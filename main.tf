provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "example-vpc"
  }
}

resource "aws_subnet" "example" {
  vpc_id     = aws_vpc.example.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "example-subnet"
  }
}

resource "aws_subnet" "example2" {
  vpc_id     = aws_vpc.example.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name = "example-subnet-2"
  }
}

resource "aws_security_group" "example" {
  name_prefix = "example"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "example" {
  name_prefix = "ele"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.example.id
}

resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"

  subnet_mapping {
    subnet_id = aws_subnet.example2.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.example3.id
  }

  security_groups = [
    aws_security_group.example.id,
  ]
}

output "app_url" {
  value = "http://${aws_lb.example.dns_name}/${aws_lb_target_group.example.target_type}/${aws_lb_target_group.example.name}/${aws_lb_target_group.example.port}"
}
