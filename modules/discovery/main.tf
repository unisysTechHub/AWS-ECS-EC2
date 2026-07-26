resource "aws_service_discovery_private_dns_namespace" "this" { name = var.domain vpc = var.vpc_id tags = var.tags }
resource "aws_service_discovery_service" "this" { for_each = toset(var.services) name = each.key dns_config { namespace_id = aws_service_discovery_private_dns_namespace.this.id routing_policy = "MULTIVALUE" dns_records { ttl = 10 type = "A" } } }
