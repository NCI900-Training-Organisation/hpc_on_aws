terraform output -json > terraform_outputs.json

ansible-playbook -i hosts mount_efs.yaml --extra-vars "@terraform_outputs.json"
