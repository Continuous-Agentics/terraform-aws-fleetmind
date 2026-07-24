# agent submodule

Provisions one Fleetmind bot's complete AWS footprint:

- *EC2 instance* — Amazon Linux 2023, private subnet, SSM-managed, bootstrapped via `user_data/agent_bootstrap.sh.tpl`.
- *IAM role + instance profile* — least-privilege scoping for SSM, CloudWatch Logs, this agent's secrets, the fleet ContextStore table (optional), and GitHub App SSM params.
- *Secrets Manager secrets* — per-agent placeholders for Slack tokens and Anthropic API key (operator populates real values out-of-band; `lifecycle.ignore_changes` preserves them).

Intended to be invoked from the root `terraform-aws-fleetmind` module via `for_each` over the agent names. Cross-cutting policies (task-ledger PM/worker grants) are attached separately by the `task-ledger` submodule using `iam_role_name` from this module.

## Key design choices

- *OpenClaw runtime account.* Bootstrap idempotently creates or reconciles an `openclaw` Unix account (`/home/openclaw`, Bash), installs Node/npm and Docker first, and grants the account Docker-group access. Docker is intentionally available for agent tools; this module does not model a locked-down service account.
- *User services, not root-owned daemon processes.* The gateway and NATS subscriber are `systemd --user` units in `/home/openclaw/.config/systemd/user/`. Both use the same home, npm-capable PATH, workspace, and user-owned fetched-secret environment file. Bootstrap enables lingering so the user manager starts at boot; normal start/restart, subscriber connectivity, and workspace pulls run as `openclaw` without sudo.
- *Workspace compatibility.* The deployed workspace remains `/opt/openclaw/workspace/<agent>` for compatibility with the current FleetMind renderer. Bootstrap links the runtime user's `~/.openclaw` state to that workspace, so OpenClaw still has a real `/home/openclaw` home while the existing deploy contract remains intact.
- *`context_store_table_arn` is optional.* Pass empty string when the fleet uses a non-DDB context-store backend; the DDB IAM policy is skipped.
- *`shared_secret_arns` (list)* — caller-supplied additional Secrets Manager ARNs to grant read access. Typically used for the RDS-managed master-user secret (`rds!db-<random>`) whose name AWS owns.
- *Hardcoded SSM paths under `/fleetmind/...`* — these match the agent runtime's expectations. Not a variable today; revisit if the runtime ever needs configurable paths.
