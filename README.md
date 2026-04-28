# FanSocial Dev Environment — ASG + ALB Terraform

A compact Terraform module that stands up a **FanSocial dev-environment** web tier in `ap-northeast-1`: a `t2.medium` **Launch Template** with inline `user_data` (apt update + app install), an **Auto Scaling Group**, and an **Application Load Balancer** in the existing FanSocial VPC. Parameterised on `var.environment` so the same module bakes out `dev`, `staging`, or `prod` stacks.

## Highlights

- **`t2.medium` launch template with inline user_data** — bootstraps the host on first boot (apt update + custom commands), no separate AMI build.
- **Externalised VPC** — `vpc_id`, `subnet_ids`, `security_group_id` default to the real FanSocial Tokyo VPC; override per env.
- **One variable, three stacks** — `environment=dev|staging|prod` switches every resource name.
- **Companion `oldiea.yml`** — earlier CloudFormation / SAM snippet kept for reference against the current Terraform layout.

## Tech stack

- Terraform + AWS provider
- AWS: Launch Template, ASG, ALB, Target Group, Route 53 (hooked separately)
- Region: `ap-northeast-1` (Tokyo)

## Repository layout

```
DEV/
├── README.md
├── .gitignore
├── main.tf         # LT + ASG + ALB for var.environment
└── oldiea.yml      # earlier/reference YAML variant
```

## Deployment

```bash
terraform init
terraform plan  -var="environment=dev"
terraform apply -var="environment=dev"
```

## Notes

- Pair with `FANSOCIAL-STAGE/` for the CodeBuild+CodeDeploy pipeline that drives this template via `ENVIRONMENT`.
- Demonstrates: multi-environment IaC from a single module, launch-template user_data bootstrap, reuse of existing VPC primitives.
