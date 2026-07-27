# agent submodule

Provisions one FleetMind bot's AWS footprint:

- **EC2 instance** — Amazon Linux 2023, private subnet, SSM-managed, bootstrapped via `user_data/agent_bootstrap.sh.tpl`.
- **IAM role + instance profile** — least-privilege scoping for SSM, CloudWatch Logs, this agent's secrets, the fleet ContextStore table (optional), and GitHub App SSM params.
- **Secrets Manager secrets** — per-agent placeholders for Slack tokens and the model-provider API key (operator populates real values out-of-band; `lifecycle.ignore_changes` preserves them).

Invoked from the root `terraform-aws-fleetmind` module via `for_each` over agent names. Cross-cutting policies (task-ledger PM/worker grants) are attached separately by the `task-ledger` submodule using this module's `iam_role_name` output.

## Key design choices

- **OpenClaw runtime account.** Bootstrap idempotently creates/reconciles an `openclaw` Unix account (`/home/openclaw`, Bash), installs Node/npm and Docker first, and grants Docker-group access. Docker is intentionally available for agent tools — this module doesn't model a locked-down service account.
- **User services, not root-owned daemons.** Gateway and NATS subscriber are `systemd --user` units in `/home/openclaw/.config/systemd/user/`. That account home also holds the user-owned fetched-secret env file. Lingering starts the user manager at boot; start/restart, subscriber connectivity, and workspace pulls run as `openclaw` without sudo.
- **Workspace compatibility.** The deployed workspace stays `/opt/openclaw/workspace/<agent>` for compatibility with the current FleetMind renderer, and is the application-state HOME for the Slack plugin, gateway, and NATS subscriber (`.openclaw` lives there). Bootstrap does not create a `/home/openclaw/.openclaw` symlink — it may be dangling before deployment and blocks plugin installation. Moving app state to the OS account home needs a coordinated FleetMind CLI/deploy-contract migration.
- **Operator login shell.** `sudo -iu openclaw` loads a generated FleetMind-only profile (`/home/openclaw/.config/fleetmind/openclaw-aliases.sh`). `ocalias` lists the available commands (`ocstatus`, `oclog`, `octail`, `ocnatsstatus`, `ocnatslog`, `ocnatstail`) — it imports no local operator config or secrets.
- **`context_store_table_arn` is optional** — pass an empty string when the fleet uses a non-DDB context-store backend; the DDB IAM policy is skipped.
- **`shared_secret_arns` (list)** — caller-supplied additional Secrets Manager ARNs to grant read access, typically the RDS-managed master-user secret (`rds!db-<random>`) whose name AWS owns.
- **Hardcoded SSM paths under `/fleetmind/...`** match the agent runtime's expectations — not a variable today; revisit if the runtime needs configurable paths.
