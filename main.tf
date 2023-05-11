resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "example" {
  vpc_id     = aws_vpc.example.id
  cidr_block = "10.0.1.0/24"
}

variable "imagebuild" {
  type = string
  description = "the latest image build version"
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

data "aws_lb_target_group" "tg" {
  arn = aws_lb_target_group.example.arn
}

resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.example.id]

  tags = {
    Name = "example-lb"
  }

  listener {
    protocol = "HTTP"
    port     = "80"

    default_action {
      target_group_arn = aws_lb_target_group.example.arn
      type             = "forward"
    }
  }
}

resource "aws_lb_target_group" "example" {
  name        = "example-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "example-tg"
  }
}

output "app_url" {
  value = "http://${aws_lb.load_balancer[*].dns_name[0]}/${data.aws_lb_target_group.tg.target_type}/${aws_lb_target_group.example.name}/${aws_lb_target_group.example.port}"
}