# --- ECR Repository ---
resource "aws_ecr_repository" "app" {
  name = "${var.project_name}-app" # Consistent naming

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-ecr"
    Environment = var.environment
  }
}

# --- CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}" # Consistent naming
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
  }
}

# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Name        = "${var.project_name}-ecs-cluster"
    Environment = var.environment
  }
}

# --- IAM Role & Policies for ECS Task Execution ---
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the AWS managed policy for basic ECS task execution (logs, ECR pull)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy to allow reading the specific DB secret
resource "aws_iam_policy" "ecs_read_db_secret_policy" {
  name        = "${var.project_name}-ecs-read-db-secret-policy"
  description = "Allow ECS tasks to read the database secret from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Effect   = "Allow",
        Resource = var.db_secret_arn # Restrict to the specific secret ARN passed in
      }
    ]
  })
}

# Attach the custom policy to the execution role
resource "aws_iam_role_policy_attachment" "ecs_read_db_secret_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_read_db_secret_policy.arn
}


# --- Security Group for ECS Tasks ---
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Allow inbound HTTP and outbound to RDS & Internet"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-ecs-tasks-sg"
    Environment = var.environment
  }
}

# Rule: Allow Inbound HTTP from Anywhere (Adjust CIDR for production, e.g., from LB)
resource "aws_security_group_rule" "ecs_ingress_http" {
  type              = "ingress"
  from_port         = var.container_port
  to_port           = var.container_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow HTTP inbound"
}

# Rule: Allow ECS Tasks Egress TO RDS SG
# Remember: source_security_group_id in an egress rule refers to the DESTINATION SG.
# resource "aws_security_group_rule" "ecs_egress_to_rds" {
#   type                     = "egress"
#   from_port                = var.db_port
#   to_port                  = var.db_port
#   protocol                 = "tcp"
#   source_security_group_id = var.rds_sg_id # Traffic Destination is RDS SG (passed as variable)
#   security_group_id        = aws_security_group.ecs_tasks.id # Rule attached TO this ECS Tasks SG
#   description              = "Allow ECS Tasks Egress to RDS"
# }

# Rule: Allow All Other Egress (for ECR, Secrets Manager, Internet etc.)
resource "aws_security_group_rule" "ecs_egress_all_other" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # All protocols
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow all other outbound traffic"
}


# --- ECS Task Definition ---
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  # task_role_arn = aws_iam_role.ecs_task_execution_role.arn # Only needed if app code itself makes AWS API calls beyond what execution role provides

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container"
      image     = var.container_image_uri # Use variable for image URI
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port # Not strictly needed for awsvpc, but good practice
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs" # Prefix for log streams within the group
        }
      }
      # Inject Secret ARN as environment variable for the application
      secrets = [
        {
          name      = "DB_SECRET_ARN" # Env var name inside container
          valueFrom = var.db_secret_arn # Get value from the secret ARN passed to module
        }
      ]
      # Pass AWS region for boto3 client inside container
      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]
    }
  ])

  tags = {
    Name        = "${var.project_name}-task-definition"
    Environment = var.environment
  }
}

# --- ECS Service ---
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn # Reference the task def created here
  desired_count   = var.desired_task_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.public_subnet_ids     # Use public subnets for now
    security_groups = [aws_security_group.ecs_tasks.id] # Use SG created in this module
    assign_public_ip = var.assign_public_ip      # Assign public IPs to tasks
  }

  # Force a new deployment when the task definition changes (e.g., new image)
  force_new_deployment = true

  # Wait for dependencies like IAM policies and the log group
  depends_on = [
    aws_iam_role_policy_attachment.ecs_read_db_secret_attachment,
    aws_cloudwatch_log_group.ecs_logs
    # Implicit dependency on network via vpc_id and subnets
    # Implicit dependency on RDS via rds_sg_id and db_secret_arn used in task def
  ]

  tags = {
    Name        = "${var.project_name}-ecs-service"
    Environment = var.environment
  }
}