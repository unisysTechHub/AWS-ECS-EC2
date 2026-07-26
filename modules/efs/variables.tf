variable "name" { type = string }
variable "stateful_services" { type = set(string) }
variable "subnet_ids" { type = list(string) }
variable "efs_security_group_id" { type = string }
variable "tags" { type = map(string) }
