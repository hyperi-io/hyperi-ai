# CAG-Heavy Injection Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate context injection from lean CAG+RAG to CAG-heavy, pre-loading all relevant standards, skills, and project context at session start.

**Architecture:** Single `inject_cag_payload()` function in `hooks/common.py` replaces the current piecemeal injection. Called by startup, compaction, and subagent hooks. Full payload is ~24K tokens (~2.4% of 1M window).

**Tech Stack:** Python 3.12+ (stdlib only), BATS (testing)

**Spec:** `docs/superpowers/specs/2026-03-17-cag-heavy-injection-design.md`

---

## Chunk 1: Core Injection Refactor

### Task 1: Add `inject_cag_payload()` to `hooks/common.py`

**Files:**
- Modify: `hooks/common.py` (add new function after `inject_rules()` at ~line 291)

- [ ] **Step 1: Write `inject_cag_payload()` function**

Add after the existing `inject_rules()` function. This is the new unified
entry point. It composes the full CAG payload by calling `inject_rules()`
for tech detection, then adding common rules, skills, and STATE.md.

```python
def inject_cag_payload(project_dir: Path) -> Tuple[str, List[str]]:
    """Build the full CAG payload for 1M context window injection.

    Loads: UNIVERSAL + detected tech rules + all common rules + all skills
    + STATE.md + user overrides + bash efficiency + tool survey.

    Returns (payload_text, list_of_loaded_names).
    """
    if os.environ.get("HYPERI_CAG_LEAN") == "1":
        return inject_rules(project_dir)

    parts: List[str] = []
    loaded: List[str] = []

    rules_dir = get_rules_dir(project_dir)
    if not rules_dir or not rules_dir.is_dir():
        return inject_rules(project_dir)  # fallback

    # 1. UNIVERSAL.md (always)
    universal = rules_dir / "UNIVERSAL.md"
    if universal.is_file():
        parts.append(universal.read_text(encoding="utf-8").strip())
        parts.append("")
        loaded.append("UNIVERSAL")

    # 2. Detected tech rules (language + infrastructure via detect_markers)
    for tech_name, rule_file in detect_technologies(project_dir):
        rule_path = rules_dir / rule_file
        if rule_path.is_file():
            parts.append("---")
            parts.append(rule_path.read_text(encoding="utf-8").strip())
            parts.append("")
            loaded.append(tech_name)

    # 3. All common rules (no detect_markers — always relevant)
    tech_files = {r[1] for r in _load_tech_detections(rules_dir)}
    for rule_path in sorted(rules_dir.glob("*.md")):
        name = rule_path.name
        if name == "UNIVERSAL.md":
            continue
        if name in tech_files:
            continue  # already loaded by detection or skipped
        if name in {r[1] for r in detect_technologies(project_dir)}:
            continue  # already loaded above
        fm = _parse_rules_frontmatter(rule_path)
        if fm.get("detect_markers"):
            continue  # tech rule not detected for this project — skip
        parts.append("---")
        parts.append(rule_path.read_text(encoding="utf-8").strip())
        parts.append("")
        loaded.append(rule_path.stem)

    # 4. All skill content (strip YAML frontmatter)
    ai_dir = get_ai_dir(project_dir)
    if ai_dir:
        skills_dir = ai_dir / "skills"
        if skills_dir.is_dir():
            for skill_dir in sorted(skills_dir.iterdir()):
                skill_file = skill_dir / "SKILL.md"
                if skill_file.is_file():
                    content = skill_file.read_text(encoding="utf-8")
                    # Strip YAML frontmatter
                    if content.startswith("---"):
                        end = content.find("\n---", 3)
                        if end != -1:
                            content = content[end + 4:].lstrip("\n")
                    parts.append("---")
                    parts.append(f"# Skill: {skill_dir.name}")
                    parts.append(content.strip())
                    parts.append("")
                    loaded.append(f"skill:{skill_dir.name}")

    # 5. Project STATE.md
    state_file = project_dir / "STATE.md"
    if state_file.is_file():
        parts.append("---")
        parts.append("# Project Context (STATE.md)")
        parts.append(state_file.read_text(encoding="utf-8").strip())
        parts.append("")
        loaded.append("STATE")

    # 6. User standards override (highest priority — loaded last)
    xdg = os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
    user_stds = Path(xdg) / "hyperi-ai" / "USER-CODING-STANDARDS.md"
    if user_stds.is_file():
        parts.append("---")
        parts.append("# User Coding Standards (OVERRIDE — these take priority)")
        parts.append(user_stds.read_text(encoding="utf-8").strip())
        parts.append("")
        loaded.append("USER")

    # 7. Bash efficiency rules
    parts.append("---")
    parts.append(bash_efficiency_rules())
    parts.append("")

    # 8. Tool survey
    available, installable, unknown = survey_tools()
    parts.append(format_tool_survey(available, installable, unknown))

    # Summary
    parts.append("")
    parts.append(f"[CAG payload: {', '.join(loaded)}]")

    return "\n".join(parts), loaded
```

**Note on common rules loading (step 3):** The logic iterates all rules files,
skips UNIVERSAL (already loaded), skips any file whose name appears in the tech
detections list (either loaded or deliberately not detected for this project),
and loads the rest. This catches: security.md, error-handling.md,
design-principles.md, testing.md, mocks-policy.md, git.md, code-style.md,
config-and-logging.md.

- [ ] **Step 2: Verify the function is syntactically correct**

Run: `python3 -c "import hooks.common"` from the project root.
Expected: No import errors.

- [ ] **Step 3: Commit**

```bash
git add hooks/common.py
git commit -m "feat: add inject_cag_payload() for 1M context CAG-heavy injection"
```

---

### Task 2: Update `hooks/inject_standards.py` to use CAG payload

**Files:**
- Modify: `hooks/inject_standards.py`

- [ ] **Step 1: Replace inject_rules + bash_efficiency + tool_survey with single call**

The current flow (lines 57-83) calls `inject_rules()`, then separately
appends bash efficiency rules and tool survey. Replace with a single call
to `inject_cag_payload()` which includes all of these.

Replace the injection section (approximately lines 57-83) with:

```python
    # --- Inject full CAG payload (standards + skills + state + tools) ---
    text, loaded = common.inject_cag_payload(project_dir)
    if text:
        print(text)
```

Remove the separate bash_efficiency_rules() and survey_tools() calls that
follow — they're now inside `inject_cag_payload()`.

Keep the date injection (lines 57-62) and reattach message (lines 69-71)
BEFORE the CAG payload call. Keep the migration helper and submodule
update at the top unchanged.

- [ ] **Step 2: Verify hook runs without error**

Run: `CLAUDE_PROJECT_DIR=/projects/hyperi-ai python3 hooks/inject_standards.py`
Expected: Output includes UNIVERSAL rules, detected tech rules, common rules,
skill content, STATE.md, bash efficiency, and tool survey. Should see
`[CAG payload: UNIVERSAL, ...]` summary at the end.

- [ ] **Step 3: Commit**

```bash
git add hooks/inject_standards.py
git commit -m "fix: use inject_cag_payload() in startup hook"
```

---

### Task 3: Simplify `hooks/on_compact.py`

**Files:**
- Modify: `hooks/on_compact.py`

- [ ] **Step 1: Replace three-tier recovery with single CAG re-injection**

Replace the body (lines 25-59) with:

```python
    project_dir = common.get_project_dir()

    # Date stamp (models hallucinate dates after compaction)
    print(f"\n# Current Date: {datetime.now().strftime('%Y-%m-%d %A')}\n")

    # Full CAG re-injection — same payload as startup
    text, loaded = common.inject_cag_payload(project_dir)
    if text:
        print(text)

    print("\nContext compacted. Full standards re-injected.")
```

Remove the `/load` prompt, the separate bash_efficiency call, the separate
tool survey call, and the recovery header. The re-injected payload IS the
full recovery.

- [ ] **Step 2: Verify hook runs**

Run: `CLAUDE_PROJECT_DIR=/projects/hyperi-ai python3 hooks/on_compact.py`
Expected: Same output as startup hook, plus "Context compacted. Full standards
re-injected." at the end.

- [ ] **Step 3: Commit**

```bash
git add hooks/on_compact.py
git commit -m "fix: simplify compaction to single CAG re-injection"
```

---

### Task 4: Update `hooks/subagent_context.py`

**Files:**
- Modify: `hooks/subagent_context.py`

- [ ] **Step 1: Switch from inject_rules to inject_cag_payload**

Replace the `inject_rules` call (line 31) with `inject_cag_payload`.
The return signature is the same `Tuple[str, List[str]]` so the rest
of the code stays identical.

```python
    text, loaded = common.inject_cag_payload(project_dir)
```

- [ ] **Step 2: Verify hook output is valid JSON**

Run: `echo '{}' | CLAUDE_PROJECT_DIR=/projects/hyperi-ai python3 hooks/subagent_context.py`
Expected: Valid JSON with `additionalContext` field containing the full payload.

- [ ] **Step 3: Commit**

```bash
git add hooks/subagent_context.py
git commit -m "fix: use inject_cag_payload() for subagent context"
```

---

## Chunk 2: Command and Doc Updates

### Task 5: Simplify `commands/load.md`

**Files:**
- Modify: `commands/load.md`

- [ ] **Step 1: Remove standards recovery from /load**

Remove or simplify **Step 3** (Read Project Files) — STATE.md is now
pre-loaded via CAG, so `/load` only needs to read TODO.md.

Remove **Step 4** (Verify Standards Are Loaded) — standards are always
in context via CAG injection. No need to verify or force-load.

Keep: Step 1 (date), Step 2 (SSoT table), Step 5 (submodule update),
Step 6 (git sync). Renumber steps.

Update the SSoT table to note that STATE.md is now auto-loaded at startup.

- [ ] **Step 2: Verify the command still reads correctly**

Read the file and check the flow makes sense without standards recovery.

- [ ] **Step 3: Commit**

```bash
git add commands/load.md
git commit -m "fix: simplify /load — standards and STATE.md now CAG-injected"
```

---

### Task 6: Update `docs/TOKEN-ENGINEERING.md`

**Files:**
- Modify: `docs/TOKEN-ENGINEERING.md`

Already rewritten in the brainstorming phase. Verify it's consistent with
the final implementation.

- [ ] **Step 1: Read and verify accuracy**

Confirm the payload contents list matches what `inject_cag_payload()` actually
loads. Confirm approximate token numbers are labelled as such.

- [ ] **Step 2: Fix any inconsistencies found**

- [ ] **Step 3: Commit if changed**

```bash
git add docs/TOKEN-ENGINEERING.md
git commit -m "docs: align TOKEN-ENGINEERING with CAG-heavy implementation"
```

---

### Task 7: Update `tools/deploy_claude.py` help text

**Files:**
- Modify: `tools/deploy_claude.py`

- [ ] **Step 1: Find architecture description in print_summary()**

Look for text describing rules as "path-scoped, auto-inject on file read"
or similar. Update to note rules are now primarily CAG-delivered at startup,
with path-scoped delivery as a redundant fallback.

- [ ] **Step 2: Update the description**

Change the relevant line(s) to reflect CAG-heavy delivery. Keep it brief —
this is help text, not documentation.

- [ ] **Step 3: Commit**

```bash
git add tools/deploy_claude.py
git commit -m "docs: update deploy help text for CAG-heavy delivery"
```

---

### Task 8: Update stale documentation

**Files:**
- Modify: `standards/STANDARDS-QUICKSTART.md` (fix path notation)
- Modify: `docs/GEMIN-2026-JAN.md` (archive — past revisit date)
- Modify: `CONTRIBUTING.md` (verify architecture description)
- Review: All other root and docs/ markdown files for staleness

- [ ] **Step 1: Fix STANDARDS-QUICKSTART.md path notation**

Replace all 6 instances of `ai/standards/` with `hyperi-ai/standards/` to
match the current submodule name. Check for any other `ai/` references that
should be `hyperi-ai/`.

- [ ] **Step 2: Archive GEMIN-2026-JAN.md**

Rename to `docs/GEMINI-2026-JAN-ARCHIVED.md`. It's past its March 2026
revisit date. Add a note at the top: "Archived — revisit date passed.
See git log for current Gemini integration status."

- [ ] **Step 3: Update CONTRIBUTING.md architecture section**

The architecture section describes "CAG, RAG, Skills" three-layer model.
Update to reflect CAG-heavy: standards and skills are now pre-loaded via
CAG at startup. RAG (path-scoped) remains as redundant fallback. Note the
~24K token budget.

- [ ] **Step 4: Scan all docs/ and root .md files for remaining staleness**

Read each file and check for:
- Old token estimates (should say "approximately" and use measured numbers)
- References to "two-layer" or "three-tier" injection
- Outdated architecture descriptions
- Hardcoded counts that will go stale

- [ ] **Step 5: Commit all doc fixes**

```bash
git add -A docs/ standards/STANDARDS-QUICKSTART.md CONTRIBUTING.md
git commit -m "docs: update all docs for CAG-heavy architecture, fix stale refs"
```

---

## Chunk 3: Testing and Validation

### Task 9: Run existing BATS tests

**Files:**
- Read: `tests/` (existing test suite)

- [ ] **Step 1: Run full BATS test suite**

Run: `bats tests/`
Expected: All 132 tests pass. If any fail due to the injection changes
(e.g., tests that assert specific injection output format), fix them.

- [ ] **Step 2: Fix any broken tests**

Update test assertions that check injection output to match the new
CAG payload format (e.g., `[CAG payload: ...]` summary line instead of
the previous format).

- [ ] **Step 3: Run generate-rules.py --check**

Run: `python3 tools/generate-rules.py --check --verbose`
Expected: 0 errors, 0 warnings.

- [ ] **Step 4: Commit test fixes**

```bash
git add tests/
git commit -m "test: update assertions for CAG-heavy injection output"
```

---

### Task 10: Integration validation

- [ ] **Step 1: Test startup injection end-to-end**

Run: `CLAUDE_PROJECT_DIR=/projects/hyperi-ai python3 hooks/inject_standards.py`
Verify output contains:
- Current date
- UNIVERSAL rules
- Detected tech rules (at minimum bash, python)
- Common rules (security, error-handling, etc.)
- Skill content (verification, bleeding-edge, documentation)
- STATE.md content
- Bash efficiency rules
- Tool survey
- `[CAG payload: ...]` summary

- [ ] **Step 2: Test compaction re-injection**

Run: `CLAUDE_PROJECT_DIR=/projects/hyperi-ai python3 hooks/on_compact.py`
Verify output matches startup (minus migration/reattach), plus
"Context compacted. Full standards re-injected."

- [ ] **Step 3: Test subagent context**

Run: `echo '{}' | CLAUDE_PROJECT_DIR=/projects/hyperi-ai python3 hooks/subagent_context.py`
Verify valid JSON with full payload in `additionalContext`.

- [ ] **Step 4: Test HYPERI_CAG_LEAN=1 rollback**

Run: `HYPERI_CAG_LEAN=1 CLAUDE_PROJECT_DIR=/projects/hyperi-ai python3 hooks/inject_standards.py`
Verify output matches the OLD lean injection (UNIVERSAL + detected tech only,
no common rules, no skills, no STATE.md).

- [ ] **Step 5: Measure actual token count of payload**

Run the Anthropic token counting script against the full startup output.
Verify it's approximately 24K tokens (within 20% tolerance).

- [ ] **Step 6: Commit any remaining fixes**

---

### Task 11: Final commit and push

- [ ] **Step 1: Run full test suite one final time**

Run: `bats tests/`
Expected: All tests pass.

- [ ] **Step 2: Check git status — no uncommitted changes**

Run: `git status --short`
Expected: Clean working tree.

- [ ] **Step 3: Rebase and push**

```bash
git pull --rebase
git push
```

- [ ] **Step 4: Verify CI passes**

Run: `gh run list --limit 2 --repo hyperi-io/hyperi-ai`
Wait for both Test and Release workflows to complete successfully.

---

## Chunk 4: Post-Implementation Audit

### Task 12: Compact rules audit

Review each compact rule against its full source standard. This is a
read-only audit — flag gaps but don't fix them in this PR.

- [ ] **Step 1: For each compact rule in standards/rules/**

Compare against the corresponding source in `standards/languages/`,
`standards/infrastructure/`, or `standards/universal/`. Flag:
- Rules present in source but missing from compact
- Nuance lost in compression
- Important patterns not captured

- [ ] **Step 2: Write audit findings**

Save to `docs/superpowers/specs/2026-03-17-compact-rules-audit.md`.
List each rule file with: OK / gaps found / action needed.

- [ ] **Step 3: Commit audit**

```bash
git add docs/superpowers/specs/2026-03-17-compact-rules-audit.md
git commit -m "docs: compact rules audit — flag gaps vs source standards"
```
