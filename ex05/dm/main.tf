# based on:
# https://github.com/alfonsof/terraform-aws-examples/blob/master/code/02-one-server/main.tf

provider "aws" {
  region = "us-east-1"
}

# Look up the latest Amazon Linux 2023 AMI like in ex01.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_security_group" "ex05" {
  name        = "ex05-ssh-zk"
  description = "Allow SSH and ZooKeeper between the exercise nodes"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["212.56.191.138/32"]
  }

  # App nodes and the ZooKeeper node all live in this group.
  # A self-reference allows the ZooKeeper port only between these instances.
  ingress {
    description = "ZooKeeper clients"
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  count = 5

  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro" # as stated in assignment
  key_name               = "vockey"
  vpc_security_group_ids = [aws_security_group.ex05.id]
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    Name = "ex05-app-${count.index + 1}"
  }
}

resource "aws_instance" "zookeeper" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = "vockey"
  vpc_security_group_ids = [aws_security_group.ex05.id]
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    Name = "ex05-zookeeper"
  }
}
