terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27" #aws hashicorp version
    }
  }

  required_version = ">= 0.14.9" #terraform version
}
#ProviderBlockForAWS
provider "aws" {
  profile = "default"
  region  = var.region
}

#Creating VPC with cidr range
resource "aws_vpc" "my-vpc" {
  cidr_block           = var.my-vpc-cidr #allocating IP addresses and for IP routing
  enable_dns_hostnames = true  #optional
  tags = {
    Name = "${var.env_prefix}-VPC"
  }
}

#Creating Public subnet with vpc id and subnet cidr
resource "aws_subnet" "Public_Subnet_1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = var.pub_subnet_cidr[0] #optional
  availability_zone       = var.public_subnet_az[0] #optional
  map_public_ip_on_launch = true #Specify true to indicate that instances launched into the subnet should be assigned a public IP address. 
  #Default is false

  tags = {
    Name = "${var.env_prefix}-Pub_subnet_1"
  }
}

#Creating Public subnet 2 with same vpc id and different subnet cidr
resource "aws_subnet" "Public_Subnet_2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = var.pub_subnet_cidr[1] #optional
  availability_zone       = var.public_subnet_az[1] #optional
  map_public_ip_on_launch = true 
  #Specify true to indicate that instances launched into the subnet should be assigned a public IP address. 
  #Default is false
  tags = {
    Name = "${var.env_prefix}-Pub_subnet_2"
  }
}

#Creating Private subnet for our DB
resource "aws_subnet" "Private_Subnet_1" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = var.private_subnet_cidr[0] #optional
  availability_zone = var.private_subnet_az[0] #optional

  tags = {
    Name = "${var.env_prefix}-Private_subnet_1"
  }
}

#Creating Private subnet 2 for our DB
resource "aws_subnet" "Private_Subnet_2" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = var.private_subnet_cidr[1] #optional
  availability_zone = var.private_subnet_az[1] #optional


  tags = {
    Name = "${var.env_prefix}-Private_subnet_2"
  }
}

#Creating Internet Gateway for our VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

#Creating Route Table to connect our VPC to internet gateway
resource "aws_route_table" "my-route-table" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = var.route_table_cidr #required
    gateway_id = aws_internet_gateway.igw.id #optional
  }

  tags = {
    Name = "${var.env_prefix}-route_table"
  }
}

#Associating our public subnet 1 with the route table
resource "aws_route_table_association" "pub_subnet_route_association_A" {
  subnet_id      = aws_subnet.Public_Subnet_1.id #optional
  route_table_id = aws_route_table.my-route-table.id #required
}
#Associating our public subnet 2 with the route table
resource "aws_route_table_association" "pub_subnet_route_association_B" {
  subnet_id      = aws_subnet.Public_Subnet_2.id #optional
  route_table_id = aws_route_table.my-route-table.id #required
}

#Creating Security group for our instances allowing http inbound
resource "aws_security_group" "my-sg" {
  vpc_id = aws_vpc.my-vpc.id
  #optional
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #optional,VPC only
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags = {
    Name = "${var.env_prefix}-my-sg"
  }
}

#Fetching the EC2 AMI details from AWS using Data Source
data "aws_ami" "ami-amazon-linux" {
  most_recent = true #optional,If more than one result is returned, use the most recent AMI
  owners      = ["amazon"] #required
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  #optional
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#Creating Our server in Public Subnet 1 using details gathered by data source
resource "aws_instance" "my-ec2-instance" {
  ami                         = var.ec2_ami #optional
  instance_type               = var.ec2_instance_type #optional
  availability_zone           = var.public_subnet_az[0] #optional
  vpc_security_group_ids      = [aws_security_group.my-sg.id] #optional
  subnet_id                   = aws_subnet.Public_Subnet_1.id #optional
  associate_public_ip_address = true #optional
  #optional
  tags = {
    Name = "${var.env_prefix}-ec2-instance"
  }
}

#Creating Our server in Public Subnet 2 using details gathered by data source
resource "aws_instance" "my-ec2-instance2" {
  ami                         = var.ec2_ami #optional
  instance_type               = var.ec2_instance_type #optional
  availability_zone           = var.public_subnet_az[1] #optional
  vpc_security_group_ids      = [aws_security_group.my-sg.id] #optional
  subnet_id                   = aws_subnet.Public_Subnet_2.id #optional
  associate_public_ip_address = true #optional
  #optional
  tags = {
    Name = "${var.env_prefix}-ec2-instance2"
  }
}


#Configuring Security group for our database instance
resource "aws_security_group" "my_db_sg" {
  vpc_id = aws_vpc.my-vpc.id
  #Optional
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.my_alb_sg.id]
  }
  #Optional, VPC only
  egress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  #Optional
  tags = {
    Name = "${var.env_prefix}-my-db-sg"
  }
}

#configuring a security group to allow HTTP inbound traffic from our ALB 
resource "aws_security_group" "my_alb_sg" {
  vpc_id = aws_vpc.my-vpc.id
  #Optional
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.my-sg.id]
  }
  #Optional, VPC only
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
  #Optional
  tags = {
    Name = "${var.env_prefix}-my-alb-sg"
  }
}

#Launchin ALB in Public Subnets
resource "aws_lb" "external-elb" {
  name               = "my-Ex-alb" #Optional, Forces new resource
  internal           = false
  load_balancer_type = "application" #Optional
  security_groups    = [aws_security_group.my_alb_sg.id]
  subnets            = [aws_subnet.Public_Subnet_1.id, aws_subnet.Public_Subnet_2.id]

}

resource "aws_lb_target_group" "external-elb" {
  name     = "aws-lb-target-group"
  port     = 80 #ort on which targets receive traffic, unless overridden when registering a specific target.
  # Required when target_type is instance or ip. Does not apply when target_type is lambda
  protocol = "HTTP" #Optional, Forces new resource
  vpc_id   = aws_vpc.my-vpc.id #(Optional,Forces new resource) Identifier of the VPC in which to create the target group.
}

# Configuring our ALB a target group that maps to our EC2 Instances.
resource "aws_lb_target_group_attachment" "external-elb1" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.my-ec2-instance.id
  port             = 80

  depends_on = [aws_instance.my-ec2-instance]
}

resource "aws_lb_target_group_attachment" "external-alb-2" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.my-ec2-instance2.id
  port             = 80

  depends_on = [aws_instance.my-ec2-instance2]
}

#Adding HTTP listner to ALB
resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external-elb.arn
  }
}

#Creating RDS instance
resource "aws_db_instance" "default" {
  allocated_storage      = var.rds_allocated_storage
  db_subnet_group_name   = aws_db_subnet_group.default.id
  engine                 = var.rds_engine
  engine_version         = var.rds_engine_version
  instance_class         = var.rds_instance_class
  multi_az               = var.rds_multi_az
  name                   = var.rds_name
  username               = var.rds_username
  password               = var.rds_password
  skip_final_snapshot    = var.rds_skip_final_snapshot
  vpc_security_group_ids = [aws_security_group.my_db_sg.id]
}

#RDS in Private Subnet
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.Private_Subnet_1.id, aws_subnet.Private_Subnet_2.id]

  tags = {
    Name = "RDS subnet group"
  }
}