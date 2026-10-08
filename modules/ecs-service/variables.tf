variable "name" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "image" {
  type = string
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "container_port" {
  type = number
}

variable "additional_ports" {
  type    = list(number)
  default = []
}

variable "command" {
  type    = list(string)
  default = null
}

variable "environment" {
  type      = map(string)
  sensitive = true
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "service_registry_arn" {
  type = string
}

variable "efs_file_system_id" {
  type    = string
  default = null
}

variable "efs_access_point_id" {
  type    = string
  default = null
}

variable "mount_path" {
  type    = string
  default = null
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "path_pattern" {
   type = string
   default = "/*"
}

variable "load_balancer_arn" {
   type = string
   default = ""
}