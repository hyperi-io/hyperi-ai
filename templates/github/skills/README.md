# VS Code Agent Skills Templates

**VS Code 1.108+ Feature:** Agent Skills allow you to define custom capabilities
that enhance AI assistants in VS Code.

## Structure

Skills are placed in `.github/skills/<skill-name>/SKILL.md` with YAML frontmatter:

```markdown
---
name: skill-name
description: Brief description shown to the AI
---

# Skill Content

Instructions and context for the AI when this skill is invoked.
```

## Deployment

The `codex.sh` agent script automatically creates skills based on detected
project technologies:

| Detected | Skill Created |
|----------|---------------|
| Always | `standards` (HyperI coding standards) |
| pyproject.toml, requirements.txt | `python` |
| go.mod | `golang` |
| tsconfig.json, package.json | `typescript` |
| Cargo.toml | `rust` |
| CMakeLists.txt, *.cpp | `cpp` |
| *.sh files | `bash` |
| Dockerfile, docker-compose.yaml | `docker` |
| Chart.yaml, charts/, values.yaml | `k8s` |
| *.tf files | `terraform` |
| ansible.cfg, playbook.yml | `ansible` |
| certs/, ssl/, pki/, tls/ | `pki` |

## VS Code Settings

Enable Agent Skills in `.vscode/settings.json`:

```json
{
    "chat.useAgentSkills": true
}
```

## Reference

- [VS Code Agent Skills Documentation](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [VS Code 1.108 Release Notes](https://code.visualstudio.com/updates/v1_108)
