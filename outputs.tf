output "vpc_id" {
  description = "ID of the lab VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by AZ letter (a, b, c)."
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "security_group_id" {
  description = "Security group attached to lab EC2 instances."
  value       = aws_security_group.lab.id
}

output "instances" {
  description = "Lab EC2 instances keyed by AZ letter, with connection details."
  value = { for k, i in aws_instance.lab : k => {
    id           = i.id
    availability = i.availability_zone
    public_ipv4  = i.public_ip
    public_ipv6  = i.ipv6_addresses
    ssh          = "ssh ${var.ssh_username}@${i.public_ip}"
  } }
}
