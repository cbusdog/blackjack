#cloud provider
provider "aws" {
  region = var.aws_region
}

#VPC & Subnet
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "blackjack-vpc"
  }
}

resource "aws_subnet" "subnets" {
  count = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone  = "${var.aws_region}${count.index + 1}"

  tags = {
    Name = "blackjack-subnet-${count.index + 1}"
  }
}

#Internet Gateway & Route Table
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "blackjack-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "blackjack-public-rt"
  }
}

resource "aws_route_table_association" "public_associations" {
  count          = length(aws_subnet.subnets)
  subnet_id      = aws_subnet.subnets[count.index].id
  route_table_id = aws_route_table.public.id
}

#Security Groups
resource "aws_security_group" "ec2" {
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "blackjack-ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow MySQL traffic"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "blackjack-rds-sg"
  }
}

#EC2 Instance
resource "aws_instance" "blackjack_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.subnets[0].id
  security_groups = [aws_security_group.ec2.name]

  tags = {
    Name = "blackjack-server"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

#RDS MySQL Instance
resource "aws_db_instance" "blackjack_db" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t2.micro"
  name                 = "blackjack"
  username             = var.db_username
  password             = var.db_password
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  subnet_group_name    = aws_db_subnet_group.main.name

  tags = {
    Name = "blackjack-db"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "blackjack-db-subnet-group"
  subnet_ids = aws_subnet.subnets[*].id

  tags = {
    Name = "blackjack-db-subnet-group"
  }
}
