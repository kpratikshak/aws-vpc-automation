Terraform to automate the VPC lab workflow

Creates a VPC with DNS hostnames & resolution enabled

Creates 2 public and 2 private subnets across 2 AZs (high availability design)

Creates an Internet Gateway and public route table

Creates a NAT Gateway in one public subnet and private route table using that NAT

Creates an S3 gateway VPC endpoint 
attached to the private route table (so private instances can access S3 without NAT)

Launches an EC2 web server in the public subnet with user-data script 
and a security group that allows HTTP (port 80)
from a configurable CIDR (default: your current IP can be set in terraform.tfvars)

