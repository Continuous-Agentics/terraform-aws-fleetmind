# terraform-aws-fleetmind

Terraform module for [Fleetmind](https://github.com/Continuous-Agentics/fleetmind) — multi-bot fleet infrastructure on AWS.

## Status

🚧 *Pre-release.* This repository was extracted from `fleetmind/infra/terraform/` to support module consumption from the upcoming `fleetmind-template` repo (Fleetmind issue [#26](https://github.com/Continuous-Agentics/fleetmind/issues/26)). The first tagged release will be `v0.1.0`.

Until `v0.1.0`, the canonical Terraform for Fleetmind deployments still lives at `Continuous-Agentics/fleetmind/infra/terraform/`. Existing fleets stay on that direct-apply pattern.

## Intended usage (post-`v0.1.0`)

```hcl
module "fleetmind" {
  source = "github.com/Continuous-Agentics/terraform-aws-fleetmind?ref=v0.1.0"

  fleet_name              = "my-fleet"
  agent_names             = ["pm", "fe"]
  agent_orchestrators     = { pm = "...", fe = "..." }
  wake_target_session_key = "..."
  # ...
}
```

Consumers configure their own `provider "aws"` block and Terraform backend; this module declares only `required_providers`.

## License

Apache 2.0 — see [LICENSE](LICENSE).
