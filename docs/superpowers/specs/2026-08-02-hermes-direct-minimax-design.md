# Hermes Direct MiniMax Design

**Goal:** Reconfigure the running Hermes installation to use MiniMax directly instead of the local `cli-proxy-api`, then disable the proxy service after a successful validation.

**Current State**
- The active Hermes runtime reads `/home/bitq/.hermes/config.yaml`.
- Hermes currently points at `http://localhost:8317/v1` with `provider: custom`.
- `cliproxyapi.service` is active and only exposes Gemini-family models, so MiniMax model names fail with `unknown provider`.

**Design**
- Back up the active Hermes config and capture the current proxy service definition for rollback.
- Probe the provided MiniMax key against the global and China OpenAI-compatible endpoints to determine which provider path is valid.
- Reconfigure `/home/bitq/.hermes/config.yaml` to use direct MiniMax access with a validated model ID.
- Restart `hermes-gateway.service` and verify with a minimal `hermes -z "test"` run.
- If validation succeeds, stop and disable `cliproxyapi.service`, then remove its user service file and local config directory only after confirming Hermes no longer depends on it.

**Safety Rules**
- Do not remove proxy artifacts before Hermes direct access is validated.
- Preserve a restorable copy of the old Hermes config and proxy service definition.
- If both MiniMax endpoints fail validation, stop and report the exact failure instead of partially migrating the system.
