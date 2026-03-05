#!/usr/bin/env python3
# Project:   HyperI AI
# File:      tools/compact-standards.py
# Purpose:   Generate compact rule versions of standards for Claude Code .claude/rules/
# Language:  Python
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED

"""
Compacts full standards files into <200 line rule versions for Claude Code.

Rules are path-scoped markdown files that Claude Code injects into context
when editing matching files. They survive context compaction, unlike skills
or conversation-loaded content.

Usage:
    python tools/compact-standards.py                  # Process all standards
    python tools/compact-standards.py --file PYTHON    # Process one standard
    python tools/compact-standards.py --dry-run        # Preview without writing

Requires:
    ANTHROPIC_API_KEY in .env or environment
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

from anthropic import Anthropic
from dotenv import load_dotenv

# Paths
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
STANDARDS_DIR = PROJECT_ROOT / "standards"
RULES_DIR = STANDARDS_DIR / "rules"

# Model for compaction — Opus for best quality, runs rarely
MODEL = "claude-opus-4-6"
MAX_OUTPUT_LINES = 200

# Mapping: standard file stem → (output name, glob patterns, subdirectory)
STANDARDS_MAP = {
    # Languages
    "languages/PYTHON": ("python.md", ['**/*.py']),
    "languages/RUST": ("rust.md", ['**/*.rs']),
    "languages/GOLANG": ("golang.md", ['**/*.go']),
    "languages/TYPESCRIPT": ("typescript.md", ['**/*.ts', '**/*.tsx', '**/*.js', '**/*.jsx']),
    "languages/CPP": ("cpp.md", ['**/*.cpp', '**/*.hpp', '**/*.cc', '**/*.h']),
    "languages/BASH": ("bash.md", ['**/*.sh']),
    "languages/SQL-CLICKHOUSE": ("clickhouse-sql.md", ['**/*.sql']),
    # Infrastructure
    "infrastructure/DOCKER": ("docker.md", ['**/Dockerfile', '**/Dockerfile.*', '**/docker-compose*.yml', '**/docker-compose*.yaml']),
    "infrastructure/K8S": ("k8s.md", ['**/Chart.yaml', '**/values.yaml', '**/templates/**/*.yaml']),
    "infrastructure/TERRAFORM": ("terraform.md", ['**/*.tf', '**/*.tfvars']),
    "infrastructure/ANSIBLE": ("ansible.md", ['**/playbook*.yml', '**/ansible.cfg', '**/roles/**/*.yml', '**/inventory/**/*']),
    # Common (no path scoping — these apply universally)
    "common/ERROR-HANDLING": ("error-handling.md", []),
    "common/TESTING": ("testing.md", []),
    "common/MOCKS-POLICY": ("mocks-policy.md", []),
    "common/SECURITY": ("security.md", []),
    "common/DESIGN-PRINCIPLES": ("design-principles.md", []),
    "common/PKI": ("pki.md", ['**/certs/**/*', '**/ssl/**/*', '**/pki/**/*', '**/tls/**/*']),
}

SYSTEM_PROMPT = """\
You are a technical editor compacting coding standards into Claude Code rules.

Task: produce a STRICT {max_lines}-line-max version of a standards document.

AGGRESSIVELY CUT — {max_lines} lines is a HARD LIMIT:
- CUT all code examples that merely illustrate an already-stated rule
- CUT explanatory prose — keep ONLY the rule itself
- CUT "why" sections, background, history, version notes
- CUT anything a competent developer knows (basic syntax, obvious patterns)
- CUT anything already covered in UNIVERSAL.md (git commits, spelling split,
  file headers, error handling philosophy, communication style, testing policy,
  security basics, licensing, AI code of conduct). These rules are ALWAYS loaded
  separately — do NOT duplicate them.
- CONDENSE multi-line examples to single-line where possible
- CONDENSE tables: keep only if they add value over a bullet list
- Keep ONLY 1 brief example per critical anti-pattern (the ❌/✅ pair)

KEEP (language/domain-specific only):
- Critical rules an AI is likely to violate (wrong function, wrong pattern)
- Must-do/never-do items specific to THIS language/tool
- Anti-patterns with brief ❌/✅ examples (one example per rule, max 3 lines each)
- Tool-specific commands and config (the stuff you can't guess)

FORMAT:
- Terse bullet points, imperative tone: "Use X", "Never Y"
- Minimal heading structure (## only, no ###)
- No prose paragraphs — every line should be a rule or example

Output MUST:
- Start with the YAML frontmatter block provided (if paths given)
- Be valid markdown
- Be STRICTLY under {max_lines} lines total
- Contain ONLY rules — zero meta-commentary

Output the compacted markdown and nothing else."""

USER_PROMPT = """\
Compact the following standards document to under {max_lines} lines.

Start your output with this exact frontmatter (do not modify it):
```
{frontmatter}
```

Here is the full standards document:

{content}"""

USER_PROMPT_NO_PATHS = """\
Compact the following standards document to under {max_lines} lines.

This is a universal rule (no path scoping). Do NOT include any YAML frontmatter.

Here is the full standards document:

{content}"""


def build_frontmatter(paths: list[str]) -> str:
    """Build YAML frontmatter for a rule file."""
    if not paths:
        return ""
    lines = ["---", "paths:"]
    for p in paths:
        lines.append(f'  - "{p}"')
    lines.append("---")
    return "\n".join(lines)


def compact_standard(
    client: Anthropic,
    standard_path: Path,
    paths: list[str],
    model: str = MODEL,
    dry_run: bool = False,
) -> str:
    """Call the API to compact a single standards file."""
    content = standard_path.read_text()
    source_lines = len(content.splitlines())

    if source_lines <= MAX_OUTPUT_LINES:
        # Already small enough — just add frontmatter
        frontmatter = build_frontmatter(paths)
        if frontmatter:
            return f"{frontmatter}\n\n{content}"
        return content

    frontmatter = build_frontmatter(paths)

    if paths:
        user_msg = USER_PROMPT.format(
            max_lines=MAX_OUTPUT_LINES,
            frontmatter=frontmatter,
            content=content,
        )
    else:
        user_msg = USER_PROMPT_NO_PATHS.format(
            max_lines=MAX_OUTPUT_LINES,
            content=content,
        )

    if dry_run:
        return f"[DRY RUN] Would compact {standard_path.name} ({source_lines} lines → ≤{MAX_OUTPUT_LINES})"

    response = client.messages.create(
        model=model,
        max_tokens=4096,
        messages=[{"role": "user", "content": user_msg}],
        system=SYSTEM_PROMPT.format(max_lines=MAX_OUTPUT_LINES),
    )

    result = response.content[0].text

    # Strip markdown code fences the model might wrap output in.
    # Handles: full wrapping, frontmatter-only wrapping, leading blanks.
    lines = result.splitlines()

    # Strip leading blank lines
    while lines and not lines[0].strip():
        lines.pop(0)

    # Strip opening code fence (``` or ```markdown etc.)
    if lines and lines[0].startswith("```"):
        lines.pop(0)

    # Strip closing code fence
    if lines and lines[-1].strip() == "```":
        lines.pop()

    # Strip stray ``` immediately after frontmatter closing ---
    # Pattern: ---\n```\n (the model sometimes wraps just the frontmatter)
    cleaned = []
    prev_was_frontmatter_close = False
    frontmatter_opened = False
    for line in lines:
        if line.strip() == "---":
            if not frontmatter_opened:
                frontmatter_opened = True
            else:
                prev_was_frontmatter_close = True
            cleaned.append(line)
            continue
        if prev_was_frontmatter_close and line.strip() == "```":
            prev_was_frontmatter_close = False
            continue  # Skip stray backtick after frontmatter
        prev_was_frontmatter_close = False
        cleaned.append(line)

    result = "\n".join(cleaned)

    return result


def main() -> int:
    load_dotenv(PROJECT_ROOT / ".env")

    parser = argparse.ArgumentParser(
        description="Compact standards into Claude Code rule files"
    )
    parser.add_argument(
        "--file",
        help="Process a single standard (e.g. PYTHON, RUST, DOCKER)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview what would be processed without calling the API",
    )
    parser.add_argument(
        "--model",
        default=MODEL,
        help=f"Model to use (default: {MODEL})",
    )
    args = parser.parse_args()

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key and not args.dry_run:
        print("Error: ANTHROPIC_API_KEY not set in .env or environment")
        return 1

    model = args.model
    client = Anthropic(api_key=api_key) if not args.dry_run else None

    # Filter to single file if specified
    if args.file:
        needle = args.file.upper()
        targets = {
            k: v for k, v in STANDARDS_MAP.items()
            if needle in k.upper()
        }
        if not targets:
            print(f"Error: no standard matching '{args.file}'")
            print(f"Available: {', '.join(STANDARDS_MAP.keys())}")
            return 1
    else:
        targets = STANDARDS_MAP

    # Create output directory
    RULES_DIR.mkdir(parents=True, exist_ok=True)

    processed = 0
    errors = 0

    for std_key, (output_name, glob_patterns) in targets.items():
        source_path = STANDARDS_DIR / f"{std_key}.md"
        output_path = RULES_DIR / output_name

        if not source_path.exists():
            print(f"  SKIP  {std_key}.md (not found)")
            continue

        source_lines = len(source_path.read_text().splitlines())
        print(f"  {'DRY ' if args.dry_run else ''}COMPACT  {std_key}.md ({source_lines} lines) → rules/{output_name}")

        try:
            result = compact_standard(
                client=client,
                standard_path=source_path,
                paths=glob_patterns,
                model=model,
                dry_run=args.dry_run,
            )

            if not args.dry_run:
                output_path.write_text(result.rstrip() + "\n")
                output_lines = len(result.splitlines())
                ratio = round((1 - output_lines / source_lines) * 100)
                status = "OK" if output_lines <= MAX_OUTPUT_LINES else "WARN >200"
                print(f"         → {output_lines} lines ({ratio}% reduction) [{status}]")

                # Rate limiting — be polite to the API
                time.sleep(0.5)

            processed += 1

        except Exception as e:
            print(f"  ERROR  {std_key}.md: {e}")
            errors += 1

    print(f"\nDone: {processed} processed, {errors} errors")
    if not args.dry_run:
        print(f"Output: {RULES_DIR}/")

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
