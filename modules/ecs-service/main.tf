resource "aws_cloudwatch_log_group" "this" { name = "/ecs/${var.name}" retention_in_days = 14 tags = var.tags }

resource "aws_ecs_task_definition" "this" {
  family = "${var.name}-task"
  network_mode = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu = var.cpu
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
        authorization_config { access_point_id = var.efs_access_point_id iam = "DISABLED" }
      }
    }
  }

  container_definitions = jsonencode([{
    name = var.name
    image = var.image
    essential = true
    cpu = var.cpu
    memory = var.memory
    command = var.command
    portMappings = concat([{ containerPort = var.container_port, protocol = "tcp" }], [for port in var.additional_ports : { containerPort = port, protocol = "tcp" }])
    environment = [for key, value in var.environment : { name = key, value = value }]
    mountPoints = var.mount_path == null ? [] : [{ sourceVolume = "data", containerPath = var.mount_path }]
    logConfiguration = { logDriver = "awslogs", options = { awslogs-group = aws_cloudwatch_log_group.this.name, awslogs-region = var.aws_region, awslogs-stream-prefix = "ecs" } }
  }])
}

resource "aws_ecs_service" "this" {
  name = var.name
  cluster = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count = 1
  launch_type = "EC2"
  network_configuration { subnets = var.private_subnet_ids security_groups = [var.security_group_id] assign_public_ip = false }
  service_registries { registry_arn = var.service_registry_arn }
}
