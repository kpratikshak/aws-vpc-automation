# 🚀 AWS VPC Lab Automation with Terraform

## Overview

This project automates the setup of a **custom AWS VPC lab environment** using **Terraform**.  
It recreates the hands-on AWS VPC workshop workflow — building a secure, scalable, and multi-AZ network that includes:

- 🏗️ **Custom VPC** with DNS support  
- 🌐 **Public and Private Subnets** (in 2 Availability Zones)  
- 🌉 **Internet Gateway (IGW)** and **NAT Gateway** (cost-optimized, 1 AZ)  
- 🧭 **Route Tables** for public/private routing  
- 🪣 **S3 Gateway VPC Endpoint** for private S3 access  
- 💻 **EC2 Web Server** (Amazon Linux 2) running an Apache/PHP stack with automated user-data provisioning  
- 🔒 **Security Group** allowing HTTP traffic from configurable CIDR (e.g., your IP)

---

## 🧩 Architecture Diagram

```text
                 +-----------------------------+
                 |        AWS Cloud            |
                 |                             |
                 |      +------------------+   |
                 |      |   VPC-Lab-vpc    |   |
                 |      |   10.0.0.0/16    |   |
                 |      +------------------+   |
                 |             |               |
                 |     +------------------+    |
                 |     | Internet Gateway |----+
                 |     +------------------+
                 |             |
      +----------+-------------+------------+
      |                       |             |
+-------------+       +-------------+       +-------------+
| Public AZ A |       | Public AZ C |       |  (optional) |
| 10.0.1.0/24 |       | 10.0.3.0/24 |       |             |
| NAT Gateway |       |             |       |             |
+-------------+       +-------------+       +-------------+
      |                       |
      |      +-----------------------------------+
      |      |       Private Subnets (AZ A/C)    |
      |      |     10.0.2.0/24, 10.0.4.0/24     |
      |      +-----------------------------------+
      |                 |              |
      |                 |  S3 Endpoint |
      |                 +--------------+
      |
      +----> EC2 Web Server (Public)
                 └── Apache + PHP + AWS SDK
