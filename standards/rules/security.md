# Security Standards

## Input Validation

- Validate ALL external input: user input, file uploads, env vars, DB results, external API responses
- Apply type checking, range/length limits, format validation, sanitisation, and business logic constraints
- Python: use Pydantic models with `Field` constraints and `@validator` for business rules
- Go: use `go-playground/validator` struct tags
- TypeScript: use Zod schemas with `.refine()` for custom rules
- Bash: check empty, length, and format (regex) before using any input

## SQL Injection Prevention

- NEVER use string interpolation/formatting in SQL queries
- ❌ `query = f"SELECT * FROM users WHERE id = {user_id}"`
- ✅ `cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))`
- Use parameterised queries or ORM query builders in every language
- Go: `db.QueryRow("SELECT * FROM users WHERE id = $1", userID)`
- TypeScript: use Prisma or parameterised `db.query('... $1', [val])`

## Secrets Management

- NEVER commit secrets to version control
- NEVER hardcode credentials in code
- NEVER log passwords, tokens, or API keys
- ALWAYS use environment variables or secret management tools (Vault, AWS Secrets Manager)
- ALWAYS rotate secrets regularly; use different secrets per environment
- Use `hyperi_pylib.config.settings` for validated config with mandatory secrets and optional defaults for non-secrets
- `.gitignore` MUST include: `.env`, `.env.local`, `.env.*.local`, `*.pem`, `*.key`, `credentials.json`, `secrets.yaml`

## Dependency Security

- Run security scanners: Python `bandit`/`pip-audit`, Go `govulncheck`, Node.js `npm audit`/`snyk`, Rust `cargo audit`
- ALWAYS commit lock files: `uv.lock`, `go.sum`, `package-lock.json`/`yarn.lock`, `Cargo.lock`
- Run `./ci/run dependency-update` (Python), `go get -u ./... && go mod tidy` (Go), `npm update && npm audit fix` (Node.js), `cargo update && cargo audit` (Rust)

## Authentication & Authorisation

- NEVER store plain text passwords — always hash with bcrypt or equivalent
- Use `secrets.token_urlsafe()` or `secrets.token_hex()` for token/API key generation
- Implement rate limiting on authentication endpoints (e.g., 5 attempts per 15-minute window)

## Common Vulnerabilities

### Command Injection
- ❌ `subprocess.run(f"ls {user_input}", shell=True)`
- ✅ `subprocess.run(["ls", user_input], shell=False)`

### XSS
- ❌ `f"<div>Hello, {user_name}</div>"`
- ✅ Use `html.escape()` or a templating engine with auto-escaping

### Insecure Deserialisation
- NEVER use `pickle.loads()` on untrusted data — use JSON or Pydantic `model_validate_json()`

### Path Traversal
- Resolve both base and target paths, then verify target starts with base path
- ❌ `open(f"/data/{filename}")` — user can pass `../../../etc/passwd`
- ✅ `file_path = (base_path / filename).resolve(); assert str(file_path).startswith(str(base_path))`

## Logging Security

- NEVER log: passwords, tokens, API keys, card numbers, SSNs, private keys, session tokens, JWTs, PII
- Use `hyperi_pylib.logger` which auto-masks sensitive fields
- Mask sensitive display data (show only last 4 digits of cards, partially mask emails)

## Security Checklists

### Before Committing
- No secrets in code or config
- Input validation on all external data
- Parameterised queries only
- Passwords hashed
- Sensitive data masked in logs
- Dependencies scanned
- Error messages don't expose internals

### Before Deploying
- Different secrets per environment
- HTTPS/TLS enabled
- Security headers configured
- Rate limiting enabled
- Audit logging enabled
- Dependency vulnerabilities resolved
