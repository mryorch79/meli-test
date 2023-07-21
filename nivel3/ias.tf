## VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.stage}-vpc"
    Env         = var.stage
  }
}

##internet gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.stage}-igw"
    Env         = var.stage
  }
}

#subnet publica 
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.pub_subnets)
  cidr_block              = element(var.pub_subnets, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.stage}-${element(var.azs, count.index)}-public-sn"
    Env         = var.stage
  }
}

#route table para subnet publica
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.stage}-public-rt"
    Env         = var.stage
  }
}

# usar ig para rt publica
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

# asociar rt publica con subnets publicas
resource "aws_route_table_association" "public" {
  count          = length(var.pub_subnets)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# default sg
resource "aws_security_group" "default" {
  name        = "${var.stage}-default-sg"
  description = "Grupo de seguridad default"
  vpc_id      = aws_vpc.vpc.id
  depends_on = [
    aws_vpc.vpc
  ]

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }
  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }

  tags = {
    Env         = var.stage
  }
}
