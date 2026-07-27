locals {
  environment_service_urls = {
    for environment, instance in aws_instance.environment : environment => {
      ar                    = "http://${instance.public_ip}:8092"
      vr                    = "http://${instance.public_ip}:8093"
      api_management        = "http://${instance.public_ip}:8000"
      api_management_ar     = "http://${instance.public_ip}:8000/ar"
      api_management_vr     = "http://${instance.public_ip}:8000/vr"
      tensorflow_model      = "http://${instance.public_ip}:8501/v1/models/half_plus_two"
      mediamtx_hls          = "http://${instance.public_ip}:8891"
      mediamtx_webrtc       = "http://${instance.public_ip}:8889"
      mediamtx_rtsp_example = "rtsp://${instance.public_ip}:8554/live"
      mediamtx_rtmp_example = "rtmp://${instance.public_ip}:1935/live"
      faas                  = aws_lambda_function_url.faas.function_url
    }
  }

  environment_ssm_commands = {
    for environment, instance in aws_instance.environment : environment =>
    "aws ssm start-session --target ${instance.id}"
  }

  environment_nifi_ssm_tunnels = {
    for environment, instance in aws_instance.environment : environment =>
    "aws ssm start-session --target ${instance.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=8443,localPortNumber=8443"
  }
}

#######################################
# Three EC2 environments
#######################################

output "environment_instance_ids" {
  description = "EC2 instance IDs keyed by dev, test, and production"
  value = {
    for environment, instance in aws_instance.environment : environment => instance.id
  }
}

output "environment_public_ips" {
  description = "Public IP addresses keyed by dev, test, and production"
  value = {
    for environment, instance in aws_instance.environment : environment => instance.public_ip
  }
}

output "environment_ssm_commands" {
  description = "Preferred SSM Session Manager commands keyed by environment"
  value       = local.environment_ssm_commands
}

output "environment_service_urls" {
  description = "Newly added service endpoints keyed by dev, test, and production"
  value       = local.environment_service_urls
}

#######################################
# Compatibility outputs
#######################################

output "public_ip" {
  description = "Development EC2 public IP retained for compatibility"
  value       = aws_instance.environment["dev"].public_ip
}

output "instance_id" {
  description = "Development EC2 instance ID retained for compatibility"
  value       = aws_instance.environment["dev"].id
}

output "platform_instance_id" {
  description = "Production EC2 instance ID retained for compatibility"
  value       = aws_instance.environment["production"].id
}

output "platform_public_ip" {
  description = "Production EC2 public IP retained for compatibility"
  value       = aws_instance.environment["production"].public_ip
}

output "platform_service_urls" {
  description = "Production service endpoints retained for compatibility"
  value       = local.environment_service_urls["production"]
}

#######################################
# Shared access details
#######################################

output "key_pair_name" {
  description = "Generated AWS key pair shared by the three environments"
  value       = aws_key_pair.generated.key_name
}

output "security_group_name" {
  description = "Generated core-service security group"
  value       = aws_security_group.runtime.name
}

output "platform_nifi_username" {
  description = "NiFi single-user login name used in every environment"
  value       = var.platform_nifi_username
}

output "environment_nifi_passwords" {
  description = "Generated NiFi passwords keyed by environment"
  value = {
    for environment, password in random_password.platform_nifi : environment => password.result
  }
  sensitive = true
}

output "platform_nifi_password" {
  description = "Production NiFi password retained for compatibility"
  value       = random_password.platform_nifi["production"].result
  sensitive   = true
}

output "environment_nifi_ssm_tunnels" {
  description = "SSM port-forwarding commands for the private NiFi UI"
  value       = local.environment_nifi_ssm_tunnels
}

output "platform_nifi_ssm_tunnel" {
  description = "Production NiFi tunnel retained for compatibility"
  value       = local.environment_nifi_ssm_tunnels["production"]
}
