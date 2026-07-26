output "file_system_id" { value = aws_efs_file_system.this.id }
output "access_point_ids" { value = { for name, access_point in aws_efs_access_point.this : name => access_point.id } }
