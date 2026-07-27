# Contributing to terraform-aws-fleetmind

This repo is the AWS Terraform module used by FleetMind fleets — changes should be deliberate, reviewable, and explicit about operator impact.

## Dev setup

Prerequisites: Terraform `>= 1.5`, AWS provider matching the checked-in lockfile.

```bash
# External contributors: fork first
gh repo fork Continuous-Agentics/terraform-aws-fleetmind --clone
cd terraform-aws-fleetmind

# Maintainers: clone upstream directly
git clone https://github.com/Continuous-Agentics/terraform-aws-fleetmind.git
cd terraform-aws-fleetmind

terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Don't run `terraform apply` against a real AWS account unless the PR explicitly needs a live infrastructure smoke test.

## Test conventions

- Run `terraform fmt -check -recursive`, `terraform init -backend=false`, and `terraform validate` before opening a PR.
- For IAM, bootstrap, SSM, Secrets Manager, S3, DynamoDB, or Cloud Map changes: include a live smoke-test note or a clear reason validation-only evidence is enough.
- Keep examples, docs, variables, outputs, and changelog aligned.
- Redact account IDs, customer-identifying secret names, Terraform state, Slack tokens, GitHub App credentials, and provider API keys before sharing logs.

## Compatibility contract

This module is consumed by `fleetmind-template` and driven by generated tfvars from `@continuous-agentics/fleetmind`. When changing inputs, outputs, IAM policy shape, bootstrap behavior, secret names, S3/DDB layout, or deployment semantics:

- Update `CHANGELOG.md` and README/docs.
- Coordinate companion PRs in `fleetmind` and `fleetmind-template` when needed.
- Update the compatibility matrix in `Continuous-Agentics/fleetmind/docs/COMPATIBILITY.md` if the recommended baseline changes.

## Branch, commit & PR conventions

Conventional Commits (`feat | fix | docs | chore | refactor | test`). Branch off `main`:

```bash
git checkout main && git pull --ff-only
git checkout -b fix/your-change
```

Keep PRs focused; squash WIP commits before opening. In the PR:

- Title in Conventional Commit style, e.g. `fix: grant deploy-staging read to all agents`.
- Describe what changed, why it matters to operators, and how it was verified.
- Link issues with `Closes #123` / `Refs #123`.
- Include migration notes for changes affecting existing deployed fleets.
- CI green and at least one maintainer approval required to merge.

## Where to file things

| What | Where |
|------|-------|
| Module bugs | GitHub Issues, `bug` label |
| Infra feature requests | GitHub Issues, `enhancement` label |
| Documentation gaps | GitHub Issues/PRs, `documentation` label |
| Security vulnerabilities | GitHub Security Advisories — not public issues |
| CLI or template bugs | File in `fleetmind` or `fleetmind-template`, link back if module behavior is affected |

## Releases

Maintainer-only. Releases are tagged and consumed by `fleetmind-template` via `?ref=vX.Y.Z`. Before tagging or merging release-affecting changes:

- [ ] `CHANGELOG.md` updated.
- [ ] Terraform checks pass.
- [ ] README/docs reflect new inputs, outputs, IAM, bootstrap, or migration behavior.
- [ ] Template/module compatibility updated if this becomes the recommended baseline.

## License / DCO

No CLA required. Contributions are licensed under the project's [MIT license](./LICENSE) (inbound=outbound).

## Conduct

Be direct, respectful, and constructive. Maintainers may close or edit issues that are spammy, abusive, or unrelated to FleetMind.
