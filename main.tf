provider "aws" {
  region = "us-west-2"
}

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "us-west-2a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "us-west-2b"
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = "us-west-2c"
}

resource "aws_security_group" "example" {
  ingress {
    from_port   = 80 # Allowing traffic in from port 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}
resource "aws_ecs_cluster" "utbapp" {
  name = "utbapp"
}

variable "imagebuild" {
  type = string
  description = "the latest image build version"
}

resource "aws_ecs_task_definition" "utbapp" {
  family                   = "utbapp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "utbapp"
    image     = "393450248593.dkr.ecr.us-west-2.amazonaws.com/grupo02:111dc73e31e2ee4929ab9e38cfe809d50163dfc3"
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
  }])
}


resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = [aws_security_group.example.id]
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

resource "aws_lb_target_group" "example" {
  name_prefix = "ele"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.example.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

resource "aws_lb" "example" {
  name               = "example-lb"
  load_balancer_type = "application"
  subnets            = [aws_default_subnet.default_subnet_a.id,aws_default_subnet.default_subnet_b.id,aws_default_subnet.default_subnet_c.id]


  security_groups = [
    aws_security_group.example.id,
  ]
}

resource "aws_ecs_service" "utbapp" {
  name            = "utbapp"
  cluster         = aws_ecs_cluster.utbapp.id
  task_definition = aws_ecs_task_definition.utbapp.arn
  desired_count   = 3

  network_configuration {
    subnets         = [aws_default_subnet.default_subnet_a.id,aws_default_subnet.default_subnet_b.id,aws_default_subnet.default_subnet_c.id]
    security_groups  = [aws_security_group.service_security_group.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn
    container_name   = aws_ecs_task_definition.utbapp.family
    container_port   = 3000
  }

  launch_type     = "FARGATE"
}

output "app_url" {
  value = "http://${aws_lb.example.dns_name}/${aws_lb_target_group.example.target_type}/${aws_lb_target_group.example.name}/${aws_lb_target_group.example.port}"
}
