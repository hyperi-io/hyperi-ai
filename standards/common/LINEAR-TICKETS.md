---
name: linear-tickets-standards
description: Standards for creating, updating, and managing Linear tickets at HyperI. Includes format, labels, and AI assistant guidance.
universal: true
---

# Linear Ticket Standard

Standards for creating, updating, and managing Linear tickets at HyperI.

**Goal:** Read this file → ask your AI assistant to create/update/find Linear tickets.

---

## Quick Start

```bash
# Install Linear CLI
npm install -g @anthropics/linear-cli

# Set your API key (get from Linear Settings → API → Personal API Keys)
linear config set-token lin_api_XXXXXXXX

# Verify setup
linear teams list
linear issues list --limit 5
```

---

## Linear CLI Installation

### Step 1: Get Your API Key

1. Open [Linear Settings](https://linear.app/settings/api)
2. Click **Personal API Keys** → **Create Key**
3. Name it (e.g., "CLI Access") and copy the token
4. Token format: `lin_api_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

### Step 2: Install CLI

```bash
# Install globally
npm install -g @anthropics/linear-cli

# Or with yarn
yarn global add @anthropics/linear-cli
```

### Step 3: Configure

```bash
# Set your token
linear config set-token lin_api_XXXXXXXX

# Verify
linear config show
linear teams list
```

### Common Commands

```bash
# List issues
linear issues list --limit 20
linear issues list --status backlog
linear issues list --status in-progress

# View issue details
linear issues view DFE-123

# Create issue
linear issues create -t "Title" -d "Description"

# Update issue
linear issues update DFE-123 -d "Updated description"
```

---

## Ticket Template

**DELETE sections that don't add value.** Only keep what provides context.

### MANDATORY Fields

Every ticket MUST have:

| Field | Where | Description |
|-------|-------|-------------|
| **Title** | Title field | `<type>: <short description>` |
| **Goal** | Description | One sentence: what success looks like |
| **Definition of Done** | Description | Checkboxes for completion criteria |
| **Priority** | Linear field | 1=Urgent, 2=High, 3=Medium, 4=Low |
| **Estimate** | Linear field | Log2 scale: 1, 2, 4, 8, 16, 32 hours |

### Optional Fields

Include ONLY if they add value:

| Section | When to Include |
|---------|-----------------|
| Components | Multiple systems affected |
| Risk & Guardrails | Production changes, breaking changes |
| Acceptance Criteria | Complex feature with multiple outcomes |
| Migration Reference | Data/schema/infra migrations |
| Why Now | Non-obvious urgency |

---

## Priority Scale (Linear Field)

Use Linear's dedicated **Priority** field, not text in description.

| Priority | Value | Meaning | Response Time |
|----------|-------|---------|---------------|
| 🔴 Urgent | 1 | Production down, security issue | Drop everything |
| 🟠 High | 2 | Blocking work, deadline-driven | This sprint |
| 🟡 Medium | 3 | Important but not urgent | Next 2-4 weeks |
| ⚪ Low | 4 | Nice to have, tech debt | When capacity allows |

---

## Estimate Scale (Linear Field)

Use Linear's dedicated **Estimate** field with log2 (exponential) scale.

| Estimate | Hours | Typical Work |
|----------|-------|--------------|
| 1 | 1h | Typo fix, config change |
| 2 | 2h | Small bug fix, simple feature |
| 4 | 4h | Half-day task, moderate complexity |
| 8 | 1d | Full day, multiple files |
| 16 | 2d | Multi-day, needs design |
| 32 | 4d | Week-long, significant feature |

**Rule:** If estimate > 32, break into smaller tickets.

---

## Title Format

```text
<type>: <short description>
```

| Type | Use For | Example |
|------|---------|---------|
| `feat:` | New feature | `feat: add S3 retry logic` |
| `fix:` | Bug fix | `fix: resolve auth timeout` |
| `chore:` | Maintenance | `chore: update dependencies` |
| `docs:` | Documentation | `docs: add API examples` |
| `refactor:` | Code restructure | `refactor: extract auth module` |
| `perf:` | Performance | `perf: optimise query caching` |
| `test:` | Testing | `test: add integration tests` |

---

## Good vs Bad Examples

### ❌ BAD: Empty Template

```markdown
## > Goals
TBD

## > Components
TBD

## > Risk & Guardrails
TBD

## > Definition of Done
- [ ] Code merged

## > Acceptance Criteria
TBD
```

**Problem:** Template filled with placeholders. Wastes reader's time.

### ❌ BAD: No Priority/Estimate

```markdown
Title: Login endpoint
Description: Update the login endpoint to accept local auth
```

**Problem:** No priority, no estimate, no definition of done. Can't be planned.

### ❌ BAD: Over-documented Simple Task

```markdown
Title: fix: typo in README

## > Goals
* Primary Goal: Fix typo in README.md
* Sub-Goals:
  * Functional: Correct spelling
  * Non-functional: Improve documentation quality
  * Operational: N/A

## > Components
* Private: README.md
* Public: N/A

## > Risk & Guardrails
* Risks: None
* Guardrails: None

## > Definition of Done
- [ ] Typo fixed
- [ ] PR merged
...
```

**Problem:** 1-hour task with 200 words of documentation. Overkill.

### ✅ GOOD: Simple Task

```markdown
Title: fix: typo in README

## Goal
Fix "recieve" → "receive" in installation section.

## Definition of Done
- [ ] Typo corrected
- [ ] PR merged

Priority: 4 (Low)
Estimate: 1
```

### ✅ GOOD: Complex Task

```markdown
Title: chore: migrate Bitnami images to upstream

## Goal
Replace all Bitnami container images before Aug 28 paywall deadline.

## Components
- dfe-discovery, dfe-core, dfe-ui, dfe-apps
- Kafka migration to KRaft mode

## Risk & Guardrails
- oauth2-proxy config differs from Bitnami wrapper
- Kafka KRaft changes cluster bootstrap
- Rollback: pin to bitnami-legacy/* if blocked

## Definition of Done
- [ ] All repos updated with new image refs
- [ ] CI/CD passes with new kubectl image
- [ ] Kafka operational in KRaft mode
- [ ] No Bitnami refs remain

## Migration Reference
| Repo | Current | Replacement |
|------|---------|-------------|
| dfe-ui | bitnami/kubectl | registry.k8s.io/kubectl:v1.32.0 |
| ... | ... | ... |

Priority: 2 (High)
Estimate: 8
```

---

## AI Code Assistant Guide

### Rules for AI Assistants

1. **DO NOT fill every section.** Only include sections that add value.
2. **MANDATORY:** Goal, Definition of Done, Priority (1-4), Estimate (log2 scale)
3. **DELETE empty sections.** Never write "TBD" or "N/A".
4. **Use Linear fields.** Priority and Estimate go in Linear fields, not description text.
5. **Keep it scannable.** Bullet points over paragraphs.

### When Creating Tickets

```text
Before creating a ticket, ask:
1. Does this ticket already exist? (Search first)
2. Should this be part of an existing ticket? (Check related)
3. Is the scope right? (Not too big, not too small)
```

---

## LLM Scripts for Ticket Operations

### Script: Create New Ticket

When user asks to create a Linear ticket:

```text
STEP 1: Gather Information
- What is the goal? (one sentence)
- What type? (feat/fix/chore/docs/refactor/perf/test)
- Priority? (1=Urgent, 2=High, 3=Medium, 4=Low)
- Estimate? (1, 2, 4, 8, 16, 32 hours)
- Definition of done? (2-5 checkboxes)

STEP 2: Search for Related Tickets
Run: linear issues list --limit 30
Look for:
- Similar titles or keywords
- Same components/systems
- Parent epics that should contain this

STEP 3: Ask User
"I found these potentially related tickets:
- DFE-XXX: <title>
- DFE-YYY: <title>
Should this be:
a) A new standalone ticket
b) Added to an existing ticket
c) A sub-issue of an existing ticket?"

STEP 4: Create Ticket
If new ticket confirmed:
linear issues create \
  -t "<type>: <description>" \
  -d "<description content>" \
  -p <priority 1-4>

STEP 5: Report Back
"Created DFE-XXX: <title>
Priority: X, Estimate: Y
URL: https://linear.app/hyperi/issue/DFE-XXX"
```

### Script: Update Ticket from Work Done

When user asks to update a ticket after completing work:

```text
STEP 1: Identify the Ticket
Ask: "Which ticket should I update? (e.g., DFE-123)"
Or infer from branch name: feat/DFE-123/description

STEP 2: Gather Changes
Run: git log --oneline -10
Run: git diff main --stat
Summarise:
- Files changed
- Features added/fixed
- Tests added

STEP 3: View Current Ticket
Run: linear issues view DFE-XXX

STEP 4: Generate Update
Create update comment or description addition:
"## Progress Update (YYYY-MM-DD)
- Implemented: <summary of commits>
- Files changed: X files (+Y/-Z lines)
- Tests: <added/updated/passing>
- Remaining: <checklist items still open>"

STEP 5: Apply Update
linear issues update DFE-XXX -d "<updated description>"
Or add comment with progress.
```

### Script: Create Retrospective Ticket

When user asks to document completed work as a ticket (after the fact):

```text
STEP 1: Gather Git History
Run: git log --oneline --since="1 week ago"
Run: git diff HEAD~10 --stat
Ask: "What was the main goal of this work?"

STEP 2: Reconstruct Ticket
Generate ticket with:
- Title: infer type from commits (feat/fix/chore)
- Goal: user's stated goal
- Definition of Done: all items checked (work complete)
- What was done: summary from commits

STEP 3: Search for Existing Ticket
Run: linear issues list --limit 30
"Is this work already tracked in any of these tickets?
- DFE-XXX: <title>
- DFE-YYY: <title>"

STEP 4: Create or Update
If new: Create retrospective ticket (mark as done)
If exists: Update existing ticket with completion details
```

### Script: Find Existing Ticket

When user asks to find a ticket for current work:

```text
STEP 1: Identify Work Context
Check: git branch --show-current
Look for: DFE-XXX in branch name
Check: recent commit messages for ticket refs

STEP 2: Search Linear
Run: linear issues list --limit 30
Search keywords from:
- Current branch name
- Recent commit messages
- Files being modified

STEP 3: Present Options
"Found these potentially matching tickets:
1. DFE-XXX: <title> (Status: In Progress)
2. DFE-YYY: <title> (Status: Backlog)
3. No matching ticket found

Which applies, or should I create a new ticket?"
```

### Script: Consolidate Tickets

When user suspects duplicate or related tickets:

```text
STEP 1: List Candidates
Run: linear issues list --limit 50
Or user provides specific ticket IDs

STEP 2: Analyse for Overlap
For each pair, check:
- Similar titles?
- Same components?
- Overlapping acceptance criteria?
- Same assignee working both?

STEP 3: Recommend Action
"These tickets appear related:
- DFE-XXX: <title>
- DFE-YYY: <title>

Recommendation:
a) Merge into single ticket (if duplicate)
b) Create parent epic (if related but distinct)
c) Link as related (if loosely connected)
d) Keep separate (if truly independent)"

STEP 4: Execute
If merge: Update one ticket, close other as duplicate
If parent: Create epic, add as sub-issues
If link: Add relation in Linear
```

---

## Branch Naming

Link branches to tickets:

```text
<type>/<ticket-id>/<short-description>
```

Examples:

- `feat/DFE-123/add-retry-logic`
- `fix/DFE-456/auth-timeout`
- `chore/DFE-789/update-deps`

---

## Workflow Integration

### Starting Work

1. Find or create ticket
2. Set status to "In Progress"
3. Create branch: `<type>/<ticket-id>/<description>`

### During Work

1. Commit with ticket reference: `fix(DFE-123): resolve timeout`
2. Update ticket if scope changes

### Completing Work

1. Ensure all Definition of Done items checked
2. Create PR referencing ticket
3. Move ticket to "In Review"

### After Merge

1. Ticket auto-moves to "Done" (or move manually)
2. Add retrospective notes if learnings to capture

---

## Reference

- [Linear Keyboard Shortcuts](https://linear.app/docs/keyboard-shortcuts)
- [Linear CLI Documentation](https://github.com/anthropics/linear-cli)
- [HyperI Git Standards](GIT.md)
