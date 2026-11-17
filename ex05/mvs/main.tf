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

  #zookeeper client port, only from inside this group
  ingress {
    from_port = 2181
    to_port   = 2181
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

#application nodes A-E
resource "aws_instance" "node" {
  count                  = 5
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.nodes.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y python3-pip nftables
    pip3 install kazoo==2.10.0
  EOF
}

#standalone zookeeper, data on the host disk so it survives a container restart
resource "aws_instance" "zookeeper" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.nodes.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y docker
    systemctl enable --now docker
    docker run -d --name zookeeper --restart always -p 2181:2181 -v /zk/data:/data -v /zk/datalog:/datalog zookeeper:3.9.3
  EOF
}

output "public_ips" {
  value = aws_instance.node[*].public_ip
}

output "private_ips" {
  value = aws_instance.node[*].private_ip
}

output "zookeeper_private_ip" {
  value = aws_instance.zookeeper.private_ip
}

output "zookeeper_public_ip" {
  value = aws_instance.zookeeper.public_ip
}
