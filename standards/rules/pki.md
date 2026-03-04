---
paths:
  - "**/certs/**/*"
  - "**/ssl/**/*"
  - "**/pki/**/*"
  - "**/tls/**/*"
---

## Security Profiles

- **Corporate default is `prod`** — use unless you have a specific reason not to
- **prod**: SSH Ed25519, TLS ECDSA P-384, AES-256-GCM, SHA-384, 20-char alphanumeric passwords
- **devtest**: SSH Ed25519, TLS ECDSA P-256, AES-256-GCM, SHA-256, 20-char alphanumeric passwords
- **highsec** (federal/CNSA 2.0): Ed25519+ML-KEM hybrid SSH, P-384→ML-DSA TLS, ML-KEM-1024 key exchange, AES-256, SHA-384/512, ML-DSA-87 signatures

## Non-Negotiable Rules

- TLS 1.2 minimum, TLS 1.3 preferred
- Never use SHA-1, MD5, DES, 3DES, RC4, CBC mode, RSA key exchange, export ciphers, SSLv2/v3, TLS 1.0/1.1
- Private keys never in git
- File permissions: `600` for private keys, `700` for `.ssh/`, `644` for public keys
- Never disable certificate verification (`verify=False`, `ssl.CERT_NONE`, `InsecureSkipVerify: true`)
- PEM is the standard certificate format; use other formats only when required by service
- Use SAN (SubjectAltName) in certs — CN matching is deprecated

## SSH Keys

- Default: `ssh-keygen -t ed25519 -C "user@hyperi.io"`
- Fallback RSA-4096 only when Ed25519 unsupported
- Never use ECDSA for SSH (RNG-dependent signatures leak keys)
- Post-quantum KEX preference: `mlkem768x25519-sha256,sntrup761x25519-sha512,curve25519-sha256`

## TLS Certificates

- **prod**: `openssl ecparam -genkey -name secp384r1 -out server.key` with `-sha384`
- **devtest**: P-256 acceptable
- CA certs: P-384, max 10-year lifetime; server certs max 1 year
- TLS 1.3 cipher priority: `TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256`, `TLS_AES_128_GCM_SHA256`
- TLS 1.2 AEAD only: `ECDHE-ECDSA-AES256-GCM-SHA384`, `ECDHE-RSA-AES256-GCM-SHA384`, `ECDHE-ECDSA-CHACHA20-POLY1305`

## PEM File Naming

- `server.key` / `server.crt` / `ca.crt` / `chain.crt` / `fullchain.crt` / `client.crt` / `client.key`

## Certificate Inspection

```bash
openssl x509 -in cert.crt -text -noout          # View details
openssl x509 -in cert.crt -enddate -noout       # Check expiry
openssl verify -CAfile ca.crt server.crt         # Verify chain
openssl s_client -connect host:443 -showcerts    # Test TLS connection
```

## Format Conversion (only when required)

- PEM→PKCS12: `openssl pkcs12 -export -in cert.crt -inkey cert.key -out cert.p12`
- PKCS12→PEM: `openssl pkcs12 -in cert.p12 -out cert.pem -nodes`
- DER↔PEM: `openssl x509 -inform DER -in cert.der -out cert.pem`

## Database TLS

- **PostgreSQL**: Use `sslmode=verify-full` in production; set `ssl_min_protocol_version = 'TLSv1.2'`
- **ClickHouse**: Enable `tcp_port_secure`/`https_port`, disable insecure ports, set `disableProtocols=sslv2,sslv3,tlsv1,tlsv1_1`

## Kafka/AutoMQ

- Use mTLS (`ssl.client.auth=required`), PKCS12 keystores, `ssl.protocol=TLSv1.3`
- Generate broker keys with P-384: `openssl ecparam -genkey -name secp384r1`

## Passwords

- Default: 20 alphanumeric chars (~119 bits entropy)
- Generate: `openssl rand -base64 30 | tr -dc 'a-zA-Z0-9' | head -c 20`
- Special characters only when system requires them

## Gitignore (mandatory patterns)

```gitignore
*.key
*.pem
!*.pub.pem
*.p12
*.pfx
*.jks
*.keystore
*.csr
.env
.env.*
!.env.example
id_rsa*
id_ed25519*
id_ecdsa*
.vault-token
*.tfstate
*.tfstate.*
```

## Certificate Locations

- **Linux CA trust**: Ubuntu `/usr/local/share/ca-certificates/` + `update-ca-certificates`; Fedora `/etc/pki/ca-trust/source/anchors/` + `update-ca-trust`
- **macOS**: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain myca.crt`
- **Proxmox Web UI**: cert at `/etc/pve/local/pveproxy-ssl.pem`, key at `/etc/pve/local/pveproxy-ssl.key`

## Infrastructure Patterns

- **Proxmox**: Use Terraform ACME provider (DNS-01/Route53) with `key_type = "P384"`, deploy via Ansible — not built-in ACME
- **Rancher/K3s**: Use cert-manager with ClusterIssuer; prefer Let's Encrypt or bring-your-own P-384 certs
- **OpenBao PKI**: Use intermediate CA pattern; set `key_type=ec key_bits=384` on roles
- **Terraform**: Never store private keys in state; use Vault transit engine
- **Ansible cert tasks**: Set `mode: '0600'` on private keys, use `no_log: true` for key deployment

## AWS

- **ACM**: Use DNS validation (auto-renews); don't pin ACM certs (they rotate)
- **ACM Private CA**: Use `EC_secp384r1` with `SHA384WITHECDSA`
- **ALB/NLB**: Use policy `ELBSecurityPolicy-TLS13-1-2-2021-06`
- **S3**: Enforce `aws:SecureTransport` condition in bucket policies

## Language-Specific

- **Python**: Use `ssl.create_default_context(cafile=certifi.where())` with `minimum_version=TLSv1_2`
- **Go**: Default TLS config is secure; never set `InsecureSkipVerify: true`; use SAN not CN
- **Rust**: Use `rustls` with `webpki_roots`
- **C++**: Use OpenSSL 3.x; always call `SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, nullptr)`
- **Node.js**: Set `minVersion: 'TLSv1.2'`, `rejectUnauthorized: true`

## HyperI Libraries

- **Python**: `from hyperi_pylib.tls import create_ssl_context; ctx = create_ssl_context(profile="prod")`
- **Rust**: `let config = create_tls_config(TlsProfile::Prod)?;`
- Libraries provide: SSL context factory, profile-based config, database SSL, Kafka mTLS, config cascade

## Anti-Pattern

```python
# ❌ BAD
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
requests.get(url, verify=False)

# ✅ GOOD
ctx = ssl.create_default_context(cafile=certifi.where())
ctx.minimum_version = ssl.TLSVersion.TLSv1_2
requests.get(url, verify=certifi.where())
```

## CNSA 2.0 / Highsec

- TLS 1.3 only (no 1.2 fallback for NSS)
- FIPS 140-2/140-3 validated modules required
- Hybrid PQ key exchange where available
- Max server cert lifetime: 1 year
- Must include CRL Distribution Points and OCSP responder
- FIPS mode: OpenSSL `OPENSSL_FIPS=1`, Go `GOEXPERIMENT=boringcrypto`, AWS FIPS endpoints
- Trigger: government/defence contracts, classified data, explicit CNSA/FIPS contractual requirements
