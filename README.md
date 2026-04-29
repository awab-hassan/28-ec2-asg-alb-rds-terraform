# Project # 28 - ec2-asg-alb-rds-terraform

Terraform module that provisions a complete dev environment on AWS in `ap-northeast-1`: a `t2.medium` EC2 Launch Template with inline `user_data`, an Auto Scaling Group, an Application Load Balancer, and a MySQL RDS instance. Parameterised on `var.environment` so the same module produces `dev`, `staging`, or `prod` stacks against an existing VPC.

## What It Provisions

**Web tier**
- Launch Template (`t2.medium`) with inline `user_data` running `apt update` and application install commands on first boot
- Auto Scaling Group attached to existing VPC subnets
- Application Load Balancer with a target group registered to the ASG

**Database**
- RDS MySQL instance (`db.t3.micro`, 20 GB `gp2` storage)
- `publicly_accessible = false`
- Identifier and database name templated from `var.environment`

## Inputs

| Variable | Purpose |
|---|---|
| `environment` | `dev` / `staging` / `prod`, switches resource names |
| `vpc_id` | Existing VPC to deploy into |
| `subnet_ids` | Subnets for the ASG and ALB |
| `security_group_id` | Pre-existing security group for the EC2 instances |
| `db_username` | RDS master username |
| `db_password` | RDS master password (pass via `TF_VAR_db_password` or `terraform.tfvars`, never commit) |

## Stack

Terraform · EC2 · Launch Template · Auto Scaling Group · Application Load Balancer · RDS MySQL · ap-northeast-1 (Tokyo)

## Repository Layout

```
ec2-asg-alb-rds-terraform/
├── main.tf            # Launch Template + ASG + ALB + RDS, parameterised on var.environment
├── variables.tf
├── oldie.yml          # Earlier CloudFormation/SAM variant, kept as reference
├── .gitignore
└── README.md
```

## Deployment

```bash
terraform init
terraform plan  -var="environment=dev"
terraform apply -var="environment=dev"
```

Switch the value of `environment` to `staging` or `prod` to provision against those naming conventions.

## Notes

- **Database credentials must never be hardcoded.** Pass `db_password` via `TF_VAR_db_password` or a gitignored `terraform.tfvars`. For production, replace this pattern with AWS Secrets Manager and have the application fetch credentials at runtime.
- The RDS instance is sized for development: `db.t3.micro`, 20 GB, single-AZ, no encryption at rest, `skip_final_snapshot = true`. Before promoting to production: enable storage encryption, switch to multi-AZ, set `skip_final_snapshot = false`, resize the instance class and storage, and add automated backups.
- The default master username should not be `admin`, which is a reserved-style word AWS discourages for MySQL RDS. Choose an application-specific username via `db_username`.
- The launch template bootstraps via `user_data` on every new instance. For faster scaling and consistent boot state, bake an AMI with Packer and reference it in the launch template instead.
- Route 53 records pointing at the ALB are managed separately, outside this module.
- `oldie.yml` is the prior CloudFormation/SAM variant of this stack, retained as a reference. It is not consumed by Terraform.
