# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# Public Subnets (for ECS Tasks/Load Balancer if used later)
resource "aws_subnet" "public" {
  count                   = 2 # Ensure at least 2 AZs for HA
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index) # e.g., 10.0.0.0/24, 10.0.1.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # Important for current setup without LB

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# Route Table Association for Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- New Private Subnets (for RDS) ---
resource "aws_subnet" "private" {
  count             = 2 # Match public subnet count for AZ coverage
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + length(aws_subnet.public)) # e.g., 10.0.2.0/24, 10.0.3.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# --- New EIP and NAT Gateway (for Private Subnets) ---
resource "aws_eip" "nat" {
  vpc        = true    
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name        = "${var.project_name}-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Place NAT GW in a public subnet

  tags = {
    Name        = "${var.project_name}-nat-gw"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# --- New Route Table for Private Subnets ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

# --- New Route Table Association for Private Subnets ---
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Group for ECS Tasks (MODIFIED)
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Allow inbound traffic for ECS tasks and outbound to RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP inbound from anywhere" # Consider restricting this in production (e.g., to ALB)
    from_port   = 80 # Port the container listens on
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress to the internet (needed for pulling images, awslogs, secrets manager)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ecs-tasks-sg"
    Environment = var.environment
  }

}

# --- New Security Group for RDS ---
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow inbound traffic from ECS tasks"
  vpc_id      = aws_vpc.main.id

  # Typically no egress needed from DB unless it needs to call external services
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Or restrict as needed
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
  }
}

# --- New Security Group Rules to break the cycle ---

# Rule: Allow RDS Ingress FROM ECS Tasks SG
resource "aws_security_group_rule" "rds_ingress_from_ecs" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id # Traffic Source is ECS Tasks SG
  security_group_id        = aws_security_group.rds.id       # Rule is attached TO the RDS SG
  description              = "Allow RDS Ingress from ECS Tasks"
}

# Rule: Allow ECS Tasks Egress TO RDS SG
# Note: For an egress rule, source_security_group_id actually means DESTINATION security group ID.
# This is a known quirk in the Terraform AWS provider's naming for egress rules.
resource "aws_security_group_rule" "ecs_egress_to_rds" {
  type                     = "egress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id       # Traffic Destination is RDS SG
  security_group_id        = aws_security_group.ecs_tasks.id # Rule is attached TO the ECS Tasks SG
  description              = "Allow ECS Tasks Egress to RDS"
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name = "${var.project_name}-app" # Use var.project_name consistently

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-ecr"
    Environment = var.environment
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Name        = "${var.project_name}-ecs-cluster"
    Environment = var.environment
  }
}

# ECS Task Execution Role
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

# Attach the AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- New: Policy to allow reading the DB secret ---
resource "aws_iam_policy" "ecs_read_db_secret_policy" {
  name        = "${var.project_name}-ecs-read-db-secret-policy"
  description = "Allow ECS tasks to read the database secret"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Effect   = "Allow",
        # Resource = "*" # Less secure - restrict in production
        Resource = aws_secretsmanager_secret.db_credentials.arn # More Secure
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_read_db_secret_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_read_db_secret_policy.arn
}

# --- New: Generate Random Password for DB ---
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_%@" # Limit special characters if needed by RDS
}

# --- New: Store DB Credentials in Secrets Manager ---
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}/${var.environment}/db-credentials-new"
  tags = {
    Name        = "${var.project_name}-db-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = var.db_engine
    host     = aws_db_instance.main.address # Use the output address from RDS instance
    port     = var.db_port
    dbname   = var.db_name
    # Add dbInstanceIdentifier if needed by your app - helps find the instance
    dbInstanceIdentifier = aws_db_instance.main.identifier
  })
   # Ensure the DB instance exists before trying to get its address
  depends_on = [aws_db_instance.main]
}

# ECS Task Definition (MODIFIED)
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256  # Adjust as needed
  memory                   = 512  # Adjust as needed
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  # task_role_arn            = aws_iam_role.ecs_task_execution_role.arn # Uncomment if app needs direct AWS API access beyond secrets

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container"
      # Image will be updated by GitHub Actions, use ECR repo URL
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80 # Port the *new* Python app will listen on
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name # Use the created log group name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      # --- New: Inject Secret Information ---
      secrets = [
         {
            name      = "DB_SECRET_ARN" # Environment variable name inside the container
            valueFrom = aws_secretsmanager_secret.db_credentials.arn # Pass the ARN of the secret
         }
      ]
      # Optional: Pass region as env var if needed by app/boto3
      environment = [
        {
          name = "AWS_REGION"
          value = var.aws_region
        }
      ]
      # --- End Secret Injection ---
    }
  ])

  tags = {
    Name        = "${var.project_name}-task-definition"
    Environment = var.environment
  }
  # Ensure secret exists before creating task def that references it
  depends_on = [aws_secretsmanager_secret_version.db_credentials_version]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}" # Consistent naming
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
  }
}

# --- New: DB Subnet Group ---
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-sng"
  subnet_ids = aws_subnet.private[*].id # Use PRIVATE subnets

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# --- New: RDS DB Instance ---
resource "aws_db_instance" "main" {
  identifier             = "${var.project_name}-${var.environment}-db"
  allocated_storage      = var.db_allocated_storage
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  port                   = var.db_port
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result # Use the generated password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id] # Attach RDS SG

  parameter_group_name = "default.${var.db_engine}${replace(var.db_engine_version, ".", "")}" # e.g. default.postgres14 for Postgres 14.x


  publicly_accessible    = false # Keep DB private
  skip_final_snapshot    = true  # Set to false for production environments!
  multi_az               = false # Set to true for HA in production (requires >=2 private subnets in diff AZs)

  tags = {
    Name        = "${var.project_name}-rds-instance"
    Environment = var.environment
  }
  # Wait for the secret to be created (though not strictly needed for RDS creation itself)
  # But crucial for the secret_version resource which DOES depend on this instance
  # depends_on = [aws_secretsmanager_secret.db_credentials] # Dependency is handled via the secret_version depends_on
}


# ECS Service (MODIFIED - Ensure correct subnets if needed, but keep public for now)
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn # Use the ARN of the latest task definition
  desired_count   = 1
  launch_type     = "FARGATE"

  # Keep in public subnets for now as user expects direct access via public IP
  # In production, use private subnets and an ALB in public subnets
  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true # Tasks get public IPs
  }

  # Force new deployment on changes to task definition
  force_new_deployment = true

  # Ensure dependencies are met
  depends_on = [
    aws_db_instance.main, # Make sure DB is ready before service tries to connect
    aws_iam_role_policy_attachment.ecs_read_db_secret_attachment
  ]

  tags = {
    Name        = "${var.project_name}-ecs-service"
    Environment = var.environment
  }
}