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

  #election messages, udp only between the nodes
  ingress {
    from_port = 6000
    to_port   = 6000
    protocol  = "udp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#A, B, C, python3 is already on al2023, no packages needed
resource "aws_instance" "node" {
  count                  = 3
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.nodes.id]
}

output "public_ips" {
  value = aws_instance.node[*].public_ip
}

output "private_ips" {
  value = aws_instance.node[*].private_ip
}
