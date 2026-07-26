variable "aws_region" { type = string default = "us-east-1" }
variable "project_name" { type = string default = "fundtransfer" }
variable "environment" { type = string default = "dev" }
variable "image_tag" { type = string default = "v1" }
variable "ecs_instance_type" { type = string default = "m5.xlarge" }
variable "mysql_root_password" { type = string sensitive = true }
variable "mysql_password" { type = string sensitive = true }
variable "jwt_signing_key" { type = string sensitive = true }

# Full public Docker image URIs for stateful development dependencies.
variable "mysql_image" { type = string default = "docker.io/library/mysql:8.0" }
variable "redis_image" { type = string default = "docker.io/library/redis:6.2" }
variable "kafka_image" { type = string default = "docker.io/bitnami/kafka:3.7" }
