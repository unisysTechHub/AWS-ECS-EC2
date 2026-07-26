output "domain" { value = aws_service_discovery_private_dns_namespace.this.name }
output "service_arns" { value = { for name, service in aws_service_discovery_service.this : name => service.arn } }
