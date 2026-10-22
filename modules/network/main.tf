resource "aws_vpc" "this" {
  cidr_block = var.cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {Name = var.name}
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {Name = var.name}
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.this.id
  cidr_block = cidrsubnet(var.cidr, 8, 0)
  availability_zone = var.availability_zone
  map_public_ip_on_launch = true
  tags = {Name = "${var.name}-public"}
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {Name = "${var.name}-public"}
}

resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_security_group" "web" {
  name = "${var.name}-web"
  description = "HTTP/HTTPS from internet"
  vpc_id = aws_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each = toset([for p in var.ingress_ports : tostring(p)])
  security_group_id = aws_security_group.web.id
  description = "public ${each.value}"
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port = each.value
  to_port = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description = "packages, ECR, SSM, S3"
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}