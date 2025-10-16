provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Choose 2 AZs: use indexes 0 and 2 if available, else first two.
locals {
  azs = length(data.aws_availability_zones.available.names) >= 3 ?
    [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[2]] :
    slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC-Lab-vpc"
    Env  = "lab"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id
  tags = {
    Name = "VPC-Lab-igw"
  }
}

# Public subnets (one per local.azs)
resource "aws_subnet" "public" {
  for_each = { for idx, az in local.azs : idx => az }

  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidrs[tonumber(each.key)]
  availability_zone       = each.value
  map_public_ip_on_launch = true
  tags = {
    Name = "VPC-Lab-public-${each.value}"
    Tier = "public"
  }
}

# Private subnets (one per AZ)
resource "aws_subnet" "private" {
  for_each = { for idx, az in local.azs : idx => az }

  vpc_id            = aws_vpc.lab.id
  cidr_block        = var.private_subnet_cidrs[tonumber(each.key)]
  availability_zone = each.value
  tags = {
    Name = "VPC-Lab-private-${each.value}"
    Tier = "private"
  }
}

# Public route table and association
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  tags = { Name = "VPC-Lab-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each      = aws_subnet.public
  subnet_id     = each.value.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT
resource "aws_eip" "nat_eip" {
  vpc = true
  tags = { Name = "VPC-Lab-nat-eip" }
}

# NAT Gateway in chosen public subnet (index var.create_nat_in_az_index)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[tostring(var.create_nat_in_az_index)].id
  depends_on    = [aws_internet_gateway.igw]
  tags = { Name = "VPC-Lab-nat" }
}

# Private route table -> route via NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "VPC-Lab-private-rt" }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
  depends_on             = [aws_nat_gateway.nat]
}

resource "aws_route_table_association" "private_assoc" {
  for_each = aws_subnet.private
  subnet_id = each.value.id
  route_table_id = aws_route_table.private.id
}

# S3 Gateway VPC Endpoint (gateway type)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.lab.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags = { Name = "VPC-Lab-s3-endpoint" }
}

# Security Group for web server
resource "aws_security_group" "web_sg" {
  name        = "VPC-Lab-web-sg"
  description = "Allow HTTP from configured CIDR"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description      = "HTTP in"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [var.my_http_cidr]
  }

  # Optional: allow ephemeral responses outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "VPC-Lab-web-sg" }
}

# Lookup Amazon Linux 2 AMI
data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# EC2 instance in public subnet
resource "aws_instance" "web" {
  ami                         = data.aws_ami.amzn2.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public["0"].id
  associate_public_ip_address = var.enable_public_ip
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  # optional key pair; if empty, will proceed without key (as lab)
  key_name = length(trimspace(var.ssh_key_name)) > 0 ? var.ssh_key_name : null

  metadata_options {
    http_tokens = "required" # V2 only (token required)
    http_endpoint = "enabled"
  }

  user_data = <<-EOT
    #!/bin/sh
    # Install a LAMP stack
    dnf install -y httpd wget php-fpm php-mysqli php-json php php-devel
    dnf install -y mariadb105-server
    dnf install -y httpd php-mbstring

    # Start the web server
    chkconfig httpd on
    systemctl start httpd

    # Install the web pages for our lab
    if [ ! -f /var/www/html/immersion-day-app-php7.zip ]; then
       cd /var/www/html
       wget -O 'immersion-day-app-php7.zip' 'https://static.us-east-1.prod.workshops.aws/public/2e449d3a-fc13-44c9-8c99-35a37735e7f5/assets/immersion-day-app-php7.zip'
       unzip immersion-day-app-php7.zip
    fi

    # Install the AWS SDK for PHP
    if [ ! -f /var/www/html/aws.zip ]; then
       cd /var/www/html
       mkdir -p vendor
       cd vendor
       wget https://docs.aws.amazon.com/aws-sdk-php/v3/download/aws.zip
       unzip aws.zip
    fi

    # Update existing packages
    dnf update -y
  EOT

  tags = {
    Name = "VPC-Lab-Web-server"
  }
}

# Optional: associate an Elastic IP with the web instance (if public IP is desired to be static)
resource "aws_eip" "web_eip" {
  instance = aws_instance.web.id
  vpc      = true
  depends_on = [aws_instance.web]
  tags = { Name = "VPC-Lab-web-eip" }
}
