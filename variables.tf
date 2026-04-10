variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "devops-learning"
}

variable "environment" {
  description = "The environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "container_image" {
  description = "The Docker image to run in the ECS cluster"
  type        = string
}
variable "app_port" {
  description = "The port the application listens on for HTTP traffic"
  type        = number
  default     = 80
}
