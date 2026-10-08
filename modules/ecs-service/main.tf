resource "aws_cloudwatch_log_group" "this" {
  name = "/ecs/${var.name}"

  retention_in_days = 14

  tags = var.tags
}


resource "aws_ecs_task_definition" "this" {
  family = "${var.name}-task"

  network_mode = "awsvpc"

  requires_compatibilities = [
    "EC2"
  ]

  cpu    = var.cpu
  memory = var.memory

  execution_role_arn = var.execution_role_arn


  dynamic "volume" {
    for_each = var.efs_file_system_id == null ? [] : [var.efs_file_system_id]

    content {
      name = "data"

      efs_volume_configuration {
        file_system_id = volume.value

        root_directory = "/"

        transit_encryption = "ENABLED"

        authorization_config {
          access_point_id = var.efs_access_point_id
          iam             = "DISABLED"
        }
      }
    }
  }


  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.image
      essential = true

      cpu    = var.cpu
      memory = var.memory

      command = var.command

      portMappings = concat(
        [
          {
            containerPort = var.container_port
            protocol      = "tcp"
          }
        ],
        [
          for port in var.additional_ports : {
            containerPort = port
            protocol      = "tcp"
          }
        ]
      )

      environment = [
        for key, value in var.environment : {
          name  = key
          value = value
        }
      ]

      mountPoints = var.mount_path == null ? [] : [
        {
          sourceVolume  = "data"
          containerPath = var.mount_path
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_lb_target_group" "this" {
  name     = "${var.name}-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/actuator/health"
  }
}
resource "aws_lb_listener" "this" {
  load_balancer_arn = var.load_balancer_arn
  port              = var.container_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = "404"
      message_body = "No matching service"
    }
  }
}

resource "aws_security_group" "ecs" {
  name        = "${var.name}-ecs"
  description = "Security Group for ${var.name} ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "Traffic from shared ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}
resource "aws_lb_listener_rule" "this" {
  listener_arn = aws_lb_listener.this.arn
  priority     = var.listener_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = [var.path_pattern]
    }
  }
}
resource "aws_ecs_service" "this" {
  name = var.name

  cluster = var.cluster_id

  task_definition = aws_ecs_task_definition.this.arn

  desired_count = 1

  launch_type = "EC2"


  network_configuration {
    subnets = var.private_subnet_ids

    security_groups = [
      aws_security_group.this.id
    ]

    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.name
    container_port   = var.container_port
  }

  service_registries {
    registry_arn = var.service_registry_arn
  }
}