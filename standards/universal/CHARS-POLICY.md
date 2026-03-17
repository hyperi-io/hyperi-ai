---
name: chars-policy-standards
description: Permitted non-ASCII characters and emojis for all HyperI code, docs, and LLM output. Restricted to a defined set only.
---

# Character & Emoji Policy

This document defines the **only permitted non-ASCII characters and emojis** for all code, documentation, console output, and LLM usage.

## Log Levels

- **FATAL** 💥 – Irrecoverable error, application crash, or system shutdown  
- **ERROR** ❌ – Blocking issue, operation failed  
- **WARN** ⚠️ – Non-blocking issue, awareness needed  
- **INFO** *(no emoji)* – Informational messages only  
- **DEBUG** *(no emoji)* – Debugging details, plain text only  
- **TRACE** *(no emoji)* – Fine-grained tracing, plain text only  

## Core Status Indicators

- **ERROR** ❌ – Blocking issues that fail the build  
- **WARNING** ⚠️ – Non-blocking issues for awareness  
- **SUCCESS** ✅ – Everything working correctly  
- **INFO** ℹ️ – General informational messages  
- **BUG** 🐞 – Identified defect or issue  
- **PENDING** ⏳ – Task is in progress / waiting  
- **CANCELLED** 🚫 – Task or operation stopped  

## Quality & Validation

- **TEST PASS** 🟢 – Test successful  
- **TEST FAIL** 🔴 – Test failed  
- **SECURITY** 🔒 – Security-related checks  
- **PERFORMANCE** ⚡ – Speed or performance messages  

## Workflow & Process

- **STEP** ➤ – Generic step indicator  
- **NEXT** ➔ – Move to next step  
- **DONE** ✔ – Completed step  
- **BLOCKED** ⛔ – Blocked step  
- **RETRY** 🔁 – Retrying action  

## ASCII Line Drawing (Safe for all terminals)

- `─`, `│`, `┌`, `┐`, `└`, `┘`, `├`, `┤`, `┬`, `┴`, `┼` – Box drawing for tables and flow  
- `➤`, `➔`, `→` – Step / arrow indicators  
- `✔`, `✖`, `▲`, `▼` – Alternative check/cross/triangles for CLI-friendly status  

---

## Logging Restriction

⚠️ **IMPORTANT RULE**:  
For **log files (persistent logged data)**, you must use **plain ASCII characters only**.  
Even the permitted emojis and Unicode symbols listed above are **not allowed in logged output**.  

- Console / documentation / prompts → May use permitted emojis and ASCII extensions.  
- Logged data (files, streams, archives) → Must be ASCII-only.  

This ensures maximum compatibility with log shippers, parsers, and downstream systems.

---

## Usage Guidelines

**Minimal and Purposeful Use Only:**

- Use emojis sparingly and only when they add clarity
- Avoid excessive repetition (e.g., ✅ after every item)
- Prefer text for status indicators in most contexts
- ONE emoji per section/heading maximum

**Examples:**

❌ **Excessive (DISCOURAGED):**

```markdown
- Task 1 complete ✅
- Task 2 complete ✅
- Task 3 complete ✅
- Task 4 complete ✅
```

✅ **Minimal (PREFERRED):**

```markdown
## Phase 1 Complete

- Task 1 complete
- Task 2 complete
- Task 3 complete
- Task 4 complete
```

**STRICT RULE:**
No special characters, Unicode ranges, or emojis may be used beyond this approved list.
This applies to **code, comments, documentation, console output, and LLM prompts**.
**EXCEPTION:** Logged data must strip all non-ASCII, even if permitted elsewhere.
**MODERATION:** Even approved emojis should be used sparingly - prefer text for clarity.
