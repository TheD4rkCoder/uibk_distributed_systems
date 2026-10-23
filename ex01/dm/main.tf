# based on:
# https://github.com/alfonsof/terraform-aws-examples/blob/master/code/02-one-server/main.tf

provider "aws" {
  region = "us-east-1"
}

# I first looked up and hardcoded an ami linux version like described in:
# https://docs.aws.amazon.com/linux/al2023/ug/ec2.html#launch-from-ec2-console
# But with LMMs I figured out I could look up the latest Amazon Linux 2023 AMI automatically:
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name" # what field to filter on
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_security_group" "ssh" {
  name        = "ex01-ssh" # arbitrary name for the security group
  description = "Allow SSH"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["212.56.191.138/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = ["212.56.191.138/32"]
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t2.micro" # as stated in assignment
  # name of the key pair to use for SSH access; must be created in AWS beforehand
  # vockey.pem is the default one of the AWS learner lab thingy; I didn't bother creating a new one
  key_name               = "vockey"
  vpc_security_group_ids = [aws_security_group.ssh.id]
  # specifies what role the instance gets when; for when it tries to communicate/access other AWS services
  # needed for lambda function call later!
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    Name = "ex01-vm"
  }
}