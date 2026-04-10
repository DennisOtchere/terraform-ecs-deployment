module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "devops-learning-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnets

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# 1. The Cluster
resource "aws_ecs_cluster" "main_cluster" {
  name = "devops-learning-cluster"
}

# 2. The Task Definition
resource "aws_ecs_task_definition" "cluster_app" {
  family                   = "hello-world-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU (Very small/cheap)
  memory                   = "512" # 0.5 GB

  container_definitions = jsonencode([
    {
      name      = "web-app"
      image     = var.container_image # A public demo image
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
        }
      ]
    }
  ])
}

# 3. The Service 
resource "aws_ecs_service" "main_service" {
  name            = "hello-world-service"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.cluster_app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnets
    assign_public_ip = true
    security_groups = [ aws_security_group.ecs_sg.id]
  }
  
}

# 4. Security Group for the Service
resource "aws_security_group" "ecs_sg" {
  name_prefix = "${var.environment}-ecs-service-sg-"
  description = "Allow traffic to ECS service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all outbound traffic (so the app can download updates)
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
  
  
}