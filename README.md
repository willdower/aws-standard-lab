# aws-standard-lab

A Terraform module for a throwaway AWS lab in **ap-southeast-2**. It builds a VPC
with one public subnet per AZ and optionally launches the cheapest Ubuntu EC2
instance in any of those subnets. Everything can be created and destroyed in
a couple of minutes.

## What gets built

- VPC (IPv4 `10.0.0.0/16` by default, plus an Amazon-assigned IPv6 `/56`)
- Internet gateway and a public route table (IPv4 and IPv6 default routes)
- Three public subnets, one per AZ (`a`, `b`, `c`), dual-stack
- Security group `lab`:
  - SSH (tcp/22) inbound from `admin_ipv4_cidr` and `admin_ipv6_cidr` only
  - All outbound allowed (IPv4 and IPv6)
- Optional EC2 instances, one per letter in `ec2_subnets`:
  - `t4g.nano` (cheapest current-gen Ubuntu option), Ubuntu 24.04 arm64
  - Login user `william` created by cloud-init, in `sudo` with passwordless sudo, key-only
  - Your SSH public key registered as an EC2 key pair
  - IMDSv2 required

## Layout

| Path | Purpose |
| --- | --- |
| `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf` | The module |
| `cloud-init.yaml.tftpl` | Creates the login user on each instance |
| `examples/lab/` | Root config that calls the module with the provider set to ap-southeast-2 |

## Usage

Requirements: Terraform >= 1.6, AWS credentials for the target account, and an
SSH public key at `~/.ssh/id_ed25519.pub` (or set `ssh_public_key_path`).

```sh
cd examples/lab
cp terraform.tfvars.example terraform.tfvars   # then set your IPs
terraform init
terraform apply
```

Connect with the `instances` output:

```sh
terraform output -json instances
ssh william@<public_ipv4>
```

Tear down:

```sh
terraform destroy
```

### Variables

| Name | Default | Notes |
| --- | --- | --- |
| `name` | `lab` | Prefix for every resource |
| `vpc_cidr` | `10.0.0.0/16` | Must be /24 or larger |
| `admin_ipv4_cidr` | `null` | Your IPv4 as `x.x.x.x/32`. Null removes the IPv4 SSH rule |
| `admin_ipv6_cidr` | `null` | Your IPv6 as `x:x::x/128`. Null removes the IPv6 SSH rule |
| `ssh_public_key_path` | `~/.ssh/id_ed25519.pub` | Public key for the key pair and `william`'s authorized_keys |
| `ssh_username` | `william` | Login user created by cloud-init |
| `ec2_subnets` | `["a"]` | `"a"`, `"b"`, `"c"` in any combination. `[]` builds the network only |
| `instance_type` | `t4g.nano` | Must match `ubuntu_arch` |
| `ubuntu_version` | `24.04` | Looked up from Canonical's SSM parameters |
| `ubuntu_arch` | `arm64` | Use `amd64` with `t3.*` / `t2.*` types |

Your home IP can change. If SSH stops working after a network change, update
`admin_ipv4_cidr` / `admin_ipv6_cidr` and run `terraform apply`.
