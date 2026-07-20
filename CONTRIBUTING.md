# Contributing to terraform-aws-fleetmind

This repo contains the AWS Terraform module used by FleetMind fleets. Changes should be backwards-conscious and tested with realistic module consumers.

## Local Checks

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

## Pull Requests

- Open PRs against `main`.
- Include the module behavior change and operator impact.
- Update `CHANGELOG.md` and docs when inputs, outputs, IAM, bootstrap behavior, or release tags change.
- Keep `fleetmind-template` examples and the FleetMind compatibility matrix aligned when a module version becomes the new recommended baseline.

