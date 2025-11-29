# Save Session Progress

Save current progress to STATE.md and clean up documentation.

This command can be run multiple times during a session to checkpoint progress, or at the end of a session before context compression.

## Save Checklist

1. **Update and Clean STATE.md**:

   **First, add current session:**
   - Document what was accomplished this session
   - Add any important decisions or changes
   - Update completion status for tasks
   - Note any blockers or issues for next session

   **Then, rationalize STATE.md (remove stale info, update changed info):**

   **ALWAYS PRESERVE (never remove):**
   - **CRITICAL section** at top (HyperCI release automation rules, core policies)
   - **Architecture decisions** (why we chose X over Y, design patterns)
   - **Current session** (just added above)
   - **Previous 1-2 sessions** (recent context for continuity)
   - **Long-term strategic goals** (multi-session objectives)
   - **Known blockers/issues** (unresolved problems)
   - **Migration paths** (e.g., "Strategic Goal: Replace ci_lib with hs-lib")

   **SAFE TO REMOVE:**
   - Completed sessions older than 2-3 sessions (move to ARCHIVE.md if significant)
   - Deprecated implementation details (replaced by refactoring)
   - Duplicate information (if same info appears in multiple places)
   - Temporary notes that are no longer relevant
   - Steps/checklists that are now automated

   **UPDATE (don't remove, just fix):**
   - File paths that changed due to refactoring
   - API examples that changed
   - Status markers that are outdated (e.g., "In Progress" → "Complete")
   - Version numbers or dependency info

   **WHEN IN DOUBT:**
   - **Ask the developer before removing** anything that might be important
   - Err on the side of keeping information (better verbose than missing context)
   - If unsure whether something is "architecture decision" or "implementation detail", keep it

2. **Clean up TODO.md**:
   - **REMOVE all completed tasks** (they belong in STATE.md, not TODO.md)
   - Add new tasks discovered during work
   - Reprioritize remaining tasks if necessary
   - TODO.md should only contain active/pending work

3. **Check git status**:
   - Any uncommitted changes?
   - Should changes be committed before stopping?
   - Are there any .tmp/ files to clean up?

4. **Review test status**:
   - Did all tests pass?
   - Any skipped or failing tests to note?

5. **Check documentation quality**:
   - **Fix markdown linting issues** in CLAUDE.md, STATE.md, TODO.md
   - Common issues to fix:
     - Blank lines around headings (MD022)
     - Blank lines around lists (MD032)
     - Blank lines around fenced code blocks (MD031)
     - Specify language for code blocks (MD040)
     - Multiple consecutive blank lines (MD012)
   - Use IDE linter feedback or ignore if minor
   - Keep fixes minimal (don't rewrite entire files)

6. **Summary for Developer**:
   - Briefly summarize what was accomplished
   - List any TODO items for next session
   - Highlight any issues or blockers
   - Confirm all documentation is updated

## Save complete

After completing the checklist above, provide a concise summary of what was saved and confirm all documentation is updated.
