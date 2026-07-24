#!/usr/bin/env python3
"""Render the agent bootstrap template and assert its runtime-user contract.

This deliberately tests the rendered user data rather than only the .tpl source:
Terraform escaping and template conditionals have broken bootstrap units before.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = REPO_ROOT / "modules/agent/user_data/agent_bootstrap.sh.tpl"


def render() -> str:
    values = {
        "fleet_name": "test-fleet",
        "agent_id": "worker",
        "openclaw_version": "latest",
        "node_version": "22",
        "aws_region": "us-west-2",
        "fleetmind_version": "latest",
        "fleetmind_package": "@continuous-agentics/fleetmind",
        "is_orchestrator": False,
        "gateway_port": 18789,
        "agent_providers": "anthropic",
    }
    hcl_map = ", ".join(f"{key} = {json.dumps(value)}" for key, value in values.items())
    expression = f"templatefile({json.dumps(str(TEMPLATE))}, {{ {hcl_map} }})\n"

    with tempfile.TemporaryDirectory(prefix="fleetmind-bootstrap-render-") as directory:
        Path(directory, "main.tf").write_text("# Isolated Terraform console context.\n", encoding="utf-8")
        result = subprocess.run(
            ["terraform", f"-chdir={directory}", "console", "-no-color"],
            input=expression,
            text=True,
            capture_output=True,
            check=False,
        )

    if result.returncode:
        raise AssertionError(f"terraform console failed:\n{result.stderr}\n{result.stdout}")

    # Terraform console prints multiline strings as a heredoc. Strip only that
    # display wrapper, then syntax-check the exact rendered shell program.
    if not result.stdout.startswith("<<EOT\n") or not result.stdout.endswith("\nEOT\n"):
        raise AssertionError(f"Unexpected terraform console string format:\n{result.stdout}")
    rendered = result.stdout.removeprefix("<<EOT\n").removesuffix("\nEOT\n")
    shellcheck = subprocess.run(
        ["bash", "-n"], input=rendered, text=True, capture_output=True, check=False
    )
    if shellcheck.returncode:
        raise AssertionError(f"Rendered bootstrap has invalid shell syntax:\n{shellcheck.stderr}")
    return rendered


def section(rendered: str, start: str, end: str) -> str:
    try:
        return rendered.split(start, 1)[1].split(end, 1)[0]
    except IndexError as error:
        raise AssertionError(f"Could not isolate rendered section starting {start!r}") from error


def require(rendered: str, expected: str) -> None:
    if expected not in rendered:
        raise AssertionError(f"Missing rendered user-data assertion:\n{expected}")


def main() -> int:
    rendered = render()

    # Runtime account, npm-capable PATH, and Docker access are all established
    # before OpenClaw is installed or configured.
    for expected in (
        'OPENCLAW_USER="openclaw"',
        'OPENCLAW_HOME="/home/openclaw"',
        'RUNTIME_PATH="/usr/local/bin:/usr/bin:/bin"',
        "dnf install -y git tar unzip jq docker",
        "systemctl enable --now docker",
        "useradd --create-home --home-dir \"$OPENCLAW_HOME\" --shell /bin/bash --groups docker \"$OPENCLAW_USER\"",
        "usermod --home \"$OPENCLAW_HOME\" --move-home --shell /bin/bash --append --groups docker \"$OPENCLAW_USER\"",
        "loginctl enable-linger \"$OPENCLAW_USER\"",
        "echo \"[bootstrap] npm $(npm --version) available on $RUNTIME_PATH\"",
        "npm install -g \"$OPENCLAW_PKG\"",
        "runuser -u \"$OPENCLAW_USER\" -- env HOME=\"$OPENCLAW_HOME\" PATH=\"$RUNTIME_PATH\" openclaw plugins install @openclaw/slack --force",
    ):
        require(rendered, expected)

    gateway = section(
        rendered,
        'cat > "$USER_SYSTEMD_DIR/openclaw-$AGENT_ID.service" << EOF',
        "# ── STAGE 12b",
    )
    nats = section(
        rendered,
        'cat > "$USER_SYSTEMD_DIR/${NATS_SVC_NAME}.service" << EOF',
        'chown "$OPENCLAW_USER:$OPENCLAW_USER"',
    )

    # Both are systemd *user* units with identical home, PATH, workspace, and
    # credential file. Neither needs a User= directive or sudo to operate.
    for unit in (gateway, nats):
        require(unit, "WorkingDirectory=$WORKSPACE_DIR")
        require(unit, "Environment=HOME=$OPENCLAW_HOME")
        require(unit, "Environment=PATH=$RUNTIME_PATH")
        require(unit, "EnvironmentFile=-$ENV_FILE")
        if "User=" in unit:
            raise AssertionError("A systemd user unit must not set User=")

    require(gateway, "ExecStartPre=/usr/local/bin/fetch-agent-secrets $FLEET_NAME $AGENT_ID $ENV_FILE $AWS_REGION")
    require(nats, "ExecStartPre=/usr/local/bin/fetch-agent-secrets $FLEET_NAME $AGENT_ID $ENV_FILE $AWS_REGION")
    require(nats, "Environment=FLEET_YAML=$NATS_FLEET_YAML")
    require(nats, "Environment=OPENCLAW_GATEWAY_PORT=18789")
    require(nats, "Environment=NATS_HEALTH_URL=http://nats.$FLEET_NAME.internal:8222/healthz")
    require(nats, "ExecStart=$FLEETMIND_BIN nats subscribe --mode worker --worker-id $AGENT_ID --json")
    if "sudo" in nats:
        raise AssertionError("Rendered NATS user service must not depend on sudo")

    for expected in (
        'USER_SYSTEMD_DIR="$OPENCLAW_HOME/.config/systemd/user"',
        "systemctl --user daemon-reload",
        'systemctl --user enable --now "openclaw-$AGENT_ID.service"',
        'systemctl --user enable --now "${NATS_SVC_NAME}.path"',
    ):
        require(rendered, expected)

    print("agent bootstrap rendered-user-data assertions passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
