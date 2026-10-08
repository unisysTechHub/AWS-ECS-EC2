data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}


resource "aws_iam_role" "task_execution" {
  name = "${var.name}-task-execution"

  assume_role_policy = data.aws_iam_policy_document.task_assume.json

  tags = var.tags
}


resource "aws_iam_role_policy_attachment" "task_execution" {
  role = aws_iam_role.task_execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_iam_role" "instance" {
  name = "${var.name}-ecs-instance"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = var.tags
}


resource "aws_iam_role_policy_attachment" "instance" {
  role = aws_iam_role.instance.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}


resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-ecs"

  role = aws_iam_role.instance.name
}


resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}


resource "aws_launch_template" "this" {
  name_prefix = "${var.name}-"

  image_id = data.aws_ssm_parameter.ecs_ami.value

  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  vpc_security_group_ids = [
    var.security_group_id
  ]

  user_data = base64encode(
    <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
    EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = var.tags
  }
}


resource "aws_autoscaling_group" "this" {
  name = "${var.name}-ecs"

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-ecs"
    propagate_at_launch = true
  }
}


resource "aws_ecs_capacity_provider" "this" {
  name = "${var.name}-ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.this.arn

    managed_termination_protection = "DISABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 80
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
    }
  }
}


resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = [
    aws_ecs_capacity_provider.this.name
  ]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
  }
}