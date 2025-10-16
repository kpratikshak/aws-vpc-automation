terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
  required_version = ">= 1.1.0"
}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.4.0/24"]
}

variable "create_nat_in_az_index" {
  description = "Index of the public subnet AZ (0-based) where NAT Gateway will be created to save cost"
  type        = number
  default     = 0
}

variable "instance_type" {
  description = "EC2 instance type for the web server"
  type        = string
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = "Optional key pair name if you want SSH access (leave empty to proceed without a key pair as lab did)"
  type        = string
  default     = ""
}

variable "my_http_cidr" {
  description = "CIDR allowed for HTTP (port 80). Put your IP/32 for least privilege, or 0.0.0.0/0 for wide access."
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_public_ip" {
  description = "Assign public IP to EC2 in public subnet"
  type        = bool
  default     = true
}
