locals {
  alb_name = coalesce(var.alb_name, "${var.project_name}-${var.environment}-alb")
}

resource "aws_security_group" "alb" {
  name        = local.alb_name
  description = "Shared ALB Security Group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = var.listener_port
    to_port     = var.listener_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_lb" "shared" {
  name               = local.alb_name
  load_balancer_type = "application"
  internal           = var.alb_internal

  subnets         = var.public_subnet_ids
  security_groups = [aws_security_group.alb.id]

  tags = var.tags
}

