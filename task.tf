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
  access_key = "AKIA33Q3WAABHW4QMTJM"
  secret_key = "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"
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

