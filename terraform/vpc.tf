# =====================================================================
# VPC — the private network that all our infrastructure lives in.
# 2 public + 2 private subnets across 2 AZs, an Internet Gateway,
# and a single (cost-saving) NAT Gateway.
# =====================================================================

# Look up which Availability Zones exist in this region.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
  # Use the first 2 AZs in the region (e.g. ap-south-1a, ap-south-1b).
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ---- The VPC itself ----
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true # allow DNS resolution inside the VPC
  enable_dns_hostnames = true # needed by EKS
  tags                 = { Name = "${var.project_name}-vpc" }
}

# ---- Internet Gateway: the VPC's door to the internet ----
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# ---- Public subnets (internet-facing) ----
resource "aws_subnet" "public" {
  count                   = length(local.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true # instances here get a public IP
  tags = {
    Name                     = "${var.project_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1" # EKS puts public load balancers here
  }
}

# ---- Private subnets (for EKS worker nodes) ----
resource "aws_subnet" "private" {
  count             = length(local.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags = {
    Name                              = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1" # EKS puts internal load balancers here
  }
}

# ---- NAT Gateway (single, to save cost) ----
# Needs a static public IP (Elastic IP).
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # NAT lives in a public subnet
  tags          = { Name = "${var.project_name}-nat" }
  depends_on    = [aws_internet_gateway.igw]
}

# ---- Public route table: send internet traffic to the IGW ----
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---- Private route table: send internet traffic out via the NAT ----
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
