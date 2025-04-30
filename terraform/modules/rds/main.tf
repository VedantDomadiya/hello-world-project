# --- Security Group for RDS ---
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow inbound traffic from ECS tasks"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
  }
}

# Rule: Allow RDS Ingress FROM ECS Tasks SG (passed as variable)
# resource "aws_security_group_rule" "rds_ingress_from_ecs" {
#   type                     = "ingress"
#   from_port                = var.db_port
#   to_port                  = var.db_port
#   protocol                 = "tcp"
#   source_security_group_id = var.ecs_tasks_sg_id # Traffic Source is ECS Tasks SG
#   security_group_id        = aws_security_group.rds.id # Rule attached TO this RDS SG
#   description              = "Allow RDS Ingress from ECS Tasks"
# }

# Default Egress (Allow all outbound) - Modify if needed
resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
}


# --- Generate Random Password for DB ---
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_%@" # Limit special characters if needed by RDS
}

# --- Store DB Credentials in Secrets Manager ---
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}/${var.environment}/db-creds" 
  tags = {
    Name        = "${var.project_name}-db-secret"
    Environment = var.environment
  }
}

# Note: Secret version depends on the RDS instance via db_instance_address
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username             = var.db_username
    password             = random_password.db_password.result
    engine               = var.db_engine
    host                 = aws_db_instance.main.address
    port                 = var.db_port
    dbname               = var.db_name
    dbInstanceIdentifier = aws_db_instance.main.identifier
  })

  # Ensure the DB instance exists before trying to get its address
  depends_on = [aws_db_instance.main]
}

# --- DB Subnet Group ---
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-sng"
  subnet_ids = var.private_subnet_ids # Use PRIVATE subnets passed as variable

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# --- RDS DB Instance ---
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
  vpc_security_group_ids = [aws_security_group.rds.id] # Attach this module's RDS SG

  # Default parameter group (adjust if custom params are needed)
  # parameter_group_name = "default.${var.db_engine}${replace(var.db_engine_version, ".", "")}" # e.g. default.postgres14 for Postgres 14.x
  # Note: Default parameter group name logic might need adjustment based on exact engine/version strings. Check AWS console/docs if apply fails.
  # For simplicity, omitting parameter_group_name lets AWS use the appropriate default.

  publicly_accessible    = false # Keep DB private
  skip_final_snapshot    = var.db_skip_final_snapshot
  multi_az               = var.db_multi_az # Use variable

  tags = {
    Name        = "${var.project_name}-rds-instance"
    Environment = var.environment
  }
}