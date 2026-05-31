# EDA MCP Bridge Recovery Design

## Goal

Restore the EasyEDA Pro / LCEDA Pro bridge connection that currently fails with:

`Connect timeout after 8000ms (url ws://127.0.0.1:18800)`

This design prioritizes fast service recovery first, with the smallest safe change set that also reduces immediate recurrence.

## Current Findings

- `Gateway` is already running and listening on port `18800`.
- `MCP Server` (`/home/bitq/mcp-servers/jlcmcp/dist/index.js`) is not running.
- The observed state matches the handoff in `EDA/TROUBLE_HANDOFF.md`.
- `EDA/check-eda-mcp.sh` currently lacks execute permission, which weakens diagnostics but is not the primary outage cause.
- `EDA/start-eda-mcp.sh` and related docs are not fully aligned on required runtime configuration and operational flow.

## Confirmed Root Cause

The immediate outage is caused by a missing middle layer in the bridge chain:

`EDA plugin <-> Gateway <-> MCP Server <-> Hermes`

At the moment, the `Gateway` is present but the `MCP Server` process is absent. As a result, the EDA-side bridge can reach the WebSocket listener but cannot complete the end-to-end command path, which surfaces as a connection timeout.

## Scope

This recovery work is limited to the operational assets in `EDA/`:

- `start-eda-mcp.sh`
- `check-eda-mcp.sh`
- `eda-mcp-wrapper.sh`
- `eda-mcp.service` if needed for consistency

This phase does not change the `jlcmcp` application source unless recovery fails and diagnostics prove a code-level issue.

## Recovery Options

### Option 1: Manual one-off startup

Start `Gateway` and `MCP Server` directly by command line, then verify process presence.

Pros:
- Fastest path to confirm the diagnosis

Cons:
- Not durable
- Leaves script defects unresolved

### Option 2: Repair EDA operational scripts first

Fix script executability and make startup/check behavior consistent, then use the scripts to launch and verify the stack.

Pros:
- Still fast
- Produces a repeatable recovery path
- Reduces the chance of the same operational miss recurring immediately

Cons:
- Slightly larger change than manual startup

### Option 3: Full service hardening

Repair scripts and systemd behavior in one pass.

Pros:
- Best long-term reliability

Cons:
- Broader scope than necessary for first recovery

## Recommended Approach

Choose **Option 2**.

It preserves the user priority of restoring service quickly while also fixing the operational paper cuts already visible in the repository. This gives a reliable local recovery command without expanding into a larger refactor or code-level investigation too early.

## Planned Changes

### 1. Script usability

- Add execute permission to the `EDA` shell scripts that are intended to be run directly.
- Keep script entry points unchanged so existing documentation remains mostly valid.

### 2. Startup consistency

- Ensure the startup path clearly launches `Gateway` only when needed.
- Ensure it launches `MCP Server` and verifies that the process remains alive after startup.
- Make runtime configuration explicit where helpful, including `GATEWAY_WS_URL`, even though the upstream code has a default value.

### 3. Health check clarity

- Keep `check-eda-mcp.sh` focused on the signals that matter for this outage:
  - `Gateway` listening
  - `MCP Server` process present
  - optional LCEDA mode visibility
- Make the script runnable as the primary first-line diagnostic.

### 4. Escalation path

If `MCP Server` still exits immediately after script repair and startup, stop broadening the fix and collect:

- process stderr/stdout
- dependency/build state
- runtime environment mismatches

That becomes a second-stage diagnostic task.

## Verification Criteria

Recovery is considered successful when all of the following are true:

- `lsof -i :18800` shows the `Gateway` listener.
- `pgrep -af "jlcmcp/dist/index.js"` shows a live `MCP Server` process.
- `check-eda-mcp.sh` reports both services as running.
- LCEDA Pro no longer reports the bridge timeout and moves to a connected state.

## Risks

- A successful process launch may still fail functionally if LCEDA-side permissions or extension state are wrong.
- `MCP Server` may terminate immediately because of missing dependencies or runtime errors not yet surfaced in the current scripts.
- systemd behavior may still need a follow-up pass if the user wants boot-time or crash recovery guarantees.

## Out Of Scope

- Refactoring `jlcmcp` source code
- Adding new bridge features
- Reworking the EDA plugin itself
- Deep systemd hardening beyond what is required for recovery consistency
