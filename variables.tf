variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for tagging and resource naming"
  type        = string
  default     = "ha-infra"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Two AZs is the minimum for real HA and keeps the example cheap to run.
# Add a third element to each list below to extend to 3 AZs.
variable "availability_zones" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ (reserved for a future DB/internal tier)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for the app tier"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for app instances. Leave null to auto-select latest Amazon Linux 2023."
  type        = string
  default     = null
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name for SSH access. Leave null to skip key-based SSH (recommended: use SSM Session Manager instead)."
  type        = string
  default     = null
}

variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 6
}

variable "desired_capacity" {
  description = "Desired starting capacity of the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "scale_out_cpu_threshold" {
  description = "Average CPU utilization (%) that triggers a scale-out"
  type        = number
  default     = 70
}

variable "scale_in_cpu_threshold" {
  description = "Average CPU utilization (%) that triggers a scale-in"
  type        = number
  default     = 40
}

variable "health_check_path" {
  description = "HTTP path the ALB target group uses for health checks"
  type        = string
  default     = "/"
}

variable "allowed_http_cidr" {
  description = "CIDR allowed to reach the ALB on port 80 (restrict this in real deployments)"
  type        = string
  default     = "0.0.0.0/0"
}
