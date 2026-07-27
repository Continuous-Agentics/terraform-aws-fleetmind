# Contributing to terraform-aws-fleetmind

AWS Terraform module for FleetMind fleets. Changes should be deliberate and explicit about operator impact.

## Dev setup

Prerequisites: Terraform `>= 1.5`, AWS provider matching the checked-in lockfile.

```bash
git clone https://github.com/Continuous-Agentics/terraform-aws-fleetmind.git
cd terraform-aws-fleetmind

terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Don't `terraform apply` against a real AWS account unless the PR needs a live smoke test.

## Test conventions

- Run `terraform fmt -check -recursive`, `terraform init -backend=false`, and `terraform validate` before opening a PR.
- For IAM, bootstrap, SSM, Secrets Manager, S3, DynamoDB, or Cloud Map changes: include a live smoke-test note or a clear reason validation-only evidence is enough.
- Keep examples, docs, variables, outputs, and changelog aligned.
- Redact account IDs, customer-identifying secret names, Terraform state, Slack tokens, GitHub App credentials, and provider API keys before sharing logs.

## Compatibility contract

Consumed by `fleetmind-template`, driven by generated tfvars from `@continuous-agentics/fleetmind`. When changing inputs, outputs, IAM shape, bootstrap behavior, secret names, S3/DDB layout, or deployment semantics:

- Update `CHANGELOG.md` and README/docs.
- Coordinate companion PRs in `fleetmind`/`fleetmind-template` when needed.
- Update the compatibility matrix in `Continuous-Agentics/fleetmind/docs/COMPATIBILITY.md` if the recommended baseline changes.

## Branch, commit & PR conventions

Conventional Commits (`feat | fix | docs | chore | refactor | test`). Branch off `main`:

```bash
git checkout main && git pull --ff-only
git checkout -b fix/your-change
```

Keep PRs focused; squash WIP commits. Title in Conventional Commit style; describe what changed and how it was verified; link issues (`Closes #123`); include migration notes for changes affecting deployed fleets. CI green + one approval to merge.

## Releases

Releases are tagged and consumed via `?ref=vX.Y.Z`. Before tagging:

- [ ] `CHANGELOG.md` updated.
- [ ] Terraform checks pass.
- [ ] README/docs reflect new inputs/outputs/IAM/bootstrap/migration behavior.
- [ ] Template/module compatibility matrix updated if this becomes the recommended baseline.

## License

MIT. See [LICENSE](./LICENSE).
