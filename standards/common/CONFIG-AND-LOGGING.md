# Configuration and Logging Standards

**HyperI standard patterns for configuration cascade and structured logging**

---

## Configuration Cascade

### 7-Layer Priority (Highest to Lowest)

| Priority | Source | Purpose | Example |
|----------|--------|---------|---------|
| 1 | CLI args/switches | Runtime override | `--host=X --port=Y` |
| 2 | ENV variables | Deployment config | `MYAPP_DATABASE_HOST=prod.db.com` |
| 3 | `.env` file | Local secrets | gitignored, never commit |
| 4 | `settings.{env}.yaml` | Environment-specific | `settings.production.yaml` |
| 5 | `settings.yaml` | Project base config | Team defaults |
| 6 | `defaults.yaml` | Safe fallback | Local dev defaults |
| 7 | Hard-coded | Last resort | Code fallback values |

### Real-World Example: `database.host`

```text
Priority    Source                        Value              When Used
--------    ------                        -----              ---------
1. CLI      --host prod.db.com            "prod.db.com"      CLI override
2. ENV      MYAPP_DATABASE_HOST=test      "test.db"          CI/staging
3. .env     MYAPP_DATABASE_HOST=local     "local.db"         Dev secrets
4. {env}    settings.production.yaml      "prod-rw.db.com"   Prod deploy
5. base     settings.yaml                 "postgres.svc"     Team default
6. defaults defaults.yaml                 "localhost"        Safe default
7. code     config.get("db.host", "localhost")               Fallback
```

### ENV Key Auto-Generation

```text
Config Path              Auto-Generated ENV Key
-----------              ----------------------
database.host         → MYAPP_DATABASE_HOST
api.timeout           → MYAPP_API_TIMEOUT
cache.redis.enabled   → MYAPP_CACHE_REDIS_ENABLED
```

---

## .env File Format

### Always Quote Values - No Exceptions

**All values in `.env` files MUST be quoted.** This applies to:

- `.env` - Local secrets (gitignored)
- `.env.example` / `env.example` - Template for developers
- `.env.sample` - Sample configuration
- `.env.{environment}` - Environment-specific (`.env.production`, `.env.staging`)

### Why Always Quote?

1. **Consistency** - One rule, no exceptions, no thinking required
2. **Safety** - Values with spaces, `#`, `$`, quotes won't break
3. **Portability** - Works across all parsers (dotenv, docker, shell)
4. **Prevents bugs** - Unquoted `#` starts a comment, breaking your config

### Correct Format

```bash
# ✅ CORRECT - Always quote values
DATABASE_HOST="localhost"
DATABASE_PORT="5432"
API_KEY="sk-1234567890abcdef"
APP_NAME="My Application"
DEBUG="true"
EMPTY_VALUE=""
PATH_WITH_SPACES="/path/to/my app/config"
VALUE_WITH_HASH="secret#123"
```

### Incorrect Format

```bash
# ❌ WRONG - Unquoted values
DATABASE_HOST=localhost
DATABASE_PORT=5432
DEBUG=true

# ❌ WRONG - These will BREAK
APP_NAME=My Application          # Stops at space
VALUE_WITH_HASH=secret#123       # Stops at hash (comment)
JSON_CONFIG={"key":"value"}      # Brace parsing issues
```

### Quote Style

**Use double quotes (`"`)** - they're the most portable:

```bash
# ✅ Preferred - Double quotes
DATABASE_URL="postgresql://user:pass@host/db"

# ⚠️ Acceptable - Single quotes (no variable expansion)
DATABASE_URL='postgresql://user:pass@host/db'

# ❌ Never - Backticks or no quotes
DATABASE_URL=`postgresql://user:pass@host/db`
```

### Escaping Within Quoted Values

```bash
# Double quotes inside double quotes - escape with backslash
MESSAGE="He said \"Hello\""

# Or use single quotes to contain double quotes
MESSAGE='He said "Hello"'

# Dollar signs in double quotes - escape to prevent expansion
PRICE="Cost is \$100"

# Or use single quotes (no expansion in single quotes)
PRICE='Cost is $100'
```

### .env.example Template

```bash
# Database Configuration
DATABASE_HOST="localhost"
DATABASE_PORT="5432"
DATABASE_NAME="myapp_dev"
DATABASE_USER="postgres"
DATABASE_PASSWORD=""

# API Keys (get from team password manager)
API_KEY=""
SECRET_KEY=""

# Feature Flags
DEBUG="false"
LOG_LEVEL="INFO"
```

---

## Multi-Language Implementation

### Python (hyperi-pylib / Dynaconf)

```python
# Zero-config - cascade is AUTOMATIC via Dynaconf
from hyperi_pylib.config import settings

# Direct attribute access (Pythonic)
host = settings.database.host         # Cascade automatic!
port = settings.database.port         # ENV > .env > files > defaults

# Dict-style with fallback
host = settings.get("database.host", "localhost")
timeout = settings.get("api.timeout", 30)
```

### Go (Viper)

```go
package config

import (
    "github.com/spf13/viper"
    "os"
    "path/filepath"
)

func LoadConfig() error {
    // Priority 7: Hardcoded defaults
    viper.SetDefault("database.host", "localhost")
    viper.SetDefault("database.port", 5432)
    viper.SetDefault("log.level", "INFO")

    // Priority 6: defaults.yaml
    viper.SetConfigName("defaults")
    viper.SetConfigType("yaml")
    viper.AddConfigPath(".")
    viper.ReadInConfig() // Ignore error if not found

    // Priority 5: settings.yaml
    viper.SetConfigName("settings")
    viper.MergeInConfig()

    // Priority 4: settings.{env}.yaml
    env := os.Getenv("APP_ENV")
    if env == "" {
        env = "development"
    }
    viper.SetConfigName("settings." + env)
    viper.MergeInConfig()

    // Priority 3: .env file (via godotenv)
    // godotenv.Load()

    // Priority 2: ENV variables
    viper.SetEnvPrefix("MYAPP")
    viper.AutomaticEnv()
    viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

    return nil
}

// Usage
func GetDatabaseHost() string {
    return viper.GetString("database.host")
}
```

### TypeScript (dotenv + custom loader)

```typescript
import { config } from 'dotenv';
import * as fs from 'fs';
import * as yaml from 'yaml';

interface Config {
  database: {
    host: string;
    port: number;
  };
  log: {
    level: string;
  };
}

function loadConfig(): Config {
  // Priority 7: Hardcoded defaults
  const defaults: Config = {
    database: { host: 'localhost', port: 5432 },
    log: { level: 'INFO' },
  };

  // Priority 6-5: YAML files
  const loadYaml = (file: string) => {
    try {
      return yaml.parse(fs.readFileSync(file, 'utf8'));
    } catch {
      return {};
    }
  };

  const env = process.env.NODE_ENV || 'development';

  // Merge in priority order (later overrides earlier)
  let merged = {
    ...defaults,
    ...loadYaml('defaults.yaml'),
    ...loadYaml('settings.yaml'),
    ...loadYaml(`settings.${env}.yaml`),
  };

  // Priority 3: .env file
  config(); // Loads .env into process.env

  // Priority 2: ENV variables override
  if (process.env.MYAPP_DATABASE_HOST) {
    merged.database.host = process.env.MYAPP_DATABASE_HOST;
  }
  if (process.env.MYAPP_DATABASE_PORT) {
    merged.database.port = parseInt(process.env.MYAPP_DATABASE_PORT);
  }

  return merged;
}

export const settings = loadConfig();
```

### Bash

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration Cascade (HyperI Standard)
# Priority: CLI > ENV > .env > config.{env}.sh > config.sh > defaults > hardcoded

# Priority 7: Hardcoded defaults (lowest priority)
DEFAULT_HOST="localhost"
DEFAULT_PORT="8080"
DEFAULT_LOG_LEVEL="INFO"

# Priority 6: Source defaults file (if exists)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/defaults.sh" ]] && source "${SCRIPT_DIR}/defaults.sh"

# Priority 5: Source base config (if exists)
[[ -f "${SCRIPT_DIR}/config.sh" ]] && source "${SCRIPT_DIR}/config.sh"

# Priority 4: Source environment-specific config
APP_ENV="${APP_ENV:-development}"
[[ -f "${SCRIPT_DIR}/config.${APP_ENV}.sh" ]] && source "${SCRIPT_DIR}/config.${APP_ENV}.sh"

# Priority 3: Source .env file (local secrets, gitignored)
[[ -f "${SCRIPT_DIR}/.env" ]] && source "${SCRIPT_DIR}/.env"

# Priority 2: ENV variables override (deployment)
HOST="${MYAPP_HOST:-${HOST:-${DEFAULT_HOST}}}"
PORT="${MYAPP_PORT:-${PORT:-${DEFAULT_PORT}}}"
LOG_LEVEL="${LOG_LEVEL:-${DEFAULT_LOG_LEVEL}}"

# Priority 1: CLI args override (highest priority) - in main()
main() {
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --host=*) HOST="${1#*=}"; shift ;;
            --port=*) PORT="${1#*=}"; shift ;;
            --log-level=*) LOG_LEVEL="${1#*=}"; shift ;;
            -h|--help) usage; exit 0 ;;
            *) break ;;
        esac
    done

    log_info "Starting with HOST=${HOST} PORT=${PORT}"
}
```

### Rust (config-rs)

```rust
use config::{Config, ConfigError, Environment, File};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Settings {
    pub database: DatabaseSettings,
    pub log: LogSettings,
}

#[derive(Debug, Deserialize)]
pub struct DatabaseSettings {
    pub host: String,
    pub port: u16,
}

#[derive(Debug, Deserialize)]
pub struct LogSettings {
    pub level: String,
}

impl Settings {
    pub fn new() -> Result<Self, ConfigError> {
        let env = std::env::var("APP_ENV").unwrap_or_else(|_| "development".into());

        let s = Config::builder()
            // Priority 7: Hardcoded defaults
            .set_default("database.host", "localhost")?
            .set_default("database.port", 5432)?
            .set_default("log.level", "INFO")?
            // Priority 6: defaults.yaml
            .add_source(File::with_name("defaults").required(false))
            // Priority 5: settings.yaml
            .add_source(File::with_name("settings").required(false))
            // Priority 4: settings.{env}.yaml
            .add_source(File::with_name(&format!("settings.{}", env)).required(false))
            // Priority 3: .env (via dotenv in main)
            // Priority 2: Environment variables
            .add_source(
                Environment::with_prefix("MYAPP")
                    .separator("_")
                    .try_parsing(true),
            )
            .build()?;

        s.try_deserialize()
    }
}
```

---

## Logging Standards

### Output Modes

| Context | Format | Colours | Emojis |
|---------|--------|---------|--------|
| **Console (dev)** | Human-friendly | Solarized | CHARS-POLICY approved |
| **Container/CI** | RFC 3339 JSON | None | ASCII text equivalents |
| **File** | RFC 3339 plain | None | None |

### RFC 3339 Timestamp Format (With Timezone)

```text
2025-01-20T14:30:00.123+11:00   # Local timezone offset
2025-01-20T03:30:00.123Z        # UTC (Z = +00:00)
```

**Required for:** All production logs, container logs, file logs.

⚠️ **Always include timezone offset** - Never use timestamps without timezone (`2025-01-20T14:30:00` is ambiguous).

### Log Levels

| Level | Use Case | Emoji (console) | ASCII (machine) |
|-------|----------|-----------------|-----------------|
| CRITICAL | Irrecoverable error | 💥 | [FATAL] |
| ERROR | Blocking issue | ❌ | [ERROR] |
| WARNING | Non-blocking issue | ⚠️ | [WARN] |
| INFO | Normal operation | - | - |
| SUCCESS | Operation complete | ✅ | [SUCCESS] |
| DEBUG | Debugging info | - | - |

---

## Multi-Language Logging

### Python (hyperi-pylib / Loguru)

```python
# Zero-config logging with RFC 3339, sensitive masking, auto-detect console
from hyperi_pylib import logger

logger.info("Processing", user_id=123)
logger.error("Failed", error=str(e), exc_info=True)

# Automatic context
logger.error(
    "Operation failed",
    user_id=user_id,           # Who
    operation="update_profile", # What
    request_id=request_id,      # Tracking
    exc_info=True               # Stack trace
)
```

### Go (slog)

```go
package main

import (
    "log/slog"
    "os"
    "time"
)

func setupLogging() *slog.Logger {
    var handler slog.Handler

    if os.Getenv("LOG_FORMAT") == "json" {
        // Container/CI: JSON with RFC 3339
        handler = slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{
            Level: slog.LevelInfo,
            ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
                if a.Key == slog.TimeKey {
                    // RFC 3339 format
                    a.Value = slog.StringValue(a.Value.Time().Format(time.RFC3339Nano))
                }
                return a
            },
        })
    } else {
        // Console: Human-friendly
        handler = slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
            Level: slog.LevelDebug,
        })
    }

    return slog.New(handler)
}

// Usage
func main() {
    logger := setupLogging()

    logger.Info("Processing",
        slog.Int("user_id", 123),
        slog.String("operation", "update_profile"),
    )

    logger.Error("Failed",
        slog.String("error", err.Error()),
        slog.String("request_id", requestID),
    )
}
```

### TypeScript (pino)

```typescript
import pino from 'pino';

const isProduction = process.env.NODE_ENV === 'production';

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  // RFC 3339 timestamps
  timestamp: () => `,"time":"${new Date().toISOString()}"`,
  // Human-friendly in dev, JSON in production
  transport: isProduction
    ? undefined
    : {
        target: 'pino-pretty',
        options: { colorize: true },
      },
});

// Usage
logger.info({ userId: 123, operation: 'update_profile' }, 'Processing');
logger.error({ error: err.message, requestId }, 'Failed');
```

### Bash

```bash
# Log levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Level priority for filtering (Bash 3.2 compatible - no associative arrays)
get_log_priority() {
    case "${1}" in
        DEBUG)    echo 0 ;;
        INFO)     echo 1 ;;
        WARNING)  echo 2 ;;
        ERROR)    echo 3 ;;
        CRITICAL) echo 4 ;;
        *)        echo 1 ;;
    esac
}

should_log() {
    local level="${1}"
    local current requested
    current=$(get_log_priority "${LOG_LEVEL}")
    requested=$(get_log_priority "${level}")
    [[ ${requested} -ge ${current} ]]
}

log_message() {
    local level="${1}"
    local message="${2}"

    should_log "${level}" || return 0

    # RFC 3339 timestamp
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

    # Structured output (JSON for containers, human for console)
    if [[ -t 2 ]]; then
        # Console: human-friendly with colour
        case "${level}" in
            DEBUG)    printf "\033[90m%s [DEBUG] %s\033[0m\n" "${timestamp}" "${message}" >&2 ;;
            INFO)     printf "\033[34m%s [INFO]  %s\033[0m\n" "${timestamp}" "${message}" >&2 ;;
            WARNING)  printf "\033[33m%s [WARN]  %s\033[0m\n" "${timestamp}" "${message}" >&2 ;;
            ERROR)    printf "\033[31m%s [ERROR] %s\033[0m\n" "${timestamp}" "${message}" >&2 ;;
            CRITICAL) printf "\033[91m%s [FATAL] %s\033[0m\n" "${timestamp}" "${message}" >&2 ;;
        esac
    else
        # Container/pipe: JSON for log aggregators
        printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' \
            "${timestamp}" "${level}" "${message}" >&2
    fi
}

# Convenience functions
log_debug()    { log_message "DEBUG" "$*"; }
log_info()     { log_message "INFO" "$*"; }
log_warning()  { log_message "WARNING" "$*"; }
log_error()    { log_message "ERROR" "$*"; }
log_critical() { log_message "CRITICAL" "$*"; }
```

### Rust (tracing)

```rust
use tracing::{info, error, Level};
use tracing_subscriber::{fmt, EnvFilter};

fn setup_logging() {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info"));

    let is_json = std::env::var("LOG_FORMAT")
        .map(|v| v == "json")
        .unwrap_or(false);

    if is_json {
        // Container: JSON with RFC 3339
        fmt()
            .json()
            .with_env_filter(filter)
            .init();
    } else {
        // Console: Human-friendly
        fmt()
            .with_env_filter(filter)
            .init();
    }
}

// Usage
fn process_user(user_id: i32) {
    info!(user_id, operation = "update_profile", "Processing");

    if let Err(e) = do_work() {
        error!(error = %e, user_id, "Operation failed");
    }
}
```

---

## Structured Logging Fields

### Required Context

**ALWAYS log with context:**

```python
logger.error(
    "Operation failed",
    user_id=user_id,           # Who
    operation="update_profile", # What
    request_id=request_id,      # Tracking
    exc_info=True               # Stack trace
)
```

### Context Checklist

**Required:**

- User/session identifier (NOT passwords!)
- Operation being performed
- Timestamp (RFC 3339 with timezone)
- Request/transaction ID for tracing
- Full stack trace for errors

**Recommended:**

- Client IP address (hashed for privacy)
- User agent / client version
- Input parameters (sanitised!)
- System state (memory, CPU if relevant)

---

## Sensitive Data Masking

**ALWAYS mask in logs:**

- Passwords, tokens, API keys
- Credit cards, CVV, SSN, PII
- Private keys, certificates, JWTs

```python
# hyperi-pylib auto-masks sensitive patterns
logger.info("Connecting", password="secret123")  # → password="***MASKED***"
```

**Supported patterns:**

- Passwords (password=, pwd=, pass=)
- API keys (api_key=, apikey=, token=)
- Bearer tokens (Authorization: Bearer ...)
- Database URLs (postgresql://user:password@host)
- AWS keys (AKIA..., aws_secret_access_key=)
- Credit cards (card_number=, cvv=)

---

## ENV Variables for Logging

```bash
LOG_LEVEL=DEBUG           # DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_FORMAT=json           # json, text, console, logfmt
LOG_OUTPUT=stdout         # stdout, stderr, file
NO_COLOR=1                # Disable colours (standard)
LOG_TIMESTAMP_FORMAT=rfc3339  # iso8601, rfc3339, unix
```
