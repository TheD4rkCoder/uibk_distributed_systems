# terraform setup
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Input variable for which ip addresses can connect to server
variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to connect via SSH" 
  type        = string
  default     = "0.0.0.0/0" # open to the world
}

# Input variable for ssh key
variable "public_key_path" {
  description = "Path to your local SSH public key"
  type        = string
  default     = "~/.ssh/aws_ds.pub"
}

# AMI: latest Amazon Linux 2023 (x86_64)
# AMI is disk image the instance boots from
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# For the virtual private network (VPC), every account has a default VPC
data "aws_vpc" "default" {
  default = true
}

# For ssh identity file
resource "aws_key_pair" "ssh" {
  key_name   = "terraform-ec2-key"
  public_key = file(pathexpand(var.public_key_path))
}

# Security group, basically a stateful, virtual firewall
# SSH  (22)  from a restricted CIDR
# HTTP (80)  from anywhere
# All outbound traffic allowed
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-basic-sg"
  description = "Allow SSH and HTTP inbound, all outbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "N-body1"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description= "N-body2"
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-basic-sg"
  }
}

# EC2 instance (the actual server)
resource "aws_instance" "app" {
  ami = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name = aws_key_pair.ssh.key_name
  associate_public_ip_address = true
  iam_instance_profile = "LabInstanceProfile"

  tags = {
    Name = "al2023-terraform-instance"
  }
}

# Outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "ami_used" {
  description = "AMI ID that was resolved for Amazon Linux 2023"
  value       = data.aws_ssm_parameter.al2023_ami.value
  sensitive   = true
}
