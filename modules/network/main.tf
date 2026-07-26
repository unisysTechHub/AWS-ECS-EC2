data "aws_availability_zones" "available" { state = "available" }
resource "aws_vpc" "this" { cidr_block = "10.60.0.0/16" enable_dns_hostnames = true enable_dns_support = true tags = merge(var.tags, { Name = "${var.name}-vpc" }) }
resource "aws_internet_gateway" "this" { vpc_id = aws_vpc.this.id tags = var.tags }
resource "aws_subnet" "private" { count = 2 vpc_id = aws_vpc.this.id cidr_block = "10.60.${count.index + 1}.0/24" availability_zone = data.aws_availability_zones.available.names[count.index] tags = var.tags }
resource "aws_subnet" "public" { vpc_id = aws_vpc.this.id cidr_block = "10.60.10.0/24" availability_zone = data.aws_availability_zones.available.names[0] map_public_ip_on_launch = true tags = var.tags }
resource "aws_route_table" "public" { vpc_id = aws_vpc.this.id route { cidr_block = "0.0.0.0/0" gateway_id = aws_internet_gateway.this.id } }
resource "aws_route_table_association" "public" { subnet_id = aws_subnet.public.id route_table_id = aws_route_table.public.id }
resource "aws_eip" "nat" { domain = "vpc" tags = var.tags }
resource "aws_nat_gateway" "this" { allocation_id = aws_eip.nat.id subnet_id = aws_subnet.public.id depends_on = [aws_internet_gateway.this] tags = var.tags }
resource "aws_route_table" "private" { vpc_id = aws_vpc.this.id route { cidr_block = "0.0.0.0/0" nat_gateway_id = aws_nat_gateway.this.id } }
resource "aws_route_table_association" "private" { count = 2 subnet_id = aws_subnet.private[count.index].id route_table_id = aws_route_table.private.id }
resource "aws_security_group" "ecs" { name = "${var.name}-ecs" vpc_id = aws_vpc.this.id ingress { from_port = 0 to_port = 0 protocol = "-1" self = true } egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] } tags = var.tags }
resource "aws_vpc_security_group_ingress_rule" "ssh" { security_group_id = aws_security_group.ecs.id cidr_ipv4 = var.ssh_allowed_cidr from_port = 22 to_port = 22 ip_protocol = "tcp" description = "SSH administration" }
resource "aws_security_group" "efs" { name = "${var.name}-efs" vpc_id = aws_vpc.this.id ingress { from_port = 2049 to_port = 2049 protocol = "tcp" security_groups = [aws_security_group.ecs.id] } tags = var.tags }
