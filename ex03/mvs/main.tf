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

  #zenoh router and the peers' own listeners (random ports), only from inside this group
  ingress {
    from_port = 0
    to_port   = 65535
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

#A, B, C for task 1 and 2, commander + 3 lieutenants for task 3
resource "aws_instance" "node" {
  count                  = 4
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.nodes.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y python3-pip
    pip3 install eclipse-zenoh==1.10.2
  EOF
}

#the vpc has no multicast, so zenoh scouting can't find the peers, they connect to this router instead
resource "aws_instance" "router" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.nodes.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y docker
    systemctl enable --now docker
    docker run -d --restart always --net host eclipse/zenoh:1.10.2
  EOF
}

output "public_ips" {
  value = aws_instance.node[*].public_ip
}

output "private_ips" {
  value = aws_instance.node[*].private_ip
}

output "router_private_ip" {
  value = aws_instance.router.private_ip
}
