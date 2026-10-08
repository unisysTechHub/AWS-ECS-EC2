variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "alb_internal" {
  description = "Whether the ALB is internal"
  type        = bool
  default     = false
}

variable "alb_name" {
  description = "ALB name. If null, defaults to <project>-<environment>-alb"
  type        = string
  default     = null
}

variable "listener_port" {
  description = "HTTP listener port"
  type        = number
  default     = 80
}

variable "listener_protocol" {
  description = "Listener protocol"
  type        = string
  default     = "HTTP"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}