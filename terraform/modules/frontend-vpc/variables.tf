variable "name" {
  type    = string
  default = "frontend"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "app_subnet_ids" {
  description = "Subnets for the internal ALB and the Fargate service (one per AZ)."
  type        = list(string)
}

variable "app_route_table_id" {
  description = "Route table ID shared by the app subnets, used to add the default route to the TGW."
  type        = string
}

variable "azs" {
  type = list(string)
}

variable "security_vpc_cidr" {
  description = "Security VPC CIDR (traffic to the internal ALB arrives via TGW from here)."
  type        = string
}

variable "transit_gateway_id" {
  type = string
}

variable "container_port" {
  description = "Port the frontend container listens on (matches the Next.js Dockerfile's EXPOSE/PORT)."
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

variable "tags" {
  type    = map(string)
  default = {}
}
