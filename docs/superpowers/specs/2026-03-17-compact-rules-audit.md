# Compact Rules Audit — 2026-03-17

Comparison of compact rules (`standards/rules/`) against full source standards.
Focused on substantive gaps that affect LLM behaviour, not cosmetic differences.

## Results

| Compact Rule | Source | Verdict |
|---|---|---|
| python.md | PYTHON.md | OK |
| rust.md | RUST.md | OK |
| golang.md | GOLANG.md | OK |
| typescript.md | TYPESCRIPT.md | GAPS — missing Effect-TS patterns |
| bash.md | BASH.md | OK |
| cpp.md | CPP.md | OK |
| clickhouse-sql.md | SQL-CLICKHOUSE.md | OK (minor — advanced patterns) |
| docker.md | DOCKER.md | OK |
| k8s.md | K8S.md | GAPS — missing practical examples |
| terraform.md | TERRAFORM.md | OK |
| ansible.md | ANSIBLE.md | OK |
| security.md | SECURITY.md | OK |
| error-handling.md | ERROR-HANDLING.md | OK |
| design-principles.md | DESIGN-PRINCIPLES.md | OK |
| testing.md | TESTING.md | GAPS — missing test-first workflow |
| mocks-policy.md | MOCKS-POLICY.md | OK |
| git.md | GIT.md | GAPS — missing semantic-release workflow |
| code-style.md | CODE-STYLE.md | OK |
| config-and-logging.md | CONFIG-AND-LOGGING.md | GAPS — missing implementation detail |
| ci.md | (standalone) | OK |
| pki.md | PKI.md | OK |

## Gaps to Address

### High Priority

1. **testing.md** — Add test pyramid structure, test-first workflow, per-language
   patterns. Currently just says "80% coverage, no mocks" without guidance on
   test structure or when to use test-first.

2. **config-and-logging.md** — Add logging format (JSON for containers, RFC 3339
   timestamps), .env quoting rules, cascade layer examples. Currently lists
   sensitive fields but not how to implement logging correctly.

3. **typescript.md** — Add Effect-TS patterns (Effect.gen, Service/Layer
   composition, Schema validation). Central to HyperI tech stack but absent
   from compact rules.

### Medium Priority

4. **git.md** — Add semantic-release workflow explanation and version bump
   rules. LLM may write commits that don't trigger releases correctly.

5. **k8s.md** — Add practical examples for External Secrets, KEDA autoscaling,
   ArgoCD sync policies. Compact has the rules but not enough to implement.

### Low Priority

6. **clickhouse-sql.md** — Advanced patterns (projections, materialized views)
   missing but basic query rules complete.

7. **pki.md** — Infrastructure-specific examples missing but base TLS rules
   complete.
