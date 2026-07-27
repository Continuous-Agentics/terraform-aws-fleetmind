# Migrations

Per-version notes for bumping `?ref=` in your `main.tf`: breaking changes (state mv or recreate), new optional variables, and behavioral changes that could surprise `terraform plan`.

If a version bump shows unexpected destroy+create, stop and read the matching entry below before applying.

---

## Unreleased — standard OpenClaw home/workspace layout

### Behavioral changes

- Agent bootstrap's `WORKSPACE_BASE` changes from `/opt/openclaw/workspace` to `$OPENCLAW_HOME/.openclaw/workspace` (i.e. `/home/openclaw/.openclaw/workspace`). Each agent's workspace — and the gateway/NATS subscriber's `.openclaw/` application state — now lives under the `openclaw` OS account's home instead of a separate `/opt` path. This matches the same `~/.openclaw` contract FleetMind's local/ssh targets already use; AWS is no longer a special case. See the companion FleetMind CLI change (`workspace_base` default) in [fleetmind#288](https://github.com/Continuous-Agentics/fleetmind/pull/288).
- `modules/agent` output `workspace_path` now reflects the new path.
- The `openclaw` Linux account, `runtime_user` support, systemd `--user` services, and first-push-gated `ConditionPathExists=` startup behavior are all unchanged — only the workspace root moved.

### Operator action — existing fleets

**This is not an automatic in-place migration.** `terraform apply` alone will not move a running host: `user_data` changes are intentionally ignored via `lifecycle.ignore_changes` on existing instances, so an already-provisioned agent keeps running against its old `/opt/openclaw/workspace/<agent>` workspace until you explicitly reprovision it.

To migrate an existing fleet:

1. Bump this module's `?ref=` and use a FleetMind CLI version that defaults `workspace_base` to `/home/openclaw/.openclaw/workspace` (or set it explicitly in `fleet.yaml` if you want to keep the old path for now — the CLI has no silent fallback, so an explicit `workspace_base:` always wins).
2. For each agent host, either:
   - Taint and replace the instance (`terraform taint 'module.agent["<agent>"].aws_instance.agent'` then `terraform apply`) so bootstrap re-runs against the new path on a fresh instance, or
   - Provision a brand-new instance and cut over (recommended for production fleets — avoids downtime and lets you verify the new host before decommissioning the old one).
3. After cutover, run `fleetmind push fleet` against the new instance to deliver `openclaw.json`/workspace content to the new path.
4. Decommission the old instance once the new one is confirmed healthy.

New fleets provisioned from this version need no migration — they land on the new path from first boot.

### New-fleet setup

```hcl
module "fleetmind" {
  source = "github.com/Continuous-Agentics/terraform-aws-fleetmind?ref=<new-version>"
  ...
}
```

```bash
terraform init -upgrade
terraform plan   # expect no changes to existing instances (ignore_changes covers user_data)
```

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
