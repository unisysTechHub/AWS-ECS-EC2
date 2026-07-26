variable "domain" { type = string }
variable "vpc_id" { type = string }
variable "services" { type = list(string) }
variable "tags" { type = map(string) }
