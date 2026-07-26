variable "name" {
  type    = string
  default = "backend"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "app_subnet_ids" {
  description = "Subnets for the internal ALB and the backend ASG (one per AZ)."
  type        = list(string)
}

variable "db_subnet_ids" {
  description = "Subnets for DocumentDB and RDS Oracle (one per AZ)."
  type        = list(string)
}

variable "app_route_table_id" {
  description = "Route table ID shared by the app subnets, used to add the default route to the TGW."
  type        = string
}

variable "azs" {
  type = list(string)
}

variable "frontend_vpc_cidr" {
  description = "Frontend VPC CIDR (the internal ALB is called by the frontend tier via TGW)."
  type        = string
}

variable "transit_gateway_id" {
  type = string
}

variable "container_port" {
  description = "Port the backend container listens on (matches the NestJS Dockerfile's EXPOSE/PORT)."
  type        = number
  default     = 3000
}

variable "image_tag" {
  description = "Tag to deploy from the ECR repo this module creates. The repo starts empty, so the ECS service has 0 healthy tasks until CI/CD pushes an image with this tag — that's expected on first apply."
  type        = string
  default     = "latest"
}

variable "task_cpu" {
  description = "Fargate task vCPU units (256 = 0.25 vCPU)."
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = string
  default     = "512"
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "docdb_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "docdb_instance_count" {
  type    = number
  default = 2
}

variable "docdb_master_username" {
  type    = string
  default = "docdbadmin"
}

variable "docdb_engine_version" {
  type    = string
  default = "5.0.0"
}

variable "docdb_skip_final_snapshot" {
  description = "Set to false in production so a final snapshot is taken on destroy."
  type        = bool
  default     = true
}

variable "oracle_instance_class" {
  type    = string
  default = "db.r5.large"
}

variable "oracle_engine" {
  type    = string
  default = "oracle-se2"
}

variable "oracle_engine_version" {
  description = "Check `aws rds describe-db-engine-versions --engine oracle-se2` for valid values in your region."
  type        = string
  default     = "19"
}

variable "oracle_license_model" {
  type    = string
  default = "license-included"
}

variable "oracle_allocated_storage" {
  type    = number
  default = 100
}

variable "oracle_master_username" {
  type    = string
  default = "oracleadmin"
}

variable "oracle_multi_az" {
  type    = bool
  default = true
}

variable "oracle_skip_final_snapshot" {
  description = "Set to false in production so a final snapshot is taken on destroy."
  type        = bool
  default     = true
}

variable "redis_node_type" {
  type    = string
  default = "cache.r6g.large"
}

variable "redis_engine_version" {
  type    = string
  default = "7.1"
}

variable "redis_num_cache_clusters" {
  description = "Number of cache clusters (1 primary + replicas) in the replication group. 2 = primary + 1 replica across the two AZs."
  type        = number
  default     = 2
}

variable "redis_port" {
  type    = number
  default = 6379
}

variable "tags" {
  type    = map(string)
  default = {}
}
