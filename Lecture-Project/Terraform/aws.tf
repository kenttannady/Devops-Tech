provider "aws" {
  region = "us-east-1"
}

# VPC and Networking
resource "aws_vpc" "main" {
  count          = var.environment == "aws" ? 1 : 0
  cidr_block     = local.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "${local.app_name}-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = var.environment == "aws" ? 2 : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = local.public_subnet_cidrs[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.app_name}-public-subnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = var.environment == "aws" ? 2 : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${local.app_name}-private-subnet-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  count  = var.environment == "aws" ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  tags = {
    Name = "${local.app_name}-igw"
  }
}

# NAT Gateway for private subnets
resource "aws_eip" "nat" {
  count = var.environment == "aws" ? 1 : 0
  vpc   = true
}

resource "aws_nat_gateway" "nat" {
  count         = var.environment == "aws" ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.gw]
}

# Route Tables
resource "aws_route_table" "public" {
  count  = var.environment == "aws" ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw[0].id
  }

  tags = {
    Name = "${local.app_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = var.environment == "aws" ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[0].id
  }

  tags = {
    Name = "${local.app_name}-private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = var.environment == "aws" ? 2 : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count          = var.environment == "aws" ? 2 : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# AWS Client VPN Setup
resource "aws_ec2_client_vpn_endpoint" "vpn" {
  count               = var.environment == "aws" ? 1 : 0
  description         = "${local.app_name}-client-vpn"
  server_certificate_arn = aws_acm_certificate.vpn[0].arn
  client_cidr_block   = "10.2.0.0/22"
  vpc_id             = aws_vpc.main[0].id
  security_group_ids = [aws_security_group.vpn[0].id

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.vpn[0].arn
  }

  connection_log_options {
    enabled = false
  }
}

resource "aws_ec2_client_vpn_network_association" "private" {
  count                  = var.environment == "aws" ? 2 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn[0].id
  subnet_id              = aws_subnet.private[count.index].id
}

resource "aws_ec2_client_vpn_authorization_rule" "private" {
  count                  = var.environment == "aws" ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn[0].id
  target_network_cidr    = local.private_subnet_cidrs[0]
  authorize_all_groups   = true
}

# VPN Security Group
resource "aws_security_group" "vpn" {
  count       = var.environment == "aws" ? 1 : 0
  name        = "${local.app_name}-vpn-sg"
  description = "Allow VPN traffic"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description = "VPN"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.app_name}-vpn-sg"
  }
}

# ACM Certificate for VPN
resource "aws_acm_certificate" "vpn" {
  count             = var.environment == "aws" ? 1 : 0
  domain_name       = "vpn.${local.app_name}.internal"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Monitoring setup
resource "aws_cloudwatch_dashboard" "main" {
  count          = var.environment == "aws" ? 1 : 0
  dashboard_name = "${local.app_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web[0].id],
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web[1].id],
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.private[0].id]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.web[0].arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", aws_lb.web[0].arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "ALB Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/VPN", "TunnelState", "VpnId", aws_ec2_client_vpn_endpoint.vpn[0].id]
          ]
          period = 60
          stat   = "Average"
          region = "us-east-1"
          title  = "VPN Tunnel Status"
        }
      }
    ]
  })
}

# Private EC2 instances
resource "aws_instance" "private" {
  count                  = var.environment == "aws" ? 1 : 0
  ami                    = "ami-0c55b159cbfafe1f0" # Ubuntu 20.04 LTS
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.private[0].id
  user_data              = file("private_user_data.sh")
  
  tags = {
    Name = "${local.app_name}-private-instance"
  }
}

resource "aws_security_group" "private" {
  count       = var.environment == "aws" ? 1 : 0
  name        = "${local.app_name}-private-sg"
  description = "Allow traffic from VPN and public instances"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description = "SSH from VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.vpn[0].id]
  }

  ingress {
    description = "HTTP from public instances"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.web[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.app_name}-private-sg"
  }
}

resource "local_file" "ansible_inventory_aws" {
  count    = var.environment == "aws" ? 1 : 0
  content  = <<-EOT
    [public]
    %{for instance in aws_instance.web~}
    ${instance.public_dns} ansible_host=${instance.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
    %{endfor~}
    
    [private]
    ${aws_instance.private[0].private_dns} ansible_host=${aws_instance.private[0].private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
    
    [monitoring]
    %{for instance in aws_instance.web~}
    ${instance.public_dns}
    %{endfor~}
    
    [all:vars]
    s3_bucket_name=${aws_s3_bucket.static_content[0].bucket}
    use_load_balancer=true
    lb_dns=${aws_lb.web[0].dns_name}
    vpn_endpoint=${aws_ec2_client_vpn_endpoint.vpn[0].dns_name}
    private_subnets=${join(",", local.private_subnet_cidrs)}
  EOT
  filename = "inventory_aws.ini"
}