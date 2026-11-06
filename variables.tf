variable "name" {
  description = "Name prefix applied to every resource in the lab."
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC. Each of the three public subnets takes a /24 from it."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 24
    error_message = "vpc_cidr must be a valid IPv4 CIDR with a prefix of /24 or larger (e.g. 10.0.0.0/16)."
  }
}

variable "admin_ipv4_cidr" {
  description = "Your public IPv4 address in CIDR form (e.g. 203.0.113.10/32). SSH is allowed from this only. Null disables the IPv4 SSH rule."
  type        = string
  default     = null

  validation {
    condition     = var.admin_ipv4_cidr == null ? true : can(cidrhost(var.admin_ipv4_cidr, 0)) && !can(regex(":", var.admin_ipv4_cidr))
    error_message = "admin_ipv4_cidr must be an IPv4 CIDR, e.g. 203.0.113.10/32."
  }
}

variable "admin_ipv6_cidr" {
  description = "Your public IPv6 address in CIDR form (e.g. 2001:db8::10/128). SSH is allowed from this only. Null disables the IPv6 SSH rule."
  type        = string
  default     = null

  validation {
    condition     = var.admin_ipv6_cidr == null ? true : can(cidrhost(var.admin_ipv6_cidr, 0)) && can(regex(":", var.admin_ipv6_cidr))
    error_message = "admin_ipv6_cidr must be an IPv6 CIDR, e.g. 2001:db8::10/128."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key used for both the EC2 key pair and the login user's authorized_keys."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_username" {
  description = "Login user created on each EC2 via cloud-init (in the sudo group, passwordless sudo, key-only login)."
  type        = string
  default     = "william"
}

variable "ec2_subnets" {
  description = "Which AZ subnets get an EC2 instance. Valid values are \"a\", \"b\" and \"c\", mapping to the three ap-southeast-2 AZs. An empty list builds the network only."
  type        = list(string)
  default     = ["a"]

  validation {
    condition     = alltrue([for s in var.ec2_subnets : contains(["a", "b", "c"], s)]) && length(distinct(var.ec2_subnets)) == length(var.ec2_subnets)
    error_message = "ec2_subnets may only contain \"a\", \"b\" or \"c\", with no duplicates."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Defaults to the cheapest current-gen option. Must match ubuntu_arch."
  type        = string
  default     = "t4g.nano"
}

variable "ubuntu_version" {
  description = "Ubuntu LTS version to launch, looked up via Canonical's public SSM parameters."
  type        = string
  default     = "24.04"
}

variable "ubuntu_arch" {
  description = "CPU architecture of the Ubuntu AMI. arm64 for t4g.*, amd64 for t3.* / t2.*."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "amd64"], var.ubuntu_arch)
    error_message = "ubuntu_arch must be \"arm64\" or \"amd64\"."
  }
}
