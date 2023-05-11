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

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "example-igw"
  }
}

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }

  tags = {
    Name = "example-rt"
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

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.example.id
  route_table_id = aws_route_table.example.id
}

resource "aws_subnet" "example2" {
  vpc_id     = aws_vpc.example.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name = "example-subnet-2"
  }
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.example2.id
  route_table_id = aws_route_table.example.id
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
resource "aws_ecs_cluster" "utbapp" {
  name = "utbapp"
}

resource "aws_ecs_task_definition" "utbapp" {
  family                   = "utbapp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "utbapp"
    image     = "ivanzapata2126/utbapp:${var.imagebuild}"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
  }])
}

resource "aws_ecs_service" "utbapp" {
  name            = "utbapp"
  cluster         = aws_ecs_cluster.utbapp.id
  task_definition = aws_ecs_task_definition.utbapp.arn
  desired_count   = 1

  network_configuration {
    subnets         = [aws_subnet.example.id]
    security_groups = [aws_security_group.example.id]
    assign_public_ip = true
  }

  launch_type     = "FARGATE"
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
    subnet_id = aws_subnet.example.id
  }

  security_groups = [
    aws_security_group.example.id,
  ]
}

output "app_url" {
  value = "http://${aws_lb.example.dns_name}/${aws_lb_target_group.example.target_type}/${aws_lb_target_group.example.name}/${aws_lb_target_group.example.port}"
}
