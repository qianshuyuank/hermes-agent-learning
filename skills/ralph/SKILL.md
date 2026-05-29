---
name: ralph
description: "Ralph is an autonomous PRD-driven agent loop. Use to: create PRDs, convert PRDs to prd.json, run Ralph's autonomous execution loop. Triggers: create a prd, write prd for, plan this feature, convert this prd, turn this into ralph format, run ralph, start ralph loop, execute ralph."
user-invocable: true
---

# Ralph - Autonomous PRD-Driven Agent Loop

Ralph is an autonomous AI agent that executes PRDs iteratively. It has three entry points:

---

## Entry A: PRD Generator (ralph:prd)

**Trigger words:** `create a prd`, `write prd for`, `plan this feature`, `requirements for`, `spec out`

### Clarifying Questions (ask 3-5)

Ask only critical questions where the initial prompt is ambiguous. Format with lettered options:

```
1. What is the primary goal of this feature?
   A. [Option A]
   B. [Option B]
   C. [Option C]
   D. Other: [specify]

2. Who is the target user?
   A. [Option A]
   B. [Option B]
   ...
```

### PRD Structure

Save to `./ralph/tasks/prd-[feature-name].md`

1. **Introduction/Overview** - Brief description of the feature and problem it solves
2. **Goals** - Specific, measurable objectives (bullet list)
3. **User Stories** - Each with title, description ("As a [user]..."), and verifiable acceptance criteria
4. **Functional Requirements** - Numbered list (FR-1, FR-2...)
5. **Non-Goals** - What this will NOT include
6. **Technical Considerations** - Constraints, dependencies, integration points
7. **Open Questions** - Remaining questions needing clarification

### User Story Format

```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Typecheck/lint passes
- [ ] **[UI stories only]** Verify in browser using dev-browser skill
```

**Important:** Acceptance criteria must be verifiable, not vague. UI stories must include visual verification.

### After PRD Generation

Ask the user: "Would you like me to convert this PRD to prd.json format for Ralph execution?"

---

## Entry B: PRD Converter (ralph:convert)

**Trigger words:** `convert this prd`, `turn this into ralph format`, `create prd.json from this`, `ralph json`

### Output Format

```json
{
  "project": "[Project Name]",
  "branchName": "ralph/[feature-name-kebab-case]",
  "description": "[Feature description]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": ["Criterion 1", "Criterion 2", "Typecheck passes"],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### Story Size Rules (Critical)

**Each story must be completable in ONE Ralph iteration.**

Right-sized:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard" → Split into schema, queries, UI components, filters
- "Add authentication" → Split into schema, middleware, login UI, session handling

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

### Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later ones.

Correct order:
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

### Acceptance Criteria Rules

Each criterion must be verifiable. Always include as final criterion:
```
"Typecheck passes"
```

For UI stories, also include:
```
"Verify in browser using dev-browser skill"
```

### Conversion Rules

1. Each user story becomes one JSON entry
2. IDs: Sequential (US-001, US-002, etc.)
3. Priority: Based on dependency order, then document order
4. All stories: `passes: false` and empty `notes`
5. branchName: Derive from feature name, kebab-case, prefixed with `ralph/`
6. Always add: "Typecheck passes" to every story's acceptance criteria

### Archival Logic

Before writing a new prd.json, check if there is an existing one from a different feature:

1. Read current `prd.json` if it exists
2. Check if `branchName` differs from the new feature's branch name
3. If different AND `progress.txt` has content beyond the header:
   - Create archive folder: `archive/YYYY-MM-DD-feature-name/`
   - Copy current `prd.json` and `progress.txt` to archive
   - Reset `progress.txt` with fresh header

### Validation Checklist

Before saving prd.json:
- [ ] Previous run archived (if prd.json exists with different branchName)
- [ ] Each story is completable in one iteration
- [ ] Stories are ordered by dependency (schema to backend to UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser using dev-browser skill" as criterion
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story

---

## Entry C: Ralph Executor (ralph:run)

**Trigger words:** `run ralph`, `start ralph loop`, `execute ralph`, `ralph go`

### Setup

1. Read `prd.json` from `./ralph/prd.json`
2. Initialize `./ralph/progress.txt` if it doesn't exist (header: `| ID | Title | Status | Date | Notes |`)
3. Check archival condition: if `branchName` in new prd.json differs from existing, archive old run first

### Main Loop (Orchestrator Pattern)

```
max_iterations = 20 (or provided argument)

loop until complete or max_iterations reached:
  1. Find lowest priority story where passes=false
  2. If none found → COMPLETE
  3. Spawn leaf subagent to execute story
  4. On success:
     - Update prd.json: set that story's passes=true
     - Append to progress.txt
  5. Increment iteration
```

### Story Execution Strategy

Auto-decide based on story size:
- **Small stories** (single file changes, simple logic): Execute directly
- **Large stories** (multiple components, complex logic): Use writing-plans first, then execute

### COMPLETE Signal

When all stories have `passes=true`:

```
============================================
COMPLETE: [project name]
============================================

All [N] stories completed in [X] iterations.

Archived: ./ralph/archive/
Branch: [branchName]
```

### Progress Tracking

Append to `progress.txt` on each story completion:

```
| US-001 | Add status field | PASS | 2024-01-15 | |
```

---

## Files

- `./ralph/prd.json` - The PRD in structured JSON format
- `./ralph/progress.txt` - Iteration progress log
- `./ralph/archive/` - Archived runs from previous features