# Deploying into an existing VPC (BYO VPC)

This module supports two networking modes:

1. **Create a new VPC** (default) — a `/16` VPC, two AZs, public + private subnets, NAT gateway, IGW, route tables, and (optionally) interface endpoints.
2. **Bring your own VPC** — point the module at an existing VPC and supply public + private subnet IDs. The module skips all VPC/subnet/NAT/IGW/route-table creation.

BYO VPC fits a security-reviewed VPC, no spare `/16` space, or org policy requiring fleets to land in pre-existing networking. Trade-off: you own routing, NAT, and (today) interface endpoints.

## Enabling BYO VPC

Set in `workspaces/<fleet>.tfvars`:

```hcl
vpc_id                       = "vpc-0abc123def456"
existing_private_subnet_ids  = ["subnet-0ccc...", "subnet-0ddd..."]   # 1+ required, 2+ AZs recommended
existing_public_subnet_ids   = []                                     # optional; unused today

# var.vpc_cidr is ignored when vpc_id is set; leave the default.
```

With `var.vpc_id` non-empty, the module skips `module.vpc`, reads the existing VPC's CIDR via `data "aws_vpc" "existing"` (for security-group rules), and round-robins agent EC2s and the fleet security group across your supplied private subnets.

## Requirements your VPC must meet

- **At least 1 private subnet** (validated). 2+ in distinct AZs recommended — agents are round-robin-placed via `% length(subnets)`, and NATS uses the first subnet.
- **Public subnets optional** — the variable exists for parity with the created-VPC path; nothing reads it in BYO VPC mode today.
- **Outbound internet from private subnets.** Bootstrap pulls FleetMind from public npm, calls the model provider API, AWS APIs, and SSM. Without NAT or VPC endpoints, bootstrap fails.
- **DNS resolution + DNS hostnames enabled** on the VPC (required for SSM and Secrets Manager).
- **S3 gateway endpoint** (or NAT) on private-subnet route tables — bootstrap downloads tarballs from the ledger bucket; without an S3 endpoint you pay NAT for every push.

## Interface endpoints in BYO VPC mode

⚠️ **Known limitation:** `var.enable_interface_endpoints` has no effect when `var.vpc_id` is set — interface-endpoint creation (`vpc.tf:73`) is gated on `local.create_vpc`, so BYO VPC fleets get zero interface endpoints from this module regardless of the flag.

To keep SSM/SecretsManager/EC2Messages traffic off NAT, create these interface endpoints yourself against your private subnets (type `Interface`, SG allowing ingress from the fleet SG on TCP 443):

- `com.amazonaws.<region>.ssm`
- `com.amazonaws.<region>.ssmmessages`
- `com.amazonaws.<region>.ec2messages`
- `com.amazonaws.<region>.secretsmanager`

A future version will decouple `enable_interface_endpoints` from `local.create_vpc` (tracked in fleetmind#136).

## Switching between modes

Switching create-VPC ↔ BYO-VPC is **destructive**: Terraform destroys the previous VPC/subnets/NAT/IGW, and EC2 instances get replaced (pinned via `subnet_id`) even though IAM roles/secrets are preserved.

Don't switch on a live fleet. Stand up the new fleet in the target VPC, migrate state (Slack apps + DDB content), then tear down the old one.

## Verification after apply

```bash
terraform output vpc_id   # should equal your var.vpc_id

aws ec2 describe-subnets --subnet-ids <subnet-ids> \
  --query 'Subnets[].[SubnetId,VpcId,AvailabilityZone,MapPublicIpOnLaunch]' --output table

aws ssm start-session --target <instance-id> --region <region>
```

If `aws ssm start-session` hangs or returns `TargetNotConnected`, the bot can't reach SSM — NAT is missing or interface endpoints aren't in place.

## Related

- [`MODULE-TROUBLESHOOTING.md`](./MODULE-TROUBLESHOOTING.md) — module-level troubleshooting.
- [`MIGRATIONS.md`](./MIGRATIONS.md) — migrations between module versions.
