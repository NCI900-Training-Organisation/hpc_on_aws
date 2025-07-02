#!/bin/bash

# Fetch the public IP from Terraform output
PUBLIC_IP=$(terraform output -raw instance_public_ip)

# Check if the IP was retrieved successfully
if [[ -z "$PUBLIC_IP" ]]; then
  echo "Error: Failed to retrieve instance public IP from Terraform output."
  exit 1
fi

# Generate the Ansible inventory file
cat <<EOF > host.ini
[ec2]
$PUBLIC_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/terraform-user
EOF

echo "Ansible inventory 'host.ini' created with the EC2 instance IP: $PUBLIC_IP"
