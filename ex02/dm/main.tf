# based on ex01/dm/main.tf
provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# the two nodes talk to each other (counter sync, Redis) and I connect via ssh
resource "aws_security_group" "nodes" {
  name        = "ex02-nodes"
  description = "SSH + traffic between the two nodes"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["31.207.127.20/32"] # my ip; more secure than:
    # cidr_blocks = ["0.0.0.0/0"] # all IPs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# all traffic from/for the same security group (node <-> node)
resource "aws_security_group_rule" "between_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.nodes.id
}

# node[0] = A, node[1] = B
resource "aws_instance" "node" {
  count         = 2
  ami           = data.aws_ami.al2023.id
  instance_type = "t2.micro"
  key_name      = "vockey"

  vpc_security_group_ids = [aws_security_group.nodes.id]

  tags = {
    Name = "ex02-node-${count.index + 1}"
  }
}

output "public_ips" {
  value = aws_instance.node[*].public_ip
}

output "private_ips" {
  value = aws_instance.node[*].private_ip
}
