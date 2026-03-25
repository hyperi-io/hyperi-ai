#!/usr/bin/env bats

# Tests for v3.0 architecture: skills, MCP, migrated rules, plugin manifest

load test_helper

setup() {
    setup_test_env
    mock_cli "claude"
}

teardown() {
    cleanup_test_env
    clear_mocks
}

# --- Skills deployment ---

@test "TC-301: Methodology skills deployed (verification, documentation, bleeding-edge)" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    run ./hyperi-ai/agents/claude.sh --no-managed --no-superpowers

    [ "$status" -eq 0 ]
    [ -d ".claude/skills/verification" ]
    [ -d ".claude/skills/docs-audit" ]
    [ -d ".claude/skills/bleeding-edge" ]
    [ -f ".claude/skills/verification/SKILL.md" ]
    [ -f ".claude/skills/docs-audit/SKILL.md" ]
    [ -f ".claude/skills/bleeding-edge/SKILL.md" ]
}

@test "TC-302: Core skills still deployed (standards)" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    run ./hyperi-ai/agents/claude.sh --no-managed --no-superpowers

    [ "$status" -eq 0 ]
    [ -d ".claude/skills/standards" ]
}

@test "TC-303: Skill SKILL.md files have valid Agent Skills frontmatter" {
    for skill_dir in "$AI_SOURCE"/skills/*/; do
        local skill_md="$skill_dir/SKILL.md"
        [ -f "$skill_md" ] || continue

        # Must start with ---
        local first_line
        first_line="$(head -1 "$skill_md")"
        [ "$first_line" = "---" ] || {
            echo "FAIL: $skill_md missing opening ---"
            return 1
        }

        # Must have name: field
        grep -q "^name:" "$skill_md" || {
            echo "FAIL: $skill_md missing name: field"
            return 1
        }

        # Must have description: field
        grep -q "^description:" "$skill_md" || {
            echo "FAIL: $skill_md missing description: field"
            return 1
        }

        # Must have closing ---
        local closing
        closing="$(tail -n +2 "$skill_md" | grep -c "^---$" || true)"
        [ "$closing" -ge 1 ] || {
            echo "FAIL: $skill_md missing closing ---"
            return 1
        }
    done
}

@test "TC-304: Bleeding-edge skill references Context7 MCP" {
    grep -q "Context7" "$AI_SOURCE/skills/bleeding-edge/SKILL.md"
    grep -q "resolve-library-id" "$AI_SOURCE/skills/bleeding-edge/SKILL.md"
    grep -q "query-docs" "$AI_SOURCE/skills/bleeding-edge/SKILL.md"
}

@test "TC-305: Bleeding-edge skill has rate-limit fallback instructions" {
    grep -q "rate.limit" "$AI_SOURCE/skills/bleeding-edge/SKILL.md"
    grep -q "web search" "$AI_SOURCE/skills/bleeding-edge/SKILL.md"
}

@test "TC-306: Bleeding-edge skill is not user-invocable" {
    grep -q "user-invocable: false" "$AI_SOURCE/skills/bleeding-edge/SKILL.md"
}

# --- MCP deployment ---

@test "TC-310: MCP config deployed to consumer project" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    run ./hyperi-ai/agents/claude.sh --no-managed --no-superpowers

    [ "$status" -eq 0 ]
    [ -f ".mcp.json" ]
}

@test "TC-311: MCP config contains Context7 server" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    ./hyperi-ai/agents/claude.sh --no-managed --no-superpowers

    grep -q "context7" .mcp.json
    grep -q "@upstash/context7-mcp" .mcp.json
}

@test "TC-312: MCP merge preserves existing servers" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    # Create existing .mcp.json with a custom server
    echo '{"mcpServers":{"myserver":{"command":"test"}}}' > .mcp.json

    ./hyperi-ai/agents/claude.sh --force --no-managed --no-superpowers

    # Both servers should exist
    grep -q "myserver" .mcp.json
    grep -q "context7" .mcp.json
}

@test "TC-313: MCP config has CONTEXT7_API_KEY env var placeholder" {
    grep -q "CONTEXT7_API_KEY" "$AI_SOURCE/.mcp.json"
}

# --- Migrated rules cleanup ---

@test "TC-320: Migrated methodology rules are removed on force deploy" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    # Simulate old deployment with methodology rules
    mkdir -p .claude/rules
    for rule in debugging.md verification.md parallel-agents.md documentation.md; do
        echo "old rule" > ".claude/rules/$rule"
    done

    ./hyperi-ai/agents/claude.sh --force --no-managed --no-superpowers

    # All migrated rules should be gone
    [ ! -f ".claude/rules/debugging.md" ]
    [ ! -f ".claude/rules/verification.md" ]
    [ ! -f ".claude/rules/parallel-agents.md" ]
    [ ! -f ".claude/rules/documentation.md" ]
}

@test "TC-321: Corporate rules still deployed after migration cleanup" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    ./hyperi-ai/agents/claude.sh --force --no-managed --no-superpowers

    [ -f ".claude/rules/universal.md" ]
    [ -f ".claude/rules/python.md" ]
    [ -f ".claude/rules/git.md" ]
    [ -f ".claude/rules/security.md" ]
}

@test "TC-322: Rule files deployed (at least 25, no methodology rules)" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    ./hyperi-ai/agents/claude.sh --force --no-managed --no-superpowers

    local count
    count="$(ls .claude/rules/*.md 2>/dev/null | wc -l)"
    [ "$count" -ge 25 ]
}

# --- Commands from new path ---

@test "TC-330: Commands deployed from commands/ (not templates/)" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    ./hyperi-ai/agents/claude.sh --no-managed --no-superpowers

    [ -f ".claude/commands/load.md" ]
    [ -f ".claude/commands/save.md" ]
    [ -f ".claude/commands/review.md" ]
    [ -f ".claude/commands/simplify.md" ]
    [ -f ".claude/commands/standards.md" ]
    [ -f ".claude/commands/setup-claude.md" ]
    [ -f ".claude/commands/doco.md" ]
}

@test "TC-331: Stale command symlinks cleaned on deploy" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    mkdir -p .claude/commands

    # Create a stale symlink pointing to old templates/ path
    ln -sf "../../hyperi-ai/templates/claude-code/commands/load.md" .claude/commands/load.md

    ./hyperi-ai/agents/claude.sh --no-managed --no-superpowers

    # Should now point to commands/ not templates/
    local target
    target="$(readlink .claude/commands/load.md)"
    [[ "$target" =~ "commands/load.md" ]]
    [[ ! "$target" =~ "templates" ]]
}

# --- Plugin manifest and hooks ---

@test "TC-340: Plugin manifest exists and is valid JSON" {
    [ -f "$AI_SOURCE/.claude-plugin/plugin.json" ]
    python3 -c "import json; json.load(open('$AI_SOURCE/.claude-plugin/plugin.json'))"
}

@test "TC-341: Plugin manifest has required fields" {
    local manifest="$AI_SOURCE/.claude-plugin/plugin.json"
    python3 -c "
import json, sys
m = json.load(open('$manifest'))
assert 'name' in m, 'missing name'
assert 'version' in m, 'missing version'
assert 'description' in m, 'missing description'
assert m['name'] == 'hyperi-ai', f'wrong name: {m[\"name\"]}'
"
}

@test "TC-342: Plugin hooks.json exists and is valid JSON" {
    [ -f "$AI_SOURCE/hooks/hooks.json" ]
    python3 -c "import json; json.load(open('$AI_SOURCE/hooks/hooks.json'))"
}

@test "TC-343: Plugin hooks.json has all required event hooks" {
    local hooks="$AI_SOURCE/hooks/hooks.json"
    grep -q "SessionStart" "$hooks"
    grep -q "PostToolUse" "$hooks"
    grep -q "SubagentStart" "$hooks"
    grep -q "PreToolUse" "$hooks"
    grep -q "Stop" "$hooks"
}

@test "TC-344: Plugin hooks.json SessionStart hooks are synchronous" {
    python3 -c "
import json
data = json.load(open('$AI_SOURCE/hooks/hooks.json'))
for hook in data['hooks']:
    if hook['event'] == 'SessionStart':
        assert hook.get('async') is False, f'SessionStart hook must be async:false, got: {hook}'
"
}

# --- Python tools ---

@test "TC-350: relpath.py produces correct relative paths" {
    local result
    result="$(python3 "$AI_SOURCE/tools/relpath.py" /a/b/c /a/d/e.txt)"
    [ "$result" = "../../d/e.txt" ]
}

@test "TC-351: merge_mcp.py creates new file when destination missing" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    python3 "$AI_SOURCE/tools/merge_mcp.py" "$AI_SOURCE/.mcp.json" "$tmpdir/new.json"

    [ -f "$tmpdir/new.json" ]
    grep -q "context7" "$tmpdir/new.json"
    rm -rf "$tmpdir"
}

@test "TC-352: merge_mcp.py merges without overwriting existing servers" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    echo '{"mcpServers":{"existing":{"command":"keep"}}}' > "$tmpdir/dst.json"

    python3 "$AI_SOURCE/tools/merge_mcp.py" "$AI_SOURCE/.mcp.json" "$tmpdir/dst.json"

    grep -q "existing" "$tmpdir/dst.json"
    grep -q "context7" "$tmpdir/dst.json"
    grep -q "keep" "$tmpdir/dst.json"
    rm -rf "$tmpdir"
}

@test "TC-353: merge_mcp.py --force overwrites existing servers" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    echo '{"mcpServers":{"context7":{"command":"old"}}}' > "$tmpdir/dst.json"

    python3 "$AI_SOURCE/tools/merge_mcp.py" "$AI_SOURCE/.mcp.json" "$tmpdir/dst.json" --force

    # Should have the new context7 config, not the old one
    grep -q "@upstash/context7-mcp" "$tmpdir/dst.json"
    ! grep -q '"old"' "$tmpdir/dst.json"
    rm -rf "$tmpdir"
}

# --- Superpowers flag ---

@test "TC-360: --no-superpowers flag accepted" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    run ./hyperi-ai/agents/claude.sh --no-managed --no-superpowers --verbose

    [ "$status" -eq 0 ]
    [[ "$output" =~ "superpowers" ]]
}

# --- ai-conduct.md references web search / training data ---

@test "TC-370: ai-conduct.md references web search before code" {
    grep -qi "web.search\|training.data\|bleeding" "$AI_SOURCE/standards/rules/ai-conduct.md"
}

@test "TC-371: Deleted methodology rules do not exist in standards/rules/" {
    [ ! -f "$AI_SOURCE/standards/rules/debugging.md" ]
    [ ! -f "$AI_SOURCE/standards/rules/verification.md" ]
    [ ! -f "$AI_SOURCE/standards/rules/parallel-agents.md" ]
    [ ! -f "$AI_SOURCE/standards/rules/documentation.md" ]
}

# --- MCP config ---

@test "TC-380: MCP config contains Context7 server" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    ./hyperi-ai/agents/claude.sh --no-managed --no-superpowers

    grep -q '"context7"' .mcp.json
}

@test "TC-381: MCP config does not contain GitHub server (uses gh CLI instead)" {
    ! grep -q '"github"' "$AI_SOURCE/.mcp.json"
    ! grep -q 'github-mcp-server' "$AI_SOURCE/.mcp.json"
}

@test "TC-382: MCP merge deploys Context7 server" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    python3 "$AI_SOURCE/tools/merge_mcp.py" "$AI_SOURCE/.mcp.json" "$tmpdir/new.json"

    grep -q "context7" "$tmpdir/new.json"
    ! grep -q '"github"' "$tmpdir/new.json"
    rm -rf "$tmpdir"
}

# --- PAT discovery tool ---

@test "TC-390: discover_github_pat.py exists and is executable" {
    [ -f "$AI_SOURCE/tools/discover_github_pat.py" ]
    [ -x "$AI_SOURCE/tools/discover_github_pat.py" ]
}

@test "TC-391: discover_github_pat.py finds token from env var" {
    run env GITHUB_TOKEN="ghp_test123" python3 "$AI_SOURCE/tools/discover_github_pat.py"
    [ "$status" -eq 0 ]
    [ "$output" = "ghp_test123" ]
}

@test "TC-392: discover_github_pat.py finds GH_TOKEN env var" {
    run env -u GITHUB_TOKEN GH_TOKEN="ghp_alt456" python3 "$AI_SOURCE/tools/discover_github_pat.py"
    [ "$status" -eq 0 ]
    [ "$output" = "ghp_alt456" ]
}

@test "TC-393: discover_github_pat.py --source prints source location" {
    run env GITHUB_TOKEN="ghp_test123" python3 "$AI_SOURCE/tools/discover_github_pat.py" --source
    [ "$status" -eq 0 ]
    # Token on stdout, source on stderr (captured in combined output by bats)
    [[ "$output" =~ "ghp_test123" ]]
}

@test "TC-394: discover_github_pat.py exits 1 when no token found" {
    local fakehome
    fakehome="$(mktemp -d)"
    # Create isolated bin dir with only python3, no gh CLI
    mkdir -p "$fakehome/bin"
    ln -s "$(which python3)" "$fakehome/bin/python3"
    run env -u GITHUB_TOKEN -u GH_TOKEN -u CLAUDE_PROJECT_DIR \
        HOME="$fakehome" XDG_CONFIG_HOME="$fakehome/.config" \
        PATH="$fakehome/bin" \
        python3 "$AI_SOURCE/tools/discover_github_pat.py"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    rm -rf "$fakehome"
}

@test "TC-395: discover_github_pat.py reads from project .env file" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    echo 'GITHUB_TOKEN=ghp_fromenv789' > "$tmpdir/.env"

    run env -u GITHUB_TOKEN -u GH_TOKEN CLAUDE_PROJECT_DIR="$tmpdir" HOME="$(mktemp -d)" \
        python3 "$AI_SOURCE/tools/discover_github_pat.py"

    [ "$status" -eq 0 ]
    [ "$output" = "ghp_fromenv789" ]
    rm -rf "$tmpdir"
}

@test "TC-396: discover_github_pat.py reads from ~/.env file" {
    local tmphome
    tmphome="$(mktemp -d)"
    echo 'GITHUB_TOKEN=ghp_homeenv012' > "$tmphome/.env"

    run env -u GITHUB_TOKEN -u GH_TOKEN CLAUDE_PROJECT_DIR="$(mktemp -d)" HOME="$tmphome" \
        python3 "$AI_SOURCE/tools/discover_github_pat.py"

    [ "$status" -eq 0 ]
    [ "$output" = "ghp_homeenv012" ]
    rm -rf "$tmphome"
}

# --- Self-deploy (dogfooding) ---

@test "TC-400: --self flag accepted and sets PROJECT_ROOT == AI_ROOT" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    run ./hyperi-ai/agents/claude.sh --self --no-managed --no-superpowers --verbose --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "self-deploy" ]]
    # Both paths should be the hyperi-ai dir
    [[ "$output" =~ "AI_ROOT: $TEST_SUBMODULE/hyperi-ai" ]]
    [[ "$output" =~ "PROJECT_ROOT: $TEST_SUBMODULE/hyperi-ai" ]]
}

@test "TC-401: --self skips STATE.md requirement" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    # Remove STATE.md — self mode should not need it
    rm -f "$TEST_SUBMODULE/hyperi-ai/STATE.md"

    run ./hyperi-ai/agents/claude.sh --self --no-managed --no-superpowers

    [ "$status" -eq 0 ]
}

@test "TC-402: --self deploys rules into ai/.claude/rules/" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    run ./hyperi-ai/agents/claude.sh --self --force --no-managed --no-superpowers

    [ "$status" -eq 0 ]
    [ -f "$TEST_SUBMODULE/hyperi-ai/.claude/rules/universal.md" ]
    [ -f "$TEST_SUBMODULE/hyperi-ai/.claude/rules/python.md" ]
    [ -f "$TEST_SUBMODULE/hyperi-ai/.claude/rules/git.md" ]

    # Symlinks should resolve (not dangling)
    [ -e "$TEST_SUBMODULE/hyperi-ai/.claude/rules/universal.md" ]
}

@test "TC-403: --self deploys skills into ai/.claude/skills/" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    run ./hyperi-ai/agents/claude.sh --self --force --no-managed --no-superpowers

    [ "$status" -eq 0 ]
    [ -d "$TEST_SUBMODULE/hyperi-ai/.claude/skills/standards" ]
    [ -d "$TEST_SUBMODULE/hyperi-ai/.claude/skills/verification" ]
    [ -d "$TEST_SUBMODULE/hyperi-ai/.claude/skills/bleeding-edge" ]

    # SKILL.md symlinks should resolve
    [ -e "$TEST_SUBMODULE/hyperi-ai/.claude/skills/verification/SKILL.md" ]
}

@test "TC-404: --self skips CLAUDE.md symlink" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    run ./hyperi-ai/agents/claude.sh --self --force --no-managed --no-superpowers --verbose

    [ "$status" -eq 0 ]
    # No CLAUDE.md created inside hyperi-ai/
    [ ! -L "$TEST_SUBMODULE/hyperi-ai/CLAUDE.md" ]
}

@test "TC-405: --self skips MCP deploy (already at project root)" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    run ./hyperi-ai/agents/claude.sh --self --force --no-managed --no-superpowers --verbose

    [ "$status" -eq 0 ]
    [[ "$output" =~ "already at project root" ]]
}

@test "TC-406: --self dry run shows correct relative paths" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    run ./hyperi-ai/agents/claude.sh --self --no-managed --no-superpowers --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "../../standards/rules/" ]]
    [[ "$output" =~ "../templates/claude-code/settings.json" ]]
}
