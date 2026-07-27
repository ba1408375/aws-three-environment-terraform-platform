#######################################
# Missing-service platform
#######################################

locals {
  platform_suffix = substr(lower(replace(var.request_id, "/[^a-zA-Z0-9-]/", "-")), 0, 32)

  platform_tags = {
    Name      = "platform-services-${local.platform_suffix}"
    ManagedBy = "Terraform"
    Stack     = "DevCloud-Missing-Services"
  }

  platform_tcp_ingress = {
    rtmp = {
      description = "MediaMTX RTMP"
      from_port   = 1935
      to_port     = 1935
    }
    kong = {
      description = "Kong API proxy"
      from_port   = 8000
      to_port     = 8000
    }
    tensorflow = {
      description = "TensorFlow Serving REST API"
      from_port   = 8501
      to_port     = 8501
    }
    mediamtx_rtsp = {
      description = "MediaMTX RTSP"
      from_port   = 8554
      to_port     = 8554
    }
    mediamtx_hls = {
      description = "MediaMTX HLS"
      from_port   = 8891
      to_port     = 8891
    }
    mediamtx_webrtc = {
      description = "MediaMTX WebRTC HTTP"
      from_port   = 8889
      to_port     = 8889
    }
    ar = {
      description = "AR static endpoint"
      from_port   = 8092
      to_port     = 8092
    }
    vr = {
      description = "VR static endpoint"
      from_port   = 8093
      to_port     = 8093
    }
  }

  platform_udp_ingress = {
    mediamtx_rtp = {
      description = "MediaMTX RTP and RTCP"
      from_port   = 8000
      to_port     = 8001
    }
    mediamtx_webrtc = {
      description = "MediaMTX WebRTC ICE"
      from_port   = 8189
      to_port     = 8189
    }
    mediamtx_srt = {
      description = "MediaMTX SRT"
      from_port   = 8890
      to_port     = 8890
    }
  }

  platform_compose = {
    for environment in keys(var.environment_instances) : environment => templatefile("${path.module}/platform/docker-compose.yml.tftpl", {
      images        = var.platform_images
      nifi_username = var.platform_nifi_username
      nifi_password = random_password.platform_nifi[environment].result
    })
  }

  platform_kong_config = templatefile("${path.module}/platform/kong.yml.tftpl", {
    faas_url = aws_lambda_function_url.faas.function_url
  })

  platform_user_data = {
    for environment in keys(var.environment_instances) : environment => templatefile("${path.module}/platform_userdata.sh", {
      ar_index         = file("${path.module}/platform/ar/index.html")
      vr_index         = file("${path.module}/platform/vr/index.html")
      kong_config      = local.platform_kong_config
      compose_config   = local.platform_compose[environment]
      environment_name = environment
    })
  }
}

resource "random_password" "platform_nifi" {
  for_each = var.environment_instances

  length      = 24
  special     = false
  min_lower   = 4
  min_upper   = 4
  min_numeric = 4
}

#######################################
# Platform network access
#######################################

resource "aws_security_group" "platform" {
  name_prefix            = "platform-${local.platform_suffix}-"
  description            = "Public application ports for the missing-service platform; admin ports use SSM"
  revoke_rules_on_delete = true
  vpc_id                 = aws_vpc.service.id

  dynamic "ingress" {
    for_each = local.platform_tcp_ingress

    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = "tcp"
      cidr_blocks = var.platform_allowed_cidrs
    }
  }

  dynamic "ingress" {
    for_each = local.platform_udp_ingress

    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = "udp"
      cidr_blocks = var.platform_allowed_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.platform_tags

  lifecycle {
    create_before_destroy = true
  }
}

#######################################
# Private administration through SSM
#######################################

resource "aws_iam_role" "platform_ssm" {
  name = "platform-ssm-${local.platform_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.platform_tags
}

resource "aws_iam_role_policy_attachment" "platform_ssm" {
  role       = aws_iam_role.platform_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "platform" {
  name = "platform-${local.platform_suffix}"
  role = aws_iam_role.platform_ssm.name

  tags = local.platform_tags
}

#######################################
# Function-as-a-Service on AWS Lambda
#######################################

data "archive_file" "faas" {
  type             = "zip"
  source_file      = "${path.module}/faas/lambda_function.py"
  output_file_mode = "0666"
  output_path      = "${path.module}/faas/lambda_function.zip"
}

resource "aws_iam_role" "faas" {
  name = "faas-${local.platform_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.platform_tags
}

resource "aws_iam_role_policy_attachment" "faas_logs" {
  role       = aws_iam_role.faas.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "faas" {
  name              = "/aws/lambda/devcloud-faas-${local.platform_suffix}"
  retention_in_days = 14

  tags = local.platform_tags
}

resource "aws_lambda_function" "faas" {
  function_name = "devcloud-faas-${local.platform_suffix}"
  description   = "Working AWS-native Function-as-a-Service endpoint"
  role          = aws_iam_role.faas.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.14"
  architectures = ["x86_64"]

  filename         = data.archive_file.faas.output_path
  source_code_hash = data.archive_file.faas.output_base64sha256
  memory_size      = 128
  timeout          = 10

  tags = local.platform_tags

  depends_on = [
    aws_cloudwatch_log_group.faas,
    aws_iam_role_policy_attachment.faas_logs,
  ]
}

resource "aws_lambda_function_url" "faas" {
  function_name      = aws_lambda_function.faas.function_name
  authorization_type = var.faas_public_access ? "NONE" : "AWS_IAM"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["content-type"]
    max_age       = 3600
  }
}
