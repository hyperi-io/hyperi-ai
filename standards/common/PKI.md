---
name: pki-standards
description: PKI, TLS, SSH, and cryptographic standards based on CNSA 2.0. Use when configuring certificates, SSH keys, TLS, or any cryptographic settings.
---

# PKI and Cryptographic Standards

**Practical cryptography for HyperI projects - based on CNSA 2.0 with real-world fallbacks**

## Background (Derek)

This is a collection of my trial and error and see what breaks based on CNSA 2.0 high profile for different components, especially when used together. Based on mAturity of implementation for each component (e.g P-384 fun) as of December  2025. While I do not believe quantum computing breaking ciphers is actually going to happen anytime soon (if at all) the standards this effort has produced are all pretty damn good so we use them. Cryptanalysis is a hidden previous life/maths thing for me so its been fun, apart from debugging a couple of ugly, really slow to build OSS sources. I have attempted to summarise ny notes here and make them more 'do this' focused but if I have geeked out a bit too much here  give me detail on what make be unnecessarily detailed and I'll rework it.

I've used an LLM to tidy up my text below so please ping me if its introduced something dumb or erroneous.

---

## Security Profiles: Where to Draw the Line

Not everything needs maximum security. Here's how we think about the risk-reward trade-off.

> **Corporate Default: `prod`**
> This is what I use and you should too. It's now our corporate default.

### prod (Production - Corporate Default)

**For:** Production deployments, customer-facing services, HyperI infrastructure

| Component | Algorithm | Notes |
| --------- | --------- | ----- |
| SSH keys | Ed25519 | Fast, secure, universally supported |
| TLS certificates | **ECDSA P-384** | What we actually use in hypersec-infra-devex |
| CA certificates | ECDSA P-384 | Long-lived certs get stronger curves |
| Symmetric | AES-256-GCM | TLS 1.3 default |
| Hashing | SHA-384 | Matches P-384 security level |
| Passwords | 20 alphanumeric | ~119 bits entropy |

**Why P-384 for prod:**

- 192-bit security level vs P-256's 128-bit
- Already proven in our stack (hypersec-infra-devex runs P-384 everywhere)
- CNSA 2.0 approved for national security systems
- Future-proofs against classical cryptanalysis advances
- Let's Encrypt, OpenBao, OpenVPN all handle P-384 well

**The P-384 reality check:**

- Performance is now acceptable (OpenSSL 3.x is 5.5x faster than before)
- Some older clients may negotiate down to P-256 (that's fine)
- Python `cryptography`, Go `crypto/tls`, Rust `rustls` all support it
- Main pain point: generating test certs by hand is slightly more annoying

### devtest (Development/Testing)

**For:** Local dev, prototypes, internal tools, staging environments

| Component | Algorithm | Notes |
| --------- | --------- | ----- |
| SSH keys | Ed25519 | Same as prod |
| TLS certificates | **ECDSA P-256** | Industry default, best library support |
| Symmetric | AES-256-GCM | Same as prod |
| Hashing | SHA-256 | Sufficient for dev/test |
| Passwords | 20 alphanumeric | Same as prod |

**Why P-256 for devtest:**

- Google, Cloudflare, AWS all default to P-256
- Better performance across all languages and platforms
- OpenSSL P-384 had performance issues until recently (3.x fixed it)
- P-256 gives 128-bit security - sufficient for TLS where sessions are short-lived
- Easier to implement correctly across the stack

### highsec (Federal/CNSA 2.0)

**For:** Government contracts, defence customers, compliance-required deployments

See the [HIGH SECURITY: Federal Requirements](#high-security-federal-requirements) section below.

| Component | Algorithm | Notes |
| --------- | --------- | ----- |
| SSH keys | Ed25519 + ML-KEM hybrid | OpenSSH 10.0+ default |
| TLS certificates | ECDSA P-384 (transitioning to ML-DSA) | Per CNSA 2.0 timeline |
| Key exchange | ML-KEM-1024 (hybrid) | Post-quantum |
| Symmetric | AES-256 | FIPS 197 |
| Hashing | SHA-384 or SHA-512 | FIPS 180-4 |
| Digital signatures | ML-DSA-87 | FIPS 204 |

### Which Profile to Use?

| Project Type | Profile | Why |
| ------------ | ------- | --- |
| Production services | **prod** | Corporate default for anything real |
| Customer data, API keys | **prod** | Worth the small overhead |
| Local dev, prototypes | devtest | Speed and simplicity |
| Internal tools, staging | devtest | Good enough, less friction |
| Federal/defence contracts | highsec | Contractual requirement |
| "We might sell to DoD someday" | **prod** | P-384 satisfies most requirements |

**Rule of thumb:** If you're unsure, use **prod**. The performance difference is negligible for most workloads, and you won't have to retrofit later.

---

## Quick Reference

### SSH Keys (all profiles)

```bash
ssh-keygen -t ed25519 -C "user@hyperi.io"
```

Ed25519 for all profiles. RSA-4096 only when Ed25519 is unsupported.

### TLS Certificates

**prod (corporate default):**

| Use Case | Algorithm | Size | Notes |
| -------- | --------- | ---- | ----- |
| TLS certificates | ECDSA | P-384 | Production default |
| CA certificates | ECDSA | P-384 | Long-lived certs |
| Hashing | SHA-384 | - | Matches P-384 security level |

**devtest:**

| Use Case | Algorithm | Size | Notes |
| -------- | --------- | ---- | ----- |
| TLS certificates | ECDSA | P-256 | Industry default, lighter |
| Hashing | SHA-256 | - | Sufficient for dev/test |

**highsec:** → See [HIGH SECURITY: Federal Requirements](#high-security-federal-requirements)

### Symmetric Encryption (all profiles)

| Algorithm | Notes |
| --------- | ----- |
| AES-256-GCM | TLS 1.3 default |

### Passwords (all profiles)

| Type | Length | Entropy |
| ---- | ------ | ------- |
| Alphanumeric | 20+ chars | ~119 bits |

**Non-negotiable Stuff:**

- TLS 1.2 minimum, TLS 1.3 preferred
- No SHA-1, MD5, DES, 3DES, RC4, or CBC mode
- Private keys never in git (see gitignore section)
- File permissions: 600 for private keys, 700 for .ssh directory

---

## CNSA 2.0 Overview

The NSA's [Commercial National Security Algorithm Suite 2.0](https://media.defense.gov/2022/Sep/07/2003071836/-1/-1/0/CSI_CNSA_2.0_FAQ_.PDF)

### CNSA 2.0 Requirements (High Profile)

| Function | Algorithm | Parameter |
| -------- | --------- | --------- |
| Symmetric encryption | AES | 256-bit keys (FIPS 197) |
| Hashing | SHA | SHA-384 or SHA-512 (FIPS 180-4) |
| Key establishment | ML-KEM | ML-KEM-1024 (FIPS 203) |
| Digital signatures | ML-DSA | ML-DSA-87 (FIPS 204) |
| Software/firmware signing | LMS or XMSS | Per NIST SP 800-208 |

### What This Means

Post-quantum (ML-KEM, ML-DSA) isn't widely available yet. Our approach:

1. **Use the strongest classical algorithms** - ECDSA P-384, Ed25519, AES-256, SHA-384
2. **Enable hybrid PQ where available** - OpenSSH 9.9+ has mlkem768x25519-sha256
3. **Plan for transition** - Design so you can swap the crypto can as you need to, ideally with the hyperi-pylib/hyperi-rustlib config cascade
4. **Common lib** - TLS helpers in hyperi-pylib and hyperi-rustlib implement these standards

---

## SSH Keys

### Default: Ed25519

Ed25519 is the default for all new SSH keys. It's fast, secure, and the keys are tiny.

```bash
# Generate Ed25519 key (default choice)
ssh-keygen -t ed25519 -C "your_email@example.com"

# With custom filename
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_ed25519_work
```

**Why Ed25519:**

- Fixed 256-bit key (equivalent to ~3072-bit RSA)
- Deterministic signatures - no random number generator vulnerabilities
- Resistant to timing attacks
- Tiny keys and signatures (68 bytes vs RSA's 512+)

### Fallback: RSA-4096

When Ed25519 isn't supported (old enterprise systems, some embedded devices):

```bash
# RSA-4096 for legacy compatibility
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

### Avoid: ECDSA

Don't use ECDSA for SSH keys. The NIST curves have NSA involvement concerns, and ECDSA requires a perfect random number generator for each signature. If the RNG fails, your private key leaks.
Default entropy on most default OS deployment is woefully poor (see our Linix SOE improvements there) so this only amplifies the problem.

### Post-Quantum SSH (OpenSSH 9.9+)

OpenSSH 10.0 made hybrid post-quantum key exchange the default. Check your version:

```bash
ssh -V
```

The key exchange algorithms in order of preference:

| Algorithm | OpenSSH Version | Notes |
| --------- | --------------- | ----- |
| mlkem768x25519-sha256 | 9.9+ | ML-KEM hybrid, default in 10.0 |
| sntrup761x25519-sha512 | 9.0+ | NTRU Prime hybrid, previous default |
| curve25519-sha256 | 6.5+ | Classical fallback |

To explicitly prefer post-quantum in ssh_config:

```text
Host *
    KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512,curve25519-sha256
```

### File Permissions

SSH is strict about permissions. Wrong permissions = SSH refuses to use the key.

```bash
# Set correct permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519          # Private key
chmod 644 ~/.ssh/id_ed25519.pub      # Public key
chmod 600 ~/.ssh/config
chmod 644 ~/.ssh/authorized_keys
chmod 644 ~/.ssh/known_hosts

# Fix ownership
chown -R $USER:$USER ~/.ssh
```

| File | Permission | Why |
| ---- | ---------- | --- |
| `~/.ssh/` | 700 | Only owner can access directory |
| Private keys | 600 | Only owner can read |
| Public keys | 644 | Anyone can read |
| `config` | 600 | May contain sensitive options |
| `authorized_keys` | 644 | Server needs to read |

---

## Certificate Format: PEM

**PEM is the standard format for all HyperI certificates and keys.**

### Why PEM

| Format | Extension | Use Case |
| ------ | --------- | -------- |
| **PEM** | `.crt`, `.key`, `.pem` | **Default - use this** |
| DER | `.der`, `.cer` | Binary, rarely needed |
| PKCS#12 | `.p12`, `.pfx` | Only when required by service |

PEM files are:

- Base64-encoded with `-----BEGIN/END-----` headers
- Human-readable (easy to inspect and debug)
- Widely supported by all tools and libraries
- Easy to concatenate (cert chains)
- Git-diffable (though keys should never be in git)

### PEM File Naming

```text
server.key       # Private key
server.crt       # Certificate (or .pem)
ca.crt           # CA certificate
chain.crt        # Certificate chain (intermediate + root)
fullchain.crt    # Server cert + chain (for nginx, etc.)
client.crt       # Client certificate (mTLS)
client.key       # Client private key (mTLS)
```

### Inspect PEM Files

```bash
# View certificate details
openssl x509 -in server.crt -text -noout

# View private key info (without exposing key)
openssl ec -in server.key -text -noout 2>/dev/null || \
openssl rsa -in server.key -text -noout

# Verify cert matches key
openssl x509 -in server.crt -noout -modulus | openssl md5
openssl ec -in server.key -noout -modulus 2>/dev/null | openssl md5 || \
openssl rsa -in server.key -noout -modulus | openssl md5
```

### When to Use Other Formats

| Service | Required Format | Convert From PEM |
| ------- | --------------- | ---------------- |
| Java KeyStore | `.jks` | `keytool -importcert` |
| Windows IIS | `.pfx` | `openssl pkcs12 -export` |
| Some load balancers | `.p12` | `openssl pkcs12 -export` |

**Convert PEM to PKCS#12 (only when required):**

```bash
openssl pkcs12 -export \
    -in server.crt \
    -inkey server.key \
    -certfile ca.crt \
    -out server.p12
```

---

## TLS Certificate Generation

### Default: ECDSA P-384

For new certificates, use ECDSA with the P-384 curve. It's the sweet spot of security and performance.

```bash
# Generate P-384 private key
openssl ecparam -genkey -name secp384r1 -out server.key

# Generate CSR
openssl req -new -key server.key -out server.csr \
    -subj "/CN=app.example.com/O=HyperI/C=AU"

# Self-signed certificate (dev/testing only)
openssl req -x509 -new -key server.key -out server.crt \
    -days 365 -sha384 \
    -subj "/CN=app.example.com/O=HyperI/C=AU"
```

**One-liner for dev certs:**

```bash
openssl req -newkey ec:<(openssl ecparam -name secp384r1) \
    -nodes -x509 -keyout server.key -out server.crt \
    -days 365 -subj "/CN=localhost/O=Dev/C=AU"
```

### Why P-384 over RSA

| Metric | ECDSA P-384 | RSA-4096 |
| ------ | ----------- | -------- |
| Security level | 192-bit | ~140-bit |
| Key size | 48 bytes | 512 bytes |
| Signature size | 96 bytes | 512 bytes |
| Sign speed | ~2100/sec | ~10/sec |
| TLS handshake | Faster | Slower |

P-384 is recommended by NSA's CNSA 2.0 and provides 192-bit security equivalent.

### Fallback: RSA-4096

For maximum compatibility with legacy clients:

```bash
# Generate RSA-4096 key
openssl genrsa -out server.key 4096

# Generate CSR
openssl req -new -key server.key -out server.csr \
    -subj "/CN=app.example.com/O=HyperI/C=AU"

# Self-signed
openssl req -x509 -new -key server.key -out server.crt \
    -days 365 -sha384 \
    -subj "/CN=app.example.com/O=HyperI/C=AU"
```

### CA Certificates

For Certificate Authority certs (longer-lived):

```bash
# CA with ECDSA P-384 (preferred)
openssl ecparam -genkey -name secp384r1 -out ca.key
openssl req -x509 -new -key ca.key -out ca.crt \
    -days 3650 -sha384 \
    -subj "/CN=HyperI Internal CA/O=HyperI/C=AU"

# Sign a server cert with the CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt -days 365 -sha384
```

### Certificate File Extensions

| Extension | Format | Contents |
| --------- | ------ | -------- |
| `.key` | PEM | Private key |
| `.csr` | PEM | Certificate signing request |
| `.crt` / `.pem` | PEM | Certificate |
| `.p12` / `.pfx` | PKCS#12 | Key + cert bundle (password protected) |
| `.jks` | Java KeyStore | Java applications |

### Certificate Locations

**Linux (Ubuntu/Debian/Fedora):**

| Purpose | Location |
| ------- | -------- |
| System CA bundle | `/etc/ssl/certs/ca-certificates.crt` |
| Custom CA certs | `/usr/local/share/ca-certificates/` |
| Service certs | `/etc/ssl/private/` or `/etc/<service>/certs/` |

**macOS:**

| Purpose | Location |
| ------- | -------- |
| System Keychain | `/Library/Keychains/System.keychain` |
| User certs | `~/Library/Keychains/login.keychain` |
| CLI tools | `/etc/ssl/cert.pem` (symlink to system) |

**Add custom CA (Linux):**

```bash
# Ubuntu/Debian
sudo cp myca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# Fedora/RHEL
sudo cp myca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

---

## TLS Configuration

### TLS 1.3 (Preferred)

TLS 1.3 is the target. It removes weak cipher options and simplifies configuration.

**Cipher suites (in priority order):**

1. `TLS_AES_256_GCM_SHA384` - AES-256, strongest
2. `TLS_CHACHA20_POLY1305_SHA256` - Good on mobile/ARM
3. `TLS_AES_128_GCM_SHA256` - Acceptable fallback

### TLS 1.2 (Fallback)

When TLS 1.3 isn't available, use TLS 1.2 with AEAD ciphers only:

```text
ECDHE-ECDSA-AES256-GCM-SHA384
ECDHE-RSA-AES256-GCM-SHA384
ECDHE-ECDSA-CHACHA20-POLY1305
ECDHE-RSA-CHACHA20-POLY1305
ECDHE-ECDSA-AES128-GCM-SHA256
ECDHE-RSA-AES128-GCM-SHA256
```

**Key exchange:** ECDHE with X25519 or P-256

### Nginx Example

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;  # Let client choose in TLS 1.3
ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305;

ssl_certificate /etc/nginx/ssl/server.crt;
ssl_certificate_key /etc/nginx/ssl/server.key;

# HSTS (optional but recommended)
add_header Strict-Transport-Security "max-age=31536000" always;
```

### Envoy Example (K8s)

Envoy proxy with P-384 TLS, typically used with Gateway API or as sidecar:

```yaml
# Envoy TLS configuration (static or via xDS)
static_resources:
  listeners:
    - name: https_listener
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 8443
      filter_chains:
        - transport_socket:
            name: envoy.transport_sockets.tls
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
              common_tls_context:
                tls_params:
                  tls_minimum_protocol_version: TLSv1_2
                  tls_maximum_protocol_version: TLSv1_3
                  cipher_suites:
                    - TLS_AES_256_GCM_SHA384
                    - TLS_CHACHA20_POLY1305_SHA256
                    - ECDHE-ECDSA-AES256-GCM-SHA384
                    - ECDHE-RSA-AES256-GCM-SHA384
                tls_certificates:
                  - certificate_chain:
                      filename: /etc/envoy/certs/server.crt
                    private_key:
                      filename: /etc/envoy/certs/server.key
                validation_context:
                  trusted_ca:
                    filename: /etc/envoy/certs/ca.crt
```

**Gateway API with Envoy (Envoy Gateway):**

```yaml
# Gateway with TLS (cert from Secret)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: prod-gateway
spec:
  gatewayClassName: envoy
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: tls-certs  # cert-manager managed
---
# HTTPRoute
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
spec:
  parentRefs:
    - name: prod-gateway
  hostnames:
    - "app.example.com"
  rules:
    - backendRefs:
        - name: app-service
          port: 8080
```

**Envoy mTLS (client cert required):**

```yaml
# DownstreamTlsContext with client validation
common_tls_context:
  tls_certificates:
    - certificate_chain:
        filename: /etc/envoy/certs/server.crt
      private_key:
        filename: /etc/envoy/certs/server.key
  validation_context:
    trusted_ca:
      filename: /etc/envoy/certs/client-ca.crt
    # Require client certificate
require_client_certificate: true
```

### Disabled Algorithms

Never use:

| Algorithm | Why |
| --------- | --- |
| SSLv2, SSLv3, TLS 1.0, TLS 1.1 | Known vulnerabilities |
| MD5, SHA-1 | Broken hashes |
| DES, 3DES | Weak encryption |
| RC4 | Broken stream cipher |
| CBC mode | Padding oracle attacks |
| RSA key exchange | No forward secrecy |
| Export ciphers | Intentionally weak |

---

## Database TLS

### PostgreSQL

**Server configuration (postgresql.conf):**

```ini
ssl = on
ssl_min_protocol_version = 'TLSv1.2'
ssl_max_protocol_version = 'TLSv1.3'
ssl_cert_file = '/etc/postgresql/server.crt'
ssl_key_file = '/etc/postgresql/server.key'
ssl_ca_file = '/etc/postgresql/ca.crt'

# TLS 1.2 ciphers (TLS 1.3 auto-negotiates)
ssl_ciphers = 'HIGH:!aNULL:!MD5:!3DES'
```

**PostgreSQL 18+ adds TLS 1.3 cipher control:**

```ini
ssl_tls13_ciphers = 'TLS_AES_256_GCM_SHA384'
```

**Client connection (require full verification):**

```bash
psql "host=db.example.com dbname=app user=app sslmode=verify-full sslrootcert=/path/to/ca.crt"
```

**sslmode options:**

| Mode | Certificate Check | Hostname Check |
| ---- | ----------------- | -------------- |
| disable | No | No |
| require | No | No |
| verify-ca | Yes | No |
| verify-full | Yes | Yes |

Use `verify-full` for production.

### ClickHouse

**Server configuration (config.d/ssl.xml):**

```xml
<clickhouse>
    <https_port>8443</https_port>
    <tcp_port_secure>9440</tcp_port_secure>

    <openSSL>
        <server>
            <certificateFile>/etc/clickhouse-server/certs/server.crt</certificateFile>
            <privateKeyFile>/etc/clickhouse-server/certs/server.key</privateKeyFile>
            <caConfig>/etc/clickhouse-server/certs/ca.crt</caConfig>
            <verificationMode>strict</verificationMode>
            <cacheSessions>true</cacheSessions>
            <disableProtocols>sslv2,sslv3,tlsv1,tlsv1_1</disableProtocols>
            <preferServerCiphers>true</preferServerCiphers>
        </server>
    </openSSL>
</clickhouse>
```

**Disable insecure ports:**

```xml
<!-- Comment these out -->
<!-- <http_port>8123</http_port> -->
<!-- <tcp_port>9000</tcp_port> -->
```

**Client connection:**

```bash
clickhouse-client --host db.example.com --port 9440 --secure
```

---

## Kafka / AutoMQ TLS

Kafka uses mTLS (mutual TLS) for both encryption and authentication.

### Broker Configuration

```properties
# Enable SSL
listeners=SSL://0.0.0.0:9093
advertised.listeners=SSL://kafka.example.com:9093
security.inter.broker.protocol=SSL

# SSL settings
ssl.keystore.location=/etc/kafka/certs/kafka.keystore.p12
ssl.keystore.password=${KEYSTORE_PASSWORD}
ssl.keystore.type=PKCS12
ssl.truststore.location=/etc/kafka/certs/kafka.truststore.p12
ssl.truststore.password=${TRUSTSTORE_PASSWORD}
ssl.truststore.type=PKCS12

# mTLS - require client certificates
ssl.client.auth=required

# TLS version
ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3
```

### Create Keystores

```bash
# Generate broker key and cert
openssl ecparam -genkey -name secp384r1 -out broker.key
openssl req -new -key broker.key -out broker.csr \
    -subj "/CN=kafka.example.com/O=HyperI/C=AU"
openssl x509 -req -in broker.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out broker.crt -days 365 -sha384

# Create PKCS12 keystore
openssl pkcs12 -export -in broker.crt -inkey broker.key \
    -out kafka.keystore.p12 -name kafka \
    -CAfile ca.crt -caname root -chain

# Create truststore with CA
keytool -importcert -file ca.crt -keystore kafka.truststore.p12 \
    -storetype PKCS12 -alias ca -noprompt
```

### Client Configuration (Python)

```python
from kafka import KafkaProducer

producer = KafkaProducer(
    bootstrap_servers=['kafka.example.com:9093'],
    security_protocol='SSL',
    ssl_cafile='/path/to/ca.crt',
    ssl_certfile='/path/to/client.crt',
    ssl_keyfile='/path/to/client.key',
)
```

---

## Passwords and Secrets

### Password Policy

**Default: 20 alphanumeric characters (a-z, A-Z, 0-9)**

```bash
# Generate a 20-char alphanumeric password
openssl rand -base64 30 | tr -dc 'a-zA-Z0-9' | head -c 20
```

**Why this works:**

- 62 possible characters per position
- 20 characters = 62^20 combinations = ~119 bits of entropy
- Well above the 80-bit minimum for "strong" passwords
- NIST 2024 confirms length matters more than complexity

**When to use special characters:**

- System requires them (some password policies)
- Key derivation functions (add complexity for KDFs)
- Otherwise, don't bother - they cause escaping headaches

### Entropy Reference

| Password Type | Chars | Length | Entropy |
| ------------- | ----- | ------ | ------- |
| Alphanumeric | 62 | 20 | ~119 bits |
| Alphanumeric | 62 | 16 | ~95 bits |
| Full ASCII printable | 94 | 16 | ~105 bits |
| Alphanumeric | 62 | 12 | ~71 bits |
| Lowercase + digits | 36 | 20 | ~103 bits |

20 alphanumeric gives better entropy than 16 with special chars.

### Secret Storage

**Never store secrets in:**

- Git repositories
- Environment variables in code
- Plain text config files committed to git

**Use instead:**

- HashiCorp Vault (production)
- 1Password / cloud secrets managers
- Environment variables at runtime (not in code)
- Encrypted files with strict permissions

---

## Gitignore for Cryptographic Files

**These patterns are mandatory in every project:**

```gitignore
# Private keys - NEVER commit
*.key
*.pem
!*.pub.pem
*.p12
*.pfx
*.jks
*.keystore

# Certificate signing requests (contain public key, but keep out of git anyway)
*.csr

# Environment files with secrets
.env
.env.*
!.env.example

# SSH keys
id_rsa
id_rsa.pub
id_ed25519
id_ed25519.pub
id_ecdsa
id_ecdsa.pub

# HashiCorp Vault tokens
.vault-token

# AWS credentials
.aws/credentials
credentials.json

# Database credentials
*.pgpass
.my.cnf

# Terraform state (contains secrets)
*.tfstate
*.tfstate.*

# Ansible vault files (encrypted but still sensitive)
*vault*.yml
!*vault*.yml.example
```

### Project Certificate Locations

For projects that need certificates:

```text
project/
├── certs/                    # Gitignored directory
│   ├── .gitkeep             # Only this file committed
│   ├── ca.crt               # CA certificate (can be committed if public)
│   ├── server.crt           # Server certificate
│   └── server.key           # Private key - NEVER COMMIT
├── .gitignore               # Contains certs/*.key, etc.
└── README.md                # Documents how to generate/obtain certs
```

### Global Gitignore

Add to `~/.gitignore_global`:

```gitignore
# Always ignore private keys globally
*.key
*.pem
*.p12
id_rsa
id_ed25519
.env
```

Enable it:

```bash
git config --global core.excludesfile ~/.gitignore_global
```

---

## Platform-Specific Notes

### Ubuntu / Debian

```bash
# Install OpenSSL (usually pre-installed)
sudo apt update && sudo apt install openssl

# Check OpenSSL version
openssl version

# OpenSSH version
ssh -V

# Update CA certificates
sudo update-ca-certificates
```

### Fedora

```bash
# Install OpenSSL
sudo dnf install openssl

# Update CA certificates
sudo update-ca-trust
```

### macOS

```bash
# Homebrew OpenSSL (newer than system)
brew install openssl@3

# Use Homebrew OpenSSL
export PATH="/opt/homebrew/opt/openssl@3/bin:$PATH"

# Add CA to system keychain
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain myca.crt
```

### Windows (WSL2)

Use WSL2 with Ubuntu. Native Windows uses different certificate stores (certutil, MMC).

---

## Language-Specific

### Python

```python
import ssl
import certifi

# Create SSL context with modern settings
ctx = ssl.create_default_context(cafile=certifi.where())
ctx.minimum_version = ssl.TLSVersion.TLSv1_2
ctx.set_ciphers('ECDHE+AESGCM:CHACHA20:!aNULL:!MD5:!DSS')

# For requests library
import requests
response = requests.get('https://api.example.com', verify=certifi.where())

# For PostgreSQL with psycopg
import psycopg
conn = psycopg.connect(
    "host=db.example.com dbname=app user=app",
    sslmode="verify-full",
    sslrootcert="/path/to/ca.crt"
)
```

### Rust

```rust
use rustls::{ClientConfig, RootCertStore};
use std::sync::Arc;

// Load system CA certificates
let mut root_store = RootCertStore::empty();
root_store.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());

let config = ClientConfig::builder()
    .with_root_certificates(root_store)
    .with_no_client_auth();

let config = Arc::new(config);
```

### TypeScript / Node.js

```typescript
import https from 'https';
import fs from 'fs';

// HTTPS server with custom certs
const server = https.createServer({
  key: fs.readFileSync('/path/to/server.key'),
  cert: fs.readFileSync('/path/to/server.crt'),
  ca: fs.readFileSync('/path/to/ca.crt'),
  minVersion: 'TLSv1.2',
}, app);

// HTTPS client with CA verification
const agent = new https.Agent({
  ca: fs.readFileSync('/path/to/ca.crt'),
  rejectUnauthorized: true,
});
```

### Go

```go
package main

import (
    "crypto/tls"
    "crypto/x509"
    "net/http"
    "os"
)

func main() {
    // Load CA certificate
    caCert, _ := os.ReadFile("/path/to/ca.crt")
    caCertPool := x509.NewCertPool()
    caCertPool.AppendCertsFromPEM(caCert)

    // TLS config with modern settings
    tlsConfig := &tls.Config{
        RootCAs:    caCertPool,
        MinVersion: tls.VersionTLS12,
        CipherSuites: []uint16{
            tls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
            tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
            tls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,
        },
    }

    // HTTP client with TLS
    client := &http.Client{
        Transport: &http.Transport{TLSClientConfig: tlsConfig},
    }

    resp, _ := client.Get("https://api.example.com")
    defer resp.Body.Close()
}

// mTLS client (with client certificate)
func mTLSClient() *http.Client {
    cert, _ := tls.LoadX509KeyPair("/path/to/client.crt", "/path/to/client.key")
    caCert, _ := os.ReadFile("/path/to/ca.crt")
    caCertPool := x509.NewCertPool()
    caCertPool.AppendCertsFromPEM(caCert)

    tlsConfig := &tls.Config{
        Certificates: []tls.Certificate{cert},
        RootCAs:      caCertPool,
        MinVersion:   tls.VersionTLS12,
    }

    return &http.Client{
        Transport: &http.Transport{TLSClientConfig: tlsConfig},
    }
}
```

**Go TLS notes:**

- Go defaults to TLS 1.2+ and secure ciphers - usually no config needed
- Never set `InsecureSkipVerify: true` in production
- Use `SubjectAltName` (SAN) in certs - Go deprecated Common Name matching
- Go's crypto/tls supports FIPS mode via build tags

### C++

```cpp
// OpenSSL-based TLS (most common in C++)
#include <openssl/ssl.h>
#include <openssl/err.h>

SSL_CTX* create_tls_context() {
    // Use TLS 1.2+ only
    SSL_CTX* ctx = SSL_CTX_new(TLS_client_method());

    // Set minimum TLS version
    SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION);

    // Load CA certificates
    SSL_CTX_load_verify_locations(ctx, "/path/to/ca.crt", nullptr);

    // Enable certificate verification
    SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, nullptr);

    // Set strong cipher list (TLS 1.2)
    SSL_CTX_set_cipher_list(ctx,
        "ECDHE-ECDSA-AES256-GCM-SHA384:"
        "ECDHE-RSA-AES256-GCM-SHA384:"
        "ECDHE-ECDSA-CHACHA20-POLY1305");

    // Set TLS 1.3 ciphersuites
    SSL_CTX_set_ciphersuites(ctx, "TLS_AES_256_GCM_SHA384");

    return ctx;
}

// mTLS - load client certificate
void load_client_cert(SSL_CTX* ctx) {
    SSL_CTX_use_certificate_file(ctx, "/path/to/client.crt", SSL_FILETYPE_PEM);
    SSL_CTX_use_PrivateKey_file(ctx, "/path/to/client.key", SSL_FILETYPE_PEM);
    SSL_CTX_check_private_key(ctx);
}
```

**C++ TLS notes:**

- Use OpenSSL 3.x or BoringSSL for modern TLS support
- Always call `SSL_CTX_set_verify()` with `SSL_VERIFY_PEER`
- Check return values - OpenSSL fails silently
- Consider wolfSSL or mbedTLS for embedded systems

### Bash

```bash
# curl with custom CA
curl --cacert /path/to/ca.crt https://api.example.com

# curl with client certificate (mTLS)
curl --cacert /path/to/ca.crt \
     --cert /path/to/client.crt \
     --key /path/to/client.key \
     https://api.example.com

# wget with custom CA
wget --ca-certificate=/path/to/ca.crt https://api.example.com

# OpenSSL s_client for debugging
openssl s_client -connect api.example.com:443 -CAfile /path/to/ca.crt
```

---

## Infrastructure Tools

### Terraform

Use Vault for PKI in Terraform:

```hcl
# Request a certificate from Vault PKI
resource "vault_pki_secret_backend_cert" "app" {
  backend     = "pki"
  name        = "server-role"
  common_name = "app.example.com"
  ttl         = "720h"
}

# Output certificate to file (use carefully)
resource "local_sensitive_file" "cert" {
  content  = vault_pki_secret_backend_cert.app.certificate
  filename = "${path.module}/certs/server.crt"
}
```

**Never store private keys in Terraform state.** Use Vault's transit engine or external secret management.

### Ansible

```yaml
# Generate private key
- name: Generate ECDSA private key
  community.crypto.openssl_privatekey:
    path: /etc/ssl/private/server.key
    type: ECC
    curve: secp384r1
    mode: '0600'

# Generate CSR
- name: Generate CSR
  community.crypto.openssl_csr:
    path: /etc/ssl/certs/server.csr
    privatekey_path: /etc/ssl/private/server.key
    common_name: "{{ ansible_fqdn }}"
    organization_name: HyperI

# Self-signed cert (dev only)
- name: Generate self-signed certificate
  community.crypto.x509_certificate:
    path: /etc/ssl/certs/server.crt
    privatekey_path: /etc/ssl/private/server.key
    csr_path: /etc/ssl/certs/server.csr
    provider: selfsigned
```

### Helm

```yaml
# values.yaml - reference external secrets
tls:
  enabled: true
  secretName: app-tls  # Created externally or by cert-manager

# cert-manager integration
certManager:
  enabled: true
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

---

## Proxmox VE

We use Terraform ACME provider with DNS-01 challenge, not the built-in Proxmox ACME client. This gives us more control over key type (P-384) and allows automation via Ansible.

### Pattern: Terraform ACME + Ansible Deployment

**1. Terraform issues wildcard cert via Route53 DNS-01:**

```hcl
# terraform/modules/acme-cert/main.tf
resource "tls_private_key" "acme_account" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "acme_certificate" "wildcard" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = var.domain
  subject_alternative_names = ["*.${var.domain}"]

  # ECDSA P-384 for prod profile
  key_type = "P384"

  # DNS-01 challenge via Route53
  dns_challenge {
    provider = "route53"
    config = {
      AWS_HOSTED_ZONE_ID = var.route53_zone_id
      AWS_PROFILE        = var.aws_profile
    }
  }

  min_days_remaining = 30
}

# Output PEM files for Ansible
resource "local_sensitive_file" "private_key" {
  content         = acme_certificate.wildcard.private_key_pem
  filename        = "${var.output_path}/privkey.pem"
  file_permission = "0600"
}

resource "local_file" "fullchain" {
  content         = "${acme_certificate.wildcard.certificate_pem}${acme_certificate.wildcard.issuer_pem}"
  filename        = "${var.output_path}/fullchain.pem"
  file_permission = "0644"
}
```

**2. Ansible deploys certs to hosts:**

```yaml
# ansible/roles/tls_certs/tasks/main.yml
- name: Deploy certificate chain
  ansible.builtin.copy:
    src: "{{ tls_cert_source_dir }}/fullchain.pem"
    dest: "{{ tls_cert_dest_dir }}/fullchain.pem"
    owner: root
    group: root
    mode: "0644"
  notify: reload tls services

- name: Deploy private key
  ansible.builtin.copy:
    src: "{{ tls_cert_source_dir }}/privkey.pem"
    dest: "{{ tls_key_dest_dir }}/privkey.pem"
    owner: root
    group: "{{ tls_key_group }}"
    mode: "0640"
  no_log: true  # Don't log private key
  notify: reload tls services
```

**3. For Proxmox Web UI specifically:**

```yaml
# Proxmox expects specific paths
- name: Deploy Proxmox Web UI certificate
  ansible.builtin.copy:
    src: "{{ tls_cert_source_dir }}/fullchain.pem"
    dest: /etc/pve/local/pveproxy-ssl.pem
    owner: root
    group: www-data
    mode: "0640"
  notify: restart pveproxy

- name: Deploy Proxmox Web UI key
  ansible.builtin.copy:
    src: "{{ tls_cert_source_dir }}/privkey.pem"
    dest: /etc/pve/local/pveproxy-ssl.key
    owner: root
    group: www-data
    mode: "0640"
  no_log: true
  notify: restart pveproxy
```

### Why Not Built-in Proxmox ACME?

| Built-in ACME | Our Pattern |
| ------------- | ----------- |
| HTTP-01 or DNS plugin | DNS-01 via Route53/Terraform |
| RSA-2048 default | ECDSA P-384 (key_type = "P384") |
| Per-node config | Centralized Terraform state |
| Manual renewal | Auto-renewal with min_days_remaining |
| No metrics | Prometheus cert expiry metrics |

### Certificate Expiry Metrics

The tls_certs role includes Prometheus metrics for cert expiry monitoring:

```bash
# /var/lib/node_exporter/textfile_collector/cert_expiry.prom
ssl_certificate_expiry_timestamp_seconds{domain="devex.hyperi.io"} 1735689600
ssl_certificate_days_remaining{domain="devex.hyperi.io"} 45
```

### Proxmox Certificate Locations

| File | Purpose |
| ---- | ------- |
| `/etc/pve/local/pveproxy-ssl.pem` | Web UI certificate |
| `/etc/pve/local/pveproxy-ssl.key` | Web UI private key |
| `/etc/pve/pve-root-ca.pem` | Cluster CA (auto-generated) |
| `/etc/pve/nodes/<node>/pve-ssl.pem` | Node certificate (cluster internal) |

**Note:** The cluster internal certs (`pve-root-ca.pem`, node certs) are auto-managed by Proxmox. We only replace the pveproxy cert for Web UI.

---

## Rancher / K3s

Rancher uses cert-manager for certificate management.

### cert-manager with Rancher

**Install cert-manager:**

```bash
# Add Jetstack Helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true
```

### Certificate Options for Rancher

| Option | Use Case |
| ------ | -------- |
| Rancher-generated | Self-signed, quick setup, dev/test |
| Let's Encrypt | Public-facing, automated renewal |
| Bring your own | Enterprise CA, compliance requirements |

**Let's Encrypt with Rancher:**

```bash
helm install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --create-namespace \
    --set hostname=rancher.example.com \
    --set ingress.tls.source=letsEncrypt \
    --set letsEncrypt.email=admin@example.com \
    --set letsEncrypt.ingress.class=nginx
```

**Bring your own certificate:**

```bash
# Create TLS secret
kubectl -n cattle-system create secret tls tls-rancher-ingress \
    --cert=server.crt \
    --key=server.key

# Create CA secret (if using private CA)
kubectl -n cattle-system create secret generic tls-ca \
    --from-file=cacerts.pem=ca.crt

# Install Rancher
helm install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --set hostname=rancher.example.com \
    --set ingress.tls.source=secret \
    --set privateCA=true
```

### ClusterIssuer for Workload Certificates

```yaml
# letsencrypt-prod.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

```yaml
# Certificate for a workload
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-tls
  namespace: myapp
spec:
  secretName: app-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - app.example.com
```

---

## OpenBao (Vault Fork)

OpenBao is a community fork of HashiCorp Vault under MPL 2.0. The PKI secrets engine is API-compatible with Vault.

### PKI Secrets Engine Setup

```bash
# Enable PKI secrets engine
bao secrets enable pki

# Configure max TTL (10 years for root)
bao secrets tune -max-lease-ttl=87600h pki

# Generate root CA (or import existing)
bao write pki/root/generate/internal \
    common_name="HyperI Root CA" \
    ttl=87600h \
    key_type=ec \
    key_bits=384

# Configure CA and CRL URLs
bao write pki/config/urls \
    issuing_certificates="https://vault.example.com/v1/pki/ca" \
    crl_distribution_points="https://vault.example.com/v1/pki/crl"
```

### Intermediate CA (Recommended)

Keep root CA offline, use intermediate for issuing:

```bash
# Enable intermediate PKI
bao secrets enable -path=pki_int pki
bao secrets tune -max-lease-ttl=43800h pki_int

# Generate intermediate CSR
bao write pki_int/intermediate/generate/internal \
    common_name="HyperI Intermediate CA" \
    key_type=ec \
    key_bits=384

# Sign with root CA
bao write pki/root/sign-intermediate \
    csr=@pki_int.csr \
    format=pem_bundle \
    ttl=43800h

# Import signed intermediate
bao write pki_int/intermediate/set-signed certificate=@signed_cert.pem
```

### Certificate Role

```bash
# Create role for issuing server certs
bao write pki_int/roles/server \
    allowed_domains="example.com" \
    allow_subdomains=true \
    max_ttl=720h \
    key_type=ec \
    key_bits=384 \
    require_cn=false \
    allow_ip_sans=true
```

### Issue Certificates

```bash
# Issue a certificate
bao write pki_int/issue/server \
    common_name="app.example.com" \
    alt_names="app.internal.example.com" \
    ttl=720h

# Output includes: certificate, private_key, ca_chain
```

### Performance Notes

OpenBao PKI performance with EC keys is much better than RSA:

| Key Type | Issuance Rate |
| -------- | ------------- |
| EC P-256 | ~300k certs (no storage) |
| EC P-384 | ~250k certs (no storage) |
| RSA-4096 | ~160 certs |

For high-volume deployments (>250k active certs), use audit logs instead of storing certs in OpenBao.

---

## AWS Certificate Services

### ACM (AWS Certificate Manager)

ACM provides free public TLS certificates for AWS resources.

**Request a certificate:**

```bash
# Request public certificate (DNS validation preferred)
aws acm request-certificate \
    --domain-name app.example.com \
    --validation-method DNS \
    --subject-alternative-names "*.app.example.com"

# List certificates
aws acm list-certificates

# Describe certificate (get validation CNAME)
aws acm describe-certificate --certificate-arn arn:aws:acm:...
```

**Terraform:**

```hcl
resource "aws_acm_certificate" "app" {
  domain_name       = "app.example.com"
  validation_method = "DNS"

  subject_alternative_names = ["*.app.example.com"]

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation with Route53
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}
```

**ACM best practices:**

- Use DNS validation (auto-renews forever if CNAME exists)
- Use FQDNs, avoid wildcards where possible
- Don't pin ACM certificates (they rotate automatically)
- Separate production and dev/test certificates by account

### ACM Private CA

For internal certificates not trusted by browsers:

```bash
# Create private CA
aws acm-pca create-certificate-authority \
    --certificate-authority-configuration \
        KeyAlgorithm=EC_secp384r1,\
        SigningAlgorithm=SHA384WITHECDSA,\
        Subject='{
            "Country": "AU",
            "Organization": "HyperI",
            "CommonName": "HyperI Internal CA"
        }' \
    --certificate-authority-type ROOT

# Issue certificate from private CA
aws acm-pca issue-certificate \
    --certificate-authority-arn arn:aws:acm-pca:... \
    --csr fileb://server.csr \
    --signing-algorithm SHA384WITHECDSA \
    --validity Value=365,Type=DAYS
```

### AWS Services TLS Requirements

AWS requires TLS 1.2 minimum, recommends TLS 1.3.

**Enforce TLS 1.2+ on S3:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::bucket/*", "arn:aws:s3:::bucket"],
      "Condition": {
        "Bool": { "aws:SecureTransport": "false" }
      }
    }
  ]
}
```

**ALB/NLB TLS policies:**

| Policy | TLS Versions | Use Case |
| ------ | ------------ | -------- |
| `ELBSecurityPolicy-TLS13-1-2-2021-06` | TLS 1.2, 1.3 | Recommended |
| `ELBSecurityPolicy-TLS13-1-3-2021-06` | TLS 1.3 only | Maximum security |
| `ELBSecurityPolicy-FS-1-2-Res-2020-10` | TLS 1.2 only | Legacy compatibility |

### KMS for Certificate Keys

ACM uses KMS to protect private keys:

- ACM creates a managed KMS key `aws/acm` per region
- Private keys are never exported in plaintext
- Use AWS CloudTrail to audit certificate usage

**Post-quantum note:** AWS KMS, ACM, and Secrets Manager endpoints now support ML-KEM hybrid post-quantum key agreement on non-FIPS endpoints.

---

## Common Commands Cheat Sheet

### Inspect Certificates

```bash
# View certificate details
openssl x509 -in cert.crt -text -noout

# Check certificate expiration
openssl x509 -in cert.crt -enddate -noout

# Verify certificate chain
openssl verify -CAfile ca.crt server.crt

# View CSR
openssl req -in server.csr -text -noout

# Check private key
openssl ec -in server.key -check  # ECDSA
openssl rsa -in server.key -check # RSA
```

### Test TLS Connections

```bash
# Test HTTPS endpoint
openssl s_client -connect example.com:443 -servername example.com

# Show certificate chain
openssl s_client -connect example.com:443 -showcerts

# Test specific TLS version
openssl s_client -connect example.com:443 -tls1_3

# Check supported ciphers
nmap --script ssl-enum-ciphers -p 443 example.com
```

### Convert Formats

```bash
# PEM to PKCS12
openssl pkcs12 -export -in cert.crt -inkey cert.key -out cert.p12

# PKCS12 to PEM
openssl pkcs12 -in cert.p12 -out cert.pem -nodes

# DER to PEM
openssl x509 -inform DER -in cert.der -out cert.pem

# PEM to DER
openssl x509 -outform DER -in cert.pem -out cert.der

# Extract public key from private key
openssl ec -in private.key -pubout -out public.key  # ECDSA
openssl rsa -in private.key -pubout -out public.key # RSA
```

---

## Troubleshooting

### SSH: "WARNING: UNPROTECTED PRIVATE KEY FILE!"

```bash
chmod 600 ~/.ssh/id_ed25519
chmod 700 ~/.ssh
```

### SSL: "certificate verify failed"

1. Check the CA certificate is correct
2. Verify the hostname matches the certificate CN or SAN
3. Check certificate hasn't expired
4. Ensure intermediate certificates are included

```bash
# Debug
openssl s_client -connect host:443 -CAfile /path/to/ca.crt
```

### PostgreSQL: "SSL connection is required"

```bash
# Check server SSL is enabled
psql "host=db sslmode=require" -c "SHOW ssl"

# Check certificate files exist and have correct permissions
ls -la /var/lib/postgresql/*/main/server.crt
```

### Kafka: "SSL handshake failed"

1. Verify keystore and truststore passwords match config
2. Check certificate CN matches the hostname
3. Ensure broker and client use compatible TLS versions

```bash
# Test SSL connection
openssl s_client -connect kafka:9093
```

---

## For AI Code Assistants

### Generation Checklist

When generating cryptographic code:

1. **Never generate real private keys** - Use placeholders or generation commands
2. **Always use TLS 1.2+** - Never TLS 1.0/1.1 or SSL
3. **Default to ECDSA P-384** for certificates, Ed25519 for SSH
4. **Include certificate verification** - Don't disable with `verify=False`
5. **Add gitignore entries** for any secret files
6. **Set correct file permissions** - 600 for keys, 700 for directories

### Code Review Flags

Watch for:

- `ssl.CERT_NONE` or `verify=False` - Certificate verification disabled
- `ssl.PROTOCOL_SSLv3` or TLS 1.0/1.1 - Deprecated protocols
- MD5 or SHA-1 for signatures - Broken hashes
- RSA < 2048 bits - Weak keys
- Hardcoded passwords or keys - Should be external
- Missing gitignore for `.key`, `.pem`, `.env` files

### Example: Secure vs Insecure

```python
# BAD - Don't do this
import ssl
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE  # VULNERABLE

requests.get(url, verify=False)  # VULNERABLE

# GOOD - Do this
import ssl
import certifi

ctx = ssl.create_default_context(cafile=certifi.where())
ctx.minimum_version = ssl.TLSVersion.TLSv1_2

requests.get(url, verify=certifi.where())
```

---

## HIGH SECURITY: Federal Requirements

This section covers requirements for federal/defence customers, CNSA 2.0 compliance, and scenarios where "good enough" isn't good enough.

**When this applies:**

- Government or defence contracts (explicit requirement)
- Handling classified or export-controlled data
- Customer contractually requires CNSA/FIPS compliance
- Long-lived secrets (CA certs, signing keys with 10+ year lifetime)

### CNSA 2.0 Timeline

NSA's transition timeline for National Security Systems:

| Capability | Exclusive Use Date | Notes |
| ---------- | ------------------ | ----- |
| Software/firmware signing | 2025 | LMS/XMSS required |
| Web browsers/servers | 2025 | TLS 1.3 with CNSA algorithms |
| Traditional networking | 2026 | IPsec, MACsec |
| Operating systems | 2027 | Full stack |
| Legacy equipment | 2033 | Final sunset |

### Algorithm Requirements

**Mandatory for highsec:**

| Use | Algorithm | FIPS Standard |
| --- | --------- | ------------- |
| Symmetric encryption | AES-256 | FIPS 197 |
| Hashing | SHA-384 or SHA-512 | FIPS 180-4 |
| Key exchange | ML-KEM-1024 | FIPS 203 |
| Digital signatures | ML-DSA-87 | FIPS 204 |
| Firmware signing | LMS or XMSS | SP 800-208 |

**Current transition (until PQ widely available):**

- TLS: ECDSA P-384 with SHA-384, TLS 1.3 only
- SSH: Ed25519 with mlkem768x25519-sha256 key exchange
- IPsec: AES-256-GCM with SHA-384, DH Group 20 (P-384)

### Implementation Notes

**Post-quantum key exchange in TLS:**

As of January 2026, post-quantum TLS is emerging:

- **AWS:** ML-KEM hybrid available on KMS, ACM, Secrets Manager (non-FIPS endpoints)
- **Cloudflare:** Experimental PQ support in some products
- **OpenSSL 3.5+:** ML-KEM support expected
- **BoringSSL:** Kyber/ML-KEM hybrid already available (Chrome uses this)

For now, use TLS 1.3 with P-384 ECDHE. The handshake key exchange is the main quantum vulnerability, and P-384 provides the longest runway until PQ TLS is mature.

**FIPS mode:**

| Platform | FIPS Mode |
| -------- | --------- |
| OpenSSL | `OPENSSL_FIPS=1` or FIPS provider |
| Go | Build with `GOEXPERIMENT=boringcrypto` |
| AWS | Use FIPS endpoints (suffix `-fips`) |
| Azure | Azure Government with FIPS 140-2 validated modules |

**Certificate requirements:**

- Minimum 384-bit EC keys (P-384) or 3072-bit RSA
- SHA-384 or SHA-512 for signatures
- Maximum certificate lifetime: 1 year for server certs
- CA certificates: P-384 EC, 10-year max for root
- Must include CRL Distribution Points and OCSP responder

### Compliance Checklist

Before claiming CNSA 2.0 compliance:

- [ ] TLS 1.3 only (no 1.2 fallback for NSS)
- [ ] AES-256-GCM for all symmetric encryption
- [ ] SHA-384 minimum for all hashing
- [ ] P-384 ECDSA for certificates (transitioning to ML-DSA)
- [ ] Hybrid PQ key exchange where available
- [ ] FIPS 140-2/140-3 validated modules
- [ ] No deprecated algorithms (RSA key exchange, CBC, SHA-1, etc.)
- [ ] Certificate pinning disabled (allows algorithm agility)
- [ ] Audit logging of all cryptographic operations

### When to Upgrade from prod to highsec

| Trigger | Action |
| ------- | ------ |
| Contract requires CNSA/FIPS | Implement highsec |
| Handling classified data | Implement highsec |
| Customer is US federal agency | Verify requirements, likely highsec |
| Customer is Five Eyes defence | Verify requirements, likely highsec |
| "We might sell to government" | Stay at prod, it's close enough to upgrade later |
| Data retention > 10 years | Consider highsec for harvest-now-decrypt-later threat |

**The practical reality:** Most federal customers will accept prod (P-384, TLS 1.3, AES-256) for non-classified systems. highsec is primarily for systems that will handle classified data or have explicit CNSA 2.0 contractual requirements.

---

## HyperI Library Integration

The hyperi-pylib and hyperi-rustlib libraries provide TLS helpers that implement these PKI standards with zero-config secure defaults.

### Quick Start

**Python (hyperi-pylib):**

```python
from hyperi_pylib.tls import create_ssl_context

# Uses prod profile by default (P-384, TLS 1.2+)
ctx = create_ssl_context()

# Or explicit profile
ctx = create_ssl_context(profile="prod")      # Production (P-384)
ctx = create_ssl_context(profile="devtest")   # Dev/staging (P-256)
ctx = create_ssl_context(profile="highsec")   # Federal/CNSA 2.0
```

**Rust (hyperi-rustlib):**

```rust
use hyperi_rustlib::tls::{create_tls_config, TlsProfile};

// Uses Prod profile by default (P-384, TLS 1.2+)
let config = create_tls_config(TlsProfile::Prod)?;
```

### Documentation

For implementation details, usage patterns, and configuration options:

- **Python:** See [hyperi-pylib/docs/PKI.md](https://github.com/hypersec-io/hyperi-pylib/blob/main/docs/PKI.md)
- **Rust:** See [hyperi-rustlib/docs/PKI.md](https://github.com/hypersec-io/hyperi-rustlib/blob/main/docs/PKI.md)

### What the Libraries Provide

| Feature | hyperi-pylib | hyperi-rustlib |
| ------- | -------- | ---------- |
| SSL context factory | `create_ssl_context()` | `create_tls_config()` |
| Profile-based config | `profile="prod"` | `TlsProfile::Prod` |
| Database SSL | `build_database_url()` | via settings |
| Kafka mTLS | `get_kafka_ssl_config()` | `KafkaConfig::from_settings()` |
| Config cascade | settings.yaml / env vars | settings.yaml / env vars |

---

## Resources

**Standards and Guidelines:**

- [NSA CNSA 2.0 FAQ](https://media.defense.gov/2022/Sep/07/2003071836/-1/-1/0/CSI_CNSA_2.0_FAQ_.PDF)
- [NIST SP 800-63B - Digital Identity Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [SSL Labs Server Test](https://www.ssllabs.com/ssltest/)

**SSH and Post-Quantum:**

- [OpenSSH Post-Quantum Cryptography](https://www.openssh.org/pq.html)

**Databases:**

- [PostgreSQL SSL Documentation](https://www.postgresql.org/docs/current/ssl-tcp.html)
- [ClickHouse TLS Configuration](https://clickhouse.com/docs/knowledgebase/enabling-ssl-with-lets-encrypt)
- [Kafka mTLS Configuration](https://docs.confluent.io/platform/current/kafka/configure-mds/mutual-tls-auth-rbac.html)

**Secret Management:**

- [OpenBao PKI Secrets Engine](https://openbao.org/docs/secrets/pki/)
- [HashiCorp Vault PKI Engine](https://developer.hashicorp.com/vault/tutorials/pki/pki-engine)

**Infrastructure:**

- [Proxmox Certificate Management](https://pve.proxmox.com/wiki/Certificate_Management)
- [Rancher TLS Configuration](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/resources/add-tls-secrets)
- [cert-manager Documentation](https://cert-manager.io/docs/)

**AWS:**

- [AWS ACM Best Practices](https://docs.aws.amazon.com/acm/latest/userguide/acm-bestpractices.html)
- [AWS Certificate Services Best Practices](https://aws.github.io/aws-security-services-best-practices/guides/certificate-services/)
- [AWS ACM Private CA](https://docs.aws.amazon.com/privateca/latest/userguide/)
