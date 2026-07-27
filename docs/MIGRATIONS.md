# Migrations

Per-version notes on what to do when bumping `?ref=` in your `main.tf`. Each entry covers:

- **Breaking changes** — variables/outputs removed or renamed, resource addresses changed (state mv required, or apply recreates).
- **New optional variables** — adopt at your own pace.
- **Behavioral changes** — logic differences that don't change the API but may surprise `terraform plan`.

If `terraform plan` after a version bump shows unexpected destroy+create you don't want, *stop and read the matching entry below* before applying.

---

## v1.1.1 (current v1 baseline)

### Behavioral changes

- Agent bootstrap installs `@continuous-agentics/fleetmind` from public npm.
- The per-agent IAM role no longer includes the shared `/fleetmind/shared/github-packages-token` SSM read policy.

### Operator action

Use FleetMind CLI `0.10.1`+ and a `fleetmind-template` baseline that no longer requires GitHub Packages setup.

```hcl
module "fleetmind" {
  source = "github.com/Continuous-Agentics/terraform-aws-fleetmind?ref=v1.1.1"
  ...
}
```

```bash
terraform init -upgrade
terraform plan
```

Expect instance replacement if existing launch templates/user data came from a GitHub-Packages bootstrap version.

---

## v0.1.6

First tagged minor series — operators on pre-v0.1.0 commits were on `?ref=main`, not a tag, and can bump to `?ref=v0.1.6` cleanly without state surgery:

```hcl
module "fleetmind" {
- source = "github.com/Continuous-Agentics/terraform-aws-fleetmind"
+ source = "github.com/Continuous-Agentics/terraform-aws-fleetmind?ref=v0.1.6"
  ...
}
```

`terraform init -upgrade && terraform plan` — expect zero changes if you were on a recent `main`.

---

## Future entries

When `v0.2.0`+ ships, this doc gains a top entry covering what changed and the migration path.

---

## Conventions

- **Patch (`v0.1.x`):** No breaking changes. Variable additions allowed if defaulted to backward-compatible behavior.
- **Minor (`v0.x.0`):** May include breaking changes; each needs a migration entry.
- **Major (`vx.0.0`):** Module-shape changes (new/removed submodules, large input renames). Migration entries mandatory.
