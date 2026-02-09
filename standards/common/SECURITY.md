# Security Standards

**Security-first development practices for all HyperI projects**

---

## Input Validation

### Validate ALL External Input

**ALWAYS validate:**

- User input (forms, CLI args, API requests)
- File uploads
- Environment variables
- Database query results
- External API responses

### Validation Checklist

- [ ] Type checking
- [ ] Range/length limits
- [ ] Format validation (regex, parsing)
- [ ] Sanitisation (SQL injection, XSS, etc.)
- [ ] Business logic constraints

### Multi-Language Examples

**Python:**

```python
from pydantic import BaseModel, EmailStr, Field, validator

class UserInput(BaseModel):
    email: EmailStr
    age: int = Field(ge=18, le=120)
    username: str = Field(min_length=3, max_length=50, pattern=r'^[a-zA-Z0-9_]+$')

    @validator('username')
    def username_not_reserved(cls, v):
        if v.lower() in ['admin', 'root', 'system']:
            raise ValueError('Username is reserved')
        return v

# Usage
def create_user(data: dict) -> User:
    validated = UserInput(**data)  # Raises ValidationError if invalid
    return db.create_user(validated)
```

**Go:**

```go
import "github.com/go-playground/validator/v10"

type UserInput struct {
    Email    string `json:"email" validate:"required,email"`
    Age      int    `json:"age" validate:"gte=18,lte=120"`
    Username string `json:"username" validate:"required,min=3,max=50,alphanum"`
}

func CreateUser(input UserInput) (*User, error) {
    validate := validator.New()
    if err := validate.Struct(input); err != nil {
        return nil, fmt.Errorf("validation failed: %w", err)
    }

    // Check reserved usernames
    reserved := []string{"admin", "root", "system"}
    for _, r := range reserved {
        if strings.EqualFold(input.Username, r) {
            return nil, errors.New("username is reserved")
        }
    }

    return db.CreateUser(input)
}
```

**TypeScript:**

```typescript
import { z } from 'zod';

const UserInput = z.object({
  email: z.string().email(),
  age: z.number().int().min(18).max(120),
  username: z.string()
    .min(3)
    .max(50)
    .regex(/^[a-zA-Z0-9_]+$/)
    .refine(
      (val) => !['admin', 'root', 'system'].includes(val.toLowerCase()),
      'Username is reserved'
    ),
});

type UserInput = z.infer<typeof UserInput>;

async function createUser(data: unknown): Promise<User> {
  const validated = UserInput.parse(data); // Throws ZodError if invalid
  return db.createUser(validated);
}
```

**Bash:**

```bash
validate_input() {
    local input="${1:-}"

    # Check not empty
    if [[ -z "${input}" ]]; then
        echo "Error: Input required" >&2
        return 1
    fi

    # Check length
    if [[ ${#input} -gt 255 ]]; then
        echo "Error: Input too long" >&2
        return 1
    fi

    # Check format (alphanumeric only)
    if [[ ! "${input}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Invalid characters in input" >&2
        return 1
    fi

    return 0
}
```

---

## SQL Injection Prevention

### NEVER Use String Interpolation

**❌ Bad (SQL injection vulnerability):**

```python
# Python
query = f"SELECT * FROM users WHERE id = {user_id}"

# Go
query := fmt.Sprintf("SELECT * FROM users WHERE id = %s", userID)

# TypeScript
const query = `SELECT * FROM users WHERE id = ${userId}`;
```

**✅ Good (parameterised queries):**

```python
# Python
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))

# Python (SQLAlchemy)
session.query(User).filter(User.id == user_id).first()
```

```go
// Go
row := db.QueryRow("SELECT * FROM users WHERE id = $1", userID)

// Go (sqlx)
user := User{}
err := db.Get(&user, "SELECT * FROM users WHERE id = $1", userID)
```

```typescript
// TypeScript (Prisma)
const user = await prisma.user.findUnique({
  where: { id: userId },
});

// TypeScript (raw query with params)
const user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);
```

---

## Secrets Management

### Never Commit Secrets

❌ **NEVER** commit secrets to version control
❌ **NEVER** hardcode credentials in code
❌ **NEVER** log passwords, tokens, or API keys

✅ **ALWAYS** use environment variables
✅ **ALWAYS** use secret management tools (Vault, AWS Secrets Manager, etc.)
✅ **ALWAYS** rotate secrets regularly
✅ **ALWAYS** use different secrets per environment

### Configuration Pattern

```python
# ❌ Bad - hardcoded secrets
DATABASE_URL = "postgresql://user:password123@localhost/db"
API_KEY = "sk-1234567890abcdef"

# ✅ Good - environment variables
import os
DATABASE_URL = os.environ["DATABASE_URL"]
API_KEY = os.environ["API_KEY"]

# ✅ Better - with validation and defaults for non-secrets
from hyperi_pylib.config import settings
DATABASE_URL = settings.database.url  # Raises if missing
LOG_LEVEL = settings.get("log_level", "INFO")  # Default for non-secret
```

### .gitignore Requirements

```gitignore
# Secrets - NEVER commit
.env
.env.local
.env.*.local
*.pem
*.key
credentials.json
secrets.yaml
```

---

## Dependency Security

### Required Tools

| Language | Security Scanner | Vulnerability Alerts |
|----------|-----------------|---------------------|
| **Python** | `bandit`, `pip-audit` | Dependabot, Snyk |
| **Go** | `govulncheck` | Dependabot |
| **Node.js** | `npm audit`, `snyk` | Dependabot, Snyk |
| **Rust** | `cargo audit` | Dependabot |

### Lock Files

**ALWAYS commit lock files:**

- Python: `uv.lock`
- Go: `go.sum`
- Node.js: `package-lock.json` or `yarn.lock`
- Rust: `Cargo.lock`

**Why:** Ensures reproducible builds and known-good dependency versions.

### Regular Updates

```bash
# Python (uv)
./ci/run dependency-update

# Go
go get -u ./...
go mod tidy

# Node.js
npm update
npm audit fix

# Rust
cargo update
cargo audit
```

---

## Authentication & Authorisation

### Password Handling

**NEVER store plain text passwords:**

```python
# ❌ Bad - plain text
db.insert_user(email=email, password=password)

# ✅ Good - hashed with bcrypt
import bcrypt

password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
db.insert_user(email=email, password_hash=password_hash)

# Verification
def verify_password(password: str, stored_hash: bytes) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), stored_hash)
```

### Token Security

```python
# ✅ Secure token generation
import secrets

def generate_token(length: int = 32) -> str:
    return secrets.token_urlsafe(length)

def generate_api_key() -> str:
    return f"sk_{secrets.token_hex(32)}"
```

### Rate Limiting

```python
# Protect against brute force
from functools import lru_cache
from datetime import datetime, timedelta

_attempts: dict[str, list[datetime]] = {}

def is_rate_limited(identifier: str, max_attempts: int = 5, window_minutes: int = 15) -> bool:
    now = datetime.now()
    window_start = now - timedelta(minutes=window_minutes)

    # Clean old attempts
    attempts = [t for t in _attempts.get(identifier, []) if t > window_start]
    _attempts[identifier] = attempts

    return len(attempts) >= max_attempts

def record_attempt(identifier: str) -> None:
    if identifier not in _attempts:
        _attempts[identifier] = []
    _attempts[identifier].append(datetime.now())
```

---

## Common Vulnerabilities (OWASP Top 10)

### Injection (SQL, Command, XSS)

```python
# ❌ Command injection
import subprocess
subprocess.run(f"ls {user_input}", shell=True)  # DANGER!

# ✅ Safe command execution
subprocess.run(["ls", user_input], shell=False)
```

```python
# ❌ XSS vulnerability
return f"<div>Hello, {user_name}</div>"

# ✅ HTML escape
from html import escape
return f"<div>Hello, {escape(user_name)}</div>"

# ✅ Better - use templating engine
return render_template("greeting.html", name=user_name)  # Auto-escapes
```

### Insecure Deserialisation

```python
# ❌ NEVER use pickle with untrusted data
import pickle
data = pickle.loads(user_bytes)  # Remote code execution risk!

# ✅ Use JSON for untrusted data
import json
data = json.loads(user_string)

# ✅ If you must deserialise, validate strictly
from pydantic import BaseModel
data = MyModel.model_validate_json(user_string)
```

### Path Traversal

```python
# ❌ Path traversal vulnerability
def get_file(filename):
    return open(f"/data/{filename}").read()
# User can pass: "../../../etc/passwd"

# ✅ Validate and sanitise paths
from pathlib import Path

def get_file(filename: str) -> str:
    base_path = Path("/data").resolve()
    file_path = (base_path / filename).resolve()

    # Ensure path is within base directory
    if not str(file_path).startswith(str(base_path)):
        raise ValueError("Invalid path")

    return file_path.read_text()
```

---

## Logging Security

### Never Log Sensitive Data

**❌ NEVER log:**

- Passwords, tokens, API keys
- Credit card numbers, CVV codes
- Social Security Numbers, passport numbers
- Private keys, certificates
- Session tokens, JWTs
- PII (personally identifiable information)

**✅ Use hyperi-pylib auto-masking:**

```python
from hyperi_pylib import logger

# Automatically masks passwords, tokens, API keys
logger.info("User login", username="alice", password="secret123")
# Logs: "User login" username="alice" password="***MASKED***"
```

### Mask Sensitive Output

```python
def mask_card(card_number: str) -> str:
    """Show only last 4 digits."""
    return f"****-****-****-{card_number[-4:]}"

def mask_email(email: str) -> str:
    """Partially mask email."""
    local, domain = email.split("@")
    masked_local = local[0] + "***" + local[-1] if len(local) > 2 else "***"
    return f"{masked_local}@{domain}"
```

---

## Security Checklist

### Before Committing

- [ ] No secrets in code or config
- [ ] Input validation on all external data
- [ ] Parameterised queries (no string interpolation)
- [ ] Password hashing (never plain text)
- [ ] Sensitive data masked in logs
- [ ] Dependencies scanned for vulnerabilities
- [ ] Error messages don't expose internals

### Before Deploying

- [ ] Different secrets per environment
- [ ] HTTPS/TLS enabled
- [ ] Security headers configured
- [ ] Rate limiting enabled
- [ ] Audit logging enabled
- [ ] Dependency vulnerabilities resolved
