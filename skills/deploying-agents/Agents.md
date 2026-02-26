# Infrastructure as Code (IaC) Guidelines

## Architecture
This project provisions an AWS environment using Terraform to host the containerized AI Agent application.
- **Compute**: AWS ECS (Elastic Container Service) using Fargate serverless compute.
- **Networking**: Custom VPC with public/private subnets, NAT Gateways, and an Application Load Balancer (ALB) for ingress.
- **Security**: Security Groups restricting traffic between the ALB and ECS tasks, and IAM roles for task execution.
- **Storage**: EFS or S3 configurations as defined in `storage.tf`.

## Code Style & Stack
- **Tool**: Terraform (AWS Provider).
- **Formatting**: All Terraform code must be formatted using `terraform fmt`.
- **Structure**: Resources are logically separated into specific files (`networking.tf`, `ecs.tf`, `alb.tf`, `security.tf`). Do not put all resources in `main.tf`.

## Conventions
- **Variables**: Hardcoding values is strictly prohibited. Use `variables.tf` for all configurable parameters (e.g., region, instance types, CIDR blocks) and reference them via `var.<name>`.
- **Outputs**: Any resource attribute needed by external systems or deployment scripts (e.g., ALB DNS name, VPC ID) must be exported in `outputs.tf`.
- **Tagging**: All AWS resources that support tags must include standard project tags (e.g., `Environment`, `Project`, `ManagedBy = "Terraform"`).
- **State Management**: State is managed remotely (or locally via `terraform.tfstate`). Never commit `.tfstate` or `.tfvars` files containing secrets to version control.

## Security Posture
- **Least Privilege**: IAM roles and policies must grant only the exact permissions required by the ECS tasks. Avoid `*` actions where possible.
- **Network Isolation**: ECS tasks should reside in private subnets. Only the ALB should be exposed to the public internet.