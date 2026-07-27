#######################################
# Ubuntu AMI
#######################################

data "aws_ami" "ubuntu" {

  most_recent = true

  owners = ["099720109477"]

  filter {
    name = "name"

    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#######################################
# SSH Key
#######################################

resource "tls_private_key" "ssh" {

  algorithm = "RSA"

  rsa_bits = 4096
}

resource "aws_key_pair" "generated" {

  # Unique Key Pair Name
  key_name = "${var.key_name_prefix}-${var.request_id}"

  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_file" "pem" {

  # Unique PEM File
  filename = "${var.key_name_prefix}-${var.request_id}.pem"

  content = tls_private_key.ssh.private_key_pem

  file_permission = "0400"
}

#######################################
# Security Group
#######################################

resource "aws_security_group" "runtime" {

  # Unique Security Group Name
  name   = "${var.security_group_prefix}-${var.request_id}"
  vpc_id = aws_vpc.service.id

  #######################################
  # HTTP
  #######################################

  ingress {

    description = "HTTP"

    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  #######################################
  # HTTPS
  #######################################

  ingress {

    description = "HTTPS"

    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  #######################################
  # Nginx
  #######################################

  ingress {

    description = "Nginx"

    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  #######################################
  # Apache HTTP Server
  #######################################

  ingress {

    description = "Apache HTTP Server"

    from_port = 8081
    to_port   = 8081
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  #######################################
  # Tomcat
  #######################################

  ingress {

    description = "Tomcat"

    from_port = 8082
    to_port   = 8082
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  #######################################
  # WildFly (JBoss)
  #######################################

  ingress {

    description = "WildFly"

    from_port = 8083
    to_port   = 8083
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  #######################################
  # MySQL
  #######################################

  ingress {

    description = "MySQL"

    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    cidr_blocks = [aws_vpc.service.cidr_block]
  }

  #######################################
  # MariaDB
  #######################################

  ingress {

    description = "MariaDB"

    from_port = 3307
    to_port   = 3307
    protocol  = "tcp"

    cidr_blocks = [aws_vpc.service.cidr_block]
  }

  #######################################
  # PostgreSQL
  #######################################

  ingress {

    description = "PostgreSQL"

    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"

    cidr_blocks = [aws_vpc.service.cidr_block]
  }

  #######################################
  # MongoDB
  #######################################

  ingress {

    description = "MongoDB"

    from_port = 27017
    to_port   = 27017
    protocol  = "tcp"

    cidr_blocks = [aws_vpc.service.cidr_block]
  }

  #######################################
  # Jupyter Notebook
  #######################################

  ingress {

    description = "Jupyter Notebook"

    from_port = 8888
    to_port   = 8888
    protocol  = "tcp"

    cidr_blocks = [aws_vpc.service.cidr_block]
  }

  #######################################
  # Redis
  #######################################

  ingress {

    description = "Redis"

    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"

    cidr_blocks = [aws_vpc.service.cidr_block]
  }



  ingress {
    description = "Open WebUI"

    from_port = 3000
    to_port   = 3000
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "EMQX MQTT"

    from_port = 1883
    to_port   = 1883
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }



  ingress {
    description = "EMQX Dashboard"

    from_port = 18083
    to_port   = 18083
    protocol  = "tcp"

    cidr_blocks = [aws_vpc.service.cidr_block]
  }

  ingress {
    description = "Remix IDE"

    from_port = 8085
    to_port   = 8085
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "PocketBase"

    from_port = 8091
    to_port   = 8091
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "Portainer"

    from_port = 9000
    to_port   = 9000
    protocol  = "tcp"

    cidr_blocks = [aws_vpc.service.cidr_block]
  }


  ingress {
    description = "Blockchain (Ganache)"

    from_port = 8545
    to_port   = 8545
    protocol  = "tcp"

    cidr_blocks = [aws_vpc.service.cidr_block]
  }


  ingress {
    description = "WebXR"

    from_port = 8090
    to_port   = 8090
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {

    description = "n8n"

    from_port = 5678
    to_port   = 5678
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  #######################################
  # Outbound
  #######################################

  egress {

    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.security_group_prefix}-${var.request_id}"
  }
}

#######################################
# EC2 Instance
#######################################

locals {
  core_user_data = {
    for environment in keys(var.environment_instances) : environment => templatefile("${path.module}/userdata.sh", {
      environment_name      = environment
      mysql_root_password   = var.mysql_root_password
      mysql_database        = var.mysql_database
      mysql_user            = var.mysql_user
      mysql_password        = var.mysql_password
      mariadb_root_password = var.mariadb_root_password
      mariadb_database      = var.mariadb_database
      mariadb_user          = var.mariadb_user
      mariadb_password      = var.mariadb_password
      postgres_user         = var.postgres_user
      postgres_password     = var.postgres_password
      postgres_database     = var.postgres_database
      mongodb_user          = var.mongodb_user
      mongodb_password      = var.mongodb_password
      jupyter_token         = var.jupyter_token
      webxr_index           = file("${path.module}/webxr/index.html")
    })
  }

  environment_user_data_base64 = {
    for environment in keys(var.environment_instances) : environment => base64gzip(join("\n\n", [
      local.core_user_data[environment],
      local.platform_user_data[environment]
    ]))
  }
}

resource "aws_instance" "environment" {
  for_each = var.environment_instances

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = each.value.instance_type
  subnet_id                   = aws_subnet.environment[each.key].id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated.key_name
  iam_instance_profile        = aws_iam_instance_profile.platform.name

  vpc_security_group_ids = [
    aws_security_group.runtime.id,
    aws_security_group.platform.id
  ]

  user_data_base64            = local.environment_user_data_base64[each.key]
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  #######################################
  # Root EBS Volume
  #######################################

  root_block_device {

    volume_size           = each.value.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name        = each.key
    Environment = each.key
    ManagedBy   = "Terraform"
    RequestId   = var.request_id
    Stack       = "DevCloud-Multi-Environment"
  }

  depends_on = [
    aws_iam_role_policy_attachment.platform_ssm,
    aws_route_table_association.environment
  ]
}

moved {
  from = aws_instance.runtime
  to   = aws_instance.environment["production"]
}
