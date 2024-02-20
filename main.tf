resource "aws_vpc" "tf-palworld-vpc" {
  cidr_block       = "10.52.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "tf-palworld-vpc"
  }
}

resource "aws_subnet" "tf-palworld-sn" {
  vpc_id                  = aws_vpc.tf-palworld-vpc.id
  cidr_block              = "10.52.6.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf-palworld-sn"
  }
}

resource "aws_internet_gateway" "tf-palworld-igw" {
  vpc_id = aws_vpc.tf-palworld-vpc.id
  tags = {
    Name = "tf-palworld-igw"
  }
}

resource "aws_route_table" "tf-palworld-rt" {
  vpc_id = aws_vpc.tf-palworld-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-palworld-igw.id
  }

  tags = {
    Name = "tf-palworld-rt"
  }
}

resource "aws_route_table_association" "tf-palworld-rt-assoc" {
  subnet_id      = aws_subnet.tf-palworld-sn.id
  route_table_id = aws_route_table.tf-palworld-rt.id
}

resource "aws_security_group" "tf-palworld-sg" {
  name        = "tf-palworld-sg"
  description = "Allow SSH and UDP"
  vpc_id      = aws_vpc.tf-palworld-vpc.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "UDP from VPC"
    from_port   = 8211
    to_port     = 8211
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "palworld-sg"
  }
}

data "aws_region" "current" {}

locals {
  timestamped_tag = "${var.instance_tag}-${timestamp()}"
  aws_region      = data.aws_region.current.name
}

resource "aws_launch_template" "tf-palworld-lt" {
  depends_on    = [aws_eip.palworld-eip]
  ebs_optimized = "false"
  image_id      = "ami-09694bfab577e90b0"
  instance_type = var.instance_type
  key_name      = var.key_name
  name          = "tf-palworld-lt"
  user_data = base64encode(templatefile("${path.module}/scripts/userdata.sh", {
    EIP_ALLOC             = aws_eip.palworld-eip.id
    MAX_PLAYERS           = var.MAX_PLAYERS
    PUBLIC_IP             = aws_eip.palworld-eip.public_ip
    DEDICATED_SERVER_NAME = var.DEDICATED_SERVER_NAME
    SERVER_NAME           = var.SERVER_NAME
    SERVER_DESCRIPTION    = var.SERVER_DESCRIPTION
    SERVER_PASSWORD       = var.SERVER_PASSWORD
    ADMIN_PASSWORD        = var.ADMIN_PASSWORD
    AWS_REGION            = local.aws_region
    S3_REGION             = var.S3_REGION
    S3_URI                = var.S3_URI
  }))
  vpc_security_group_ids = [
    aws_security_group.tf-palworld-sg.id
  ]

  credit_specification {
    cpu_credits = "unlimited"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = "true"
      encrypted             = "false"
      volume_size           = 20
      volume_type           = "gp3"
    }
  }

  iam_instance_profile {
    arn = var.instance_profile_arn
  }

  instance_market_options {
    market_type = "spot"

    spot_options {
      spot_instance_type = "one-time"
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = local.timestamped_tag
    }
  }
}

resource "aws_autoscaling_group" "tf-palworld-asg" {
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.tf-palworld-sn.id]

  launch_template {
    id      = aws_launch_template.tf-palworld-lt.id
    version = "$Latest"
  }
  depends_on = [aws_eip.palworld-eip]
}

resource "aws_eip" "palworld-eip" {
  domain           = "vpc"
  public_ipv4_pool = "amazon"
  depends_on       = [aws_internet_gateway.tf-palworld-igw]
  tags = {
    Name = local.timestamped_tag
  }
}

data "aws_instance" "palworld" {
  filter {
    name   = "tag:Name"
    values = [local.timestamped_tag]
  }
  depends_on = [aws_autoscaling_group.tf-palworld-asg]
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = data.aws_instance.palworld.id
  allocation_id = aws_eip.palworld-eip.id
}

output "palworld-ip" {
  description = "Use this IP to connect to the server!"
  value       = aws_eip.palworld-eip.public_ip
}
