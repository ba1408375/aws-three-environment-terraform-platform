mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }

  mock_resource "aws_lambda_function_url" {
    defaults = {
      function_url = "https://example.lambda-url.us-east-1.on.aws/"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-terraform-role"
    }
  }
}

mock_provider "tls" {}
mock_provider "local" {}
mock_provider "random" {
  mock_resource "random_password" {
    defaults = {
      result = "MockNiFiPassword123456789"
    }
  }
}

run "three_environment_mock_apply" {
  command = apply

  variables {
    request_id = "validation"

    mysql_root_password = "ValidationRoot123"
    mysql_database      = "validation"
    mysql_user          = "validation"
    mysql_password      = "ValidationUser123"

    mariadb_root_password = "ValidationRoot123"
    mariadb_database      = "validation"
    mariadb_user          = "validation"
    mariadb_password      = "ValidationUser123"

    postgres_user     = "validation"
    postgres_password = "ValidationUser123"
    postgres_database = "validation"

    mongodb_user     = "validation"
    mongodb_password = "ValidationUser123"
    jupyter_token    = "ValidationToken123"
  }

  assert {
    condition     = toset(keys(aws_instance.environment)) == toset(["dev", "test", "production"])
    error_message = "Terraform must create exactly the dev, test, and production EC2 instances."
  }

  assert {
    condition = (
      aws_instance.environment["dev"].instance_type == "m7i.2xlarge" &&
      aws_instance.environment["test"].instance_type == "m7i.2xlarge" &&
      aws_instance.environment["production"].instance_type == "m7i.4xlarge"
    )
    error_message = "The three full-stack environments must use the tested default capacities."
  }

  assert {
    condition = alltrue([
      for environment, instance in aws_instance.environment :
      instance.tags.Environment == environment && instance.tags.Name == environment
    ])
    error_message = "Every EC2 instance must be named and tagged dev, test, or production."
  }

  assert {
    condition = alltrue([
      for payload in values(local.environment_user_data_base64) :
      nonsensitive(length(payload)) <= 21848
    ])
    error_message = "Compressed EC2 user data must remain within the 16-KB decoded API limit."
  }

  assert {
    condition = alltrue([
      for instance in values(aws_instance.environment) :
      instance.root_block_device[0].encrypted
    ])
    error_message = "Every environment root volume must be encrypted."
  }

  assert {
    condition = alltrue([
      for instance in values(aws_instance.environment) :
      instance.metadata_options[0].http_tokens == "required"
    ])
    error_message = "Every EC2 environment must require IMDSv2 tokens."
  }

  assert {
    condition     = length(random_password.platform_nifi) == 3
    error_message = "NiFi must have a separate generated password in each environment."
  }

  assert {
    condition = alltrue([
      for rule in aws_security_group.platform.ingress :
      rule.from_port != 22 && rule.from_port != 8443
    ])
    error_message = "SSH and the NiFi administrator port must not be exposed by the platform security group."
  }

  assert {
    condition = alltrue([
      for rule in aws_security_group.runtime.ingress :
      rule.from_port != 22 && !(
        contains([3306, 3307, 5432, 27017, 6379, 8888, 9000, 18083, 8545], rule.from_port) &&
        contains(rule.cidr_blocks, "0.0.0.0/0")
      )
    ])
    error_message = "SSH and core data or administration ports must not be exposed to the internet."
  }

  assert {
    condition     = aws_lambda_function.faas.runtime == "python3.14"
    error_message = "The FaaS implementation must use the supported Python runtime."
  }

  assert {
    condition     = aws_lambda_function_url.faas.authorization_type == "NONE"
    error_message = "The default demonstration FaaS endpoint should remain directly testable."
  }
}
