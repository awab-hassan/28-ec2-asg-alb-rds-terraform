provider "aws" {
  region = "ap-northeast-1" # Update to your region
}

variable "environment" {
  description = "The environment for deployment (dev, staging, prod)"
  type        = string
}

# VPC and subnet IDs (using existing ones)
variable "vpc_id" {
  default = "vpc-XXX"
}

variable "subnet_ids" {
  default = ["subnet-XXX", "subnet-XXX"]
}

variable "security_group_id" {
  default = "sg-XXX"
}

resource "aws_launch_template" "app" {
  name_prefix   = "etc-${var.environment}-template"
  instance_type = "t2.medium"
  image_id      = "ami-XXX"  # Replace with AMI ID
  user_data = base64encode(<<-EOT
    #!/bin/bash
    # Update and install necessary packages
    sudo apt update
    sudo apt install -y nginx php php-fpm php-mysql curl unzip

    # Stop and disable Apache to avoid conflicts
    sudo systemctl stop apache2 || true
    sudo systemctl disable apache2 || true
    sudo apt purge -y apache2 || true

    # Download and configure WordPress
    sudo mkdir -p /var/www/code-repo
    cd /tmp
    curl -O https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    sudo mv wordpress/* /var/www/code-repo
    sudo chown -R www-data:www-data /var/www/code-repo
    sudo chmod -R 755 /var/www/code-repo
    # Fetch the instance's private IP from EC2 metadata
    INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

    # Configure NGINX
    cat <<EOF | sudo tee /etc/nginx/sites-available/default
    server {
        listen 80;
        server_name ${var.environment}.etc.app \$INSTANCE_PRIVATE_IP;
        root /var/www/code-repo;
        client_max_body_size 500M;
        index index.php index.html index.htm;

        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }

        location ~ \.php\$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
            fastcgi_read_timeout 300;
        }

        location ~ /\.ht {
            deny all;
        }
    }
    EOF

    # Link the configuration to sites-enabled
    sudo ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

    # Test and reload NGINX
    sudo nginx -t && sudo systemctl restart nginx
  EOT
  )

  network_interfaces {
    security_groups = [var.security_group_id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      delete_on_termination = true
      volume_type           = "gp2"
    }
  }
}



# Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  name = "etc-${var.environment}-asg"
  desired_capacity     = 1
  max_size             = 5
  min_size             = 1
  vpc_zone_identifier  = var.subnet_ids
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]  # Attach the target group directly here

  tag {
    key                 = "Name"
    value               = "etc-${var.environment}-server"
    propagate_at_launch = true
  }
}

# Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "etc-${var.environment}-autoscaling-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name  = aws_autoscaling_group.web_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "etc-${var.environment}-autoscaling-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name  = aws_autoscaling_group.web_asg.name
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "etc-${var.environment}-cw-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 75

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "etc-${var.environment}-cw-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 25

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}

# Load Balancer
resource "aws_lb" "app_lb" {
  name               = "etc-${var.environment}-loadbalancerss"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "app_tg" {
  name     = "etc-${var.environment}-targetgroups"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# RDS Instance
resource "aws_db_instance" "example" {
  identifier        = "etc-${var.environment}-new-dbze"
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"
  username          = "admin"
  password          = "YOUR_PASSWORD" # NEVER HARDCODE PASSWORD IN CODE BASE. 
  db_name           = "${var.environment}_database_new_ss"
  skip_final_snapshot = true
  publicly_accessible = false
}

