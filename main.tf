resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "example" {
  vpc_id     = aws_vpc.example.id
  cidr_block = "10.0.1.0/24"
}

variable "imagebuild" {
  type        = string
  description = "the latest image build version"
  default     = "latest"
}


resource "aws_security_group" "example" {
  name        = "example"
  description = "Example security group"
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

resource "aws_lb_target_group" "example" {
  name_prefix        = "example"
  port               = 80
  protocol           = "HTTP"
  vpc_id             = aws_vpc.example.id
  target_type        = "ip"
  target_timeout     = 5
  health_check_interval_seconds = 10
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

  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn
    container_name   = "utbapp"
    container_port   = 80
  }
}

resource "aws_lb" "example" {
  name               = "example"
  internal           = false

  listener {
    protocol = "HTTP"
    port     = "80"

    default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.example.arn
    }
  }
}



output "app_url" {
  value = "http://${aws_ecs_service.utbapp.load_balancer[0].dns_name}"
}