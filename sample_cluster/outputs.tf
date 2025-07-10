############################################
# Terraform Output Definitions
# These help you retrieve important info
# from your infrastructure after 'apply'
############################################

# --------------------------------------------
# EC2 Instance IDs
# --------------------------------------------
output "instance_ids" {
  # Description appears in terraform output
  description = "IDs of the EC2 instances"

  # Creates a list of EC2 instance IDs like: ["i-0abc...", "i-0def..."]
  value = [for instance in aws_instance.cluster : instance.id]
}

# --------------------------------------------
# EC2 Public IPs
# --------------------------------------------
output "instance_public_ips" {
  description = "Public IP addresses of the EC2 instances"

  # Creates a list of public IPs for each instance like: ["18.111.222.33", ...]
  value = [for instance in aws_instance.cluster : instance.public_ip]
}

# --------------------------------------------
# EFS ID for /apps
# --------------------------------------------
output "efs_apps_id" {
  description = "EFS File System ID for /apps mount"

  # Returns something like fs-0123456789abcdef0
  value = aws_efs_file_system.apps.id
}

# --------------------------------------------
# EFS ID for /scratch
# --------------------------------------------
output "efs_scratch_id" {
  description = "EFS File System ID for /scratch mount"

  # Also returns something like fs-0fedcba9876543210
  value = aws_efs_file_system.scratch.id
}
