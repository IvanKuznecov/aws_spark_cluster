output main_efs_mount_target_dns_names  {
  description = "EFS mount target DNS names"
  value       = aws_efs_mount_target.main_efs_mount_target[*].dns_name
}

output main_efs_id  {
  description = "Main elastic file system Id"
  value       = aws_efs_file_system.main_efs.id
}