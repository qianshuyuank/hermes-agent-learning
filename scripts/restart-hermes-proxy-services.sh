#!/usr/bin/env bash
set -euo pipefail

services=(
  cliproxyapi.service
  hermes-gateway.service
)

for service in "${services[@]}"; do
  echo "==> Restarting ${service}"
  systemctl --user restart "${service}"
  systemctl --user is-active --quiet "${service}"
  echo "    ${service}: active"
done

echo
echo "==> Service summary"
systemctl --user --no-pager --plain --full status cliproxyapi.service hermes-gateway.service
