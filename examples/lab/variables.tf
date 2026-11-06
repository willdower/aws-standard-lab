variable "name" {
  type    = string
  default = "lab"
}

variable "admin_ipv4_cidr" {
  description = "Your public IPv4 as a /32, e.g. 203.0.113.10/32."
  type        = string
}

variable "admin_ipv6_cidr" {
  description = "Your public IPv6 as a /128, e.g. 2001:db8::10/128."
  type        = string
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_username" {
  type    = string
  default = "william"
}

variable "ec2_subnets" {
  description = "AZ letters to place an EC2 in: [\"a\"], [\"a\",\"b\"], [\"a\",\"b\",\"c\"], or [] for network only."
  type        = list(string)
  default     = ["a"]
}
