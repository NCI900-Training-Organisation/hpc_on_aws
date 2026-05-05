# -----------------------------------------------------
# Security Group: GPU Server Access (SSH + JupyterHub)
# -----------------------------------------------------
resource "aws_security_group" "ssh_access" {

  name        = "allow_ssh_from_anywhere"
  description = "Allow SSH and JupyterHub inbound traffic"
  vpc_id      = aws_vpc.main.id

  # -----------------------------------------------------
  # SSH Access (Port 22)
  # -----------------------------------------------------
  ingress {
    description = "SSH from anywhere (IPv4)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH from anywhere (IPv6)"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  # -----------------------------------------------------
  # JupyterHub HTTP Access (Port 80)
  # -----------------------------------------------------
  ingress {
    description = "HTTP for JupyterHub (TLJH)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------------------------
  # Optional: HTTPS (if you later enable TLS)
  # -----------------------------------------------------
  ingress {
    description = "HTTPS for JupyterHub"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------------------------
  # Allow All Outbound Traffic
  # -----------------------------------------------------
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------------------------
  # Tags
  # -----------------------------------------------------
  tags = {
    Name = "GPU-Server-ssh-access"
  }
}
