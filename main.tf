data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # ap-southeast-2 has three AZs (a, b, c). Key subnets by the AZ letter so
  # var.ec2_subnets can refer to them directly.
  azs       = slice(sort(data.aws_availability_zones.available.names), 0, 3)
  subnet_az = { for az in local.azs : substr(az, -1, 1) => az }

  # Position of each AZ letter, used to carve non-overlapping IPv4 /24s and IPv6 /64s.
  subnet_index = { a = 0, b = 1, c = 2 }

  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block                       = var.vpc_cidr
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "${var.name}-vpc"
  }

  lifecycle {
    precondition {
      condition     = data.aws_region.current.region == "ap-southeast-2"
      error_message = "This lab is built for ap-southeast-2. Current provider region is ${data.aws_region.current.region}."
    }
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = local.subnet_az

  vpc_id                          = aws_vpc.this.id
  availability_zone               = each.value
  cidr_block                      = cidrsubnet(var.vpc_cidr, 8, local.subnet_index[each.key])
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, local.subnet_index[each.key])
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true

  tags = {
    Name = "${var.name}-public-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "public_ipv4" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "public_ipv6" {
  route_table_id              = aws_route_table.public.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security group: SSH in from admin addresses only, everything out
# ---------------------------------------------------------------------------

resource "aws_security_group" "lab" {
  name        = "${var.name}-lab"
  description = "SSH from admin IPs only; all outbound allowed"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-lab"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_ipv4" {
  count = var.admin_ipv4_cidr == null ? 0 : 1

  security_group_id = aws_security_group.lab.id
  description       = "SSH from admin IPv4"
  cidr_ipv4         = var.admin_ipv4_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh_ipv6" {
  count = var.admin_ipv6_cidr == null ? 0 : 1

  security_group_id = aws_security_group.lab.id
  description       = "SSH from admin IPv6"
  cidr_ipv6         = var.admin_ipv6_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.lab.id
  description       = "All outbound IPv4"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all_ipv6" {
  security_group_id = aws_security_group.lab.id
  description       = "All outbound IPv6"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------------------------
# EC2: cheapest Ubuntu, one instance per subnet listed in var.ec2_subnets
# ---------------------------------------------------------------------------

resource "aws_key_pair" "this" {
  key_name   = "${var.name}-key"
  public_key = local.ssh_public_key
}

# Canonical publishes the current Ubuntu AMI IDs as SSM parameters, so there is
# no need to filter AMIs by owner or name pattern.
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/${var.ubuntu_version}/stable/current/${var.ubuntu_arch}/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "lab" {
  for_each = toset(var.ec2_subnets)

  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[each.key].id
  vpc_security_group_ids = [aws_security_group.lab.id]
  key_name               = aws_key_pair.this.key_name

  # cloud-init creates the login user. The Ubuntu AMI's default "ubuntu" user
  # is left in place.
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    username       = var.ssh_username
    ssh_public_key = local.ssh_public_key
  })

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  tags = {
    Name = "${var.name}-${each.key}"
  }
}
