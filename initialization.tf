terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.23.1"
    }
  }
}

provider "aws" {
  region = "us-east-2"
  shared_credentials_files = ["C:/Users/Nancy/.aws/credentials"]
}

resource "aws_ecs_cluster" "hr_test_new_cluster" {
  name = "hr_test_new_cluster"

}

resource "aws_ecs_cluster_capacity_providers" "hr_test_new_cluster_capacity" {
  cluster_name = aws_ecs_cluster.hr_test_new_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_execution_role-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_execution_role" {
  name       = "ecs_task_execution_role_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
}

resource "aws_ecs_task_definition" "laridate_migration_task_definition" {
  family                   = "laridae_migration_task_definition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = "arn:aws:iam::815028109314:role/ecs-task-admin"
  container_definitions    = <<TASK_DEFINITION
    [
      {
        "name": "laridae_migration_task",
        "image": "closetsolipsist/laridae",
        "cpu": 1024,
        "memory": 2048,
        "essential": true,
        "environment": [
          {"name": "DATABASE_URL", "value": "postgresql://postgres:Teameight8@hr-db-rds.cjp7wjotvbeh.us-east-2.rds.amazonaws.com/human_resources"}
        ],
        "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "/ecs/",
                    "awslogs-region": "us-east-2",
                    "awslogs-stream-prefix": "ecs"
                },
                "secretOptions": []
            }
      }
    ]
  TASK_DEFINITION
}

resource "aws_iam_user" "github_runner_user" {
  name = "github_runner_user"
}

resource "aws_iam_policy" "github_runner_user" {
  name        = "ecs-policy"
  description = "IAM policy for managing Amazon ECS"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ecs:*",
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}
