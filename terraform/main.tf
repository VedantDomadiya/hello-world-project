# --- Network Module ---
module "network" {
  source = "./modules/network"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  vpc_cidr_block = var.vpc_cidr_block
  # Using default subnet counts from module variables
}

# --- ECS Module ---
# Note: We need outputs from RDS (secret ARN, SG ID) and Network (VPC ID, Subnets).
# RDS needs the ECS SG ID. This creates a cycle if defined naively.
# We define ECS first to get its SG ID, pass it to RDS, then use RDS outputs in ECS.
# Terraform handles dependency resolution based on these references.

module "ecs" {
  source = "./modules/ecs"

  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids # Deploying service in public subnets
#  rds_sg_id           = module.rds.rds_sg_id      # Pass RDS SG ID for egress rule
#  db_port             = var.db_port               # Pass DB port for egress rule
  db_secret_arn       = module.rds.db_secret_arn  # Pass Secret ARN for task definition
  container_image_uri = "${module.ecs.ecr_repository_url}:${var.container_image_tag}" # Construct image URI
  container_port      = var.container_port
  # Using default CPU/Memory/Task count from module variables

  # Explicit dependency to ensure RDS module (and its SG) is created before ECS tries to use its outputs
#  depends_on = [module.rds]
}


# --- RDS Module ---
module "rds" {
  source = "./modules/rds"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_id               = module.network.vpc_id
  private_subnet_ids   = module.network.private_subnet_ids # Deploy DB in private subnets
#  ecs_tasks_sg_id      = module.ecs.ecs_tasks_sg_id  # Pass ECS Task SG for ingress rule
  db_name              = var.db_name
  db_username          = var.db_username
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_engine            = var.db_engine
  db_engine_version    = var.db_engine_version
  db_port              = var.db_port
  # Using default multi-az/skip-snapshot from module variables

  # Explicit dependency to ensure ECS module (and its SG) is created before RDS tries to use its outputs
#  depends_on = [module.ecs]
}

# Note on Dependency Cycle Handling:
# - ECS Module defines ECS SG and outputs its ID (`ecs_tasks_sg_id`).
# - RDS Module defines RDS SG and outputs its ID (`rds_sg_id`).
# - ECS Module takes `rds_sg_id` as input to allow egress TO RDS.
# - RDS Module takes `ecs_tasks_sg_id` as input to allow ingress FROM ECS.
# - We add explicit `depends_on` in both module calls pointing to each other.
#   Terraform is generally smart enough to resolve this based on attribute passing,
#   but explicit depends_on makes the intent clearer and can help in complex scenarios.
#   Alternatively, define the Security Group Rules connecting them here in the root module,
#   referencing `module.ecs.ecs_tasks_sg_id` and `module.rds.rds_sg_id`.