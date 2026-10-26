provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_key_pair" "key" {
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "nodes" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #counter sync between the nodes, only from inside this group
  ingress {
    from_port = 5000
    to_port   = 5001
    protocol  = "udp"
    self      = true
  }

  #redis (task 2), only from inside this group
  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#node A and node B
resource "aws_instance" "node" {
  count                  = 2
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.nodes.id]

  #redis client for task 2
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y python3-pip
    pip3 install redis
  EOF
}

#shared data store for task 2
resource "aws_instance" "store" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.nodes.id]

  #listen on all interfaces, the security group only lets the nodes in
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y redis6
    sed -i 's/^bind .*/bind 0.0.0.0/; s/^protected-mode yes/protected-mode no/' /etc/redis6/redis6.conf
    systemctl enable --now redis6
  EOF
}

output "public_ips" {
  value = aws_instance.node[*].public_ip
}

output "private_ips" {
  value = aws_instance.node[*].private_ip
}

output "store_public_ip" {
  value = aws_instance.store.public_ip
}

output "store_private_ip" {
  value = aws_instance.store.private_ip
}
