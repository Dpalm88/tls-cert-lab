# TLS Cert Lab

A local PKI lab for practicing TLS certificate lifecycle management, rotation, and mutual TLS (mTLS) authentication using [step-ca](https://smallstep.com/docs/step-ca/) and nginx.

## What this lab covers

- Standing up a two-tier PKI (Root CA + Intermediate CA) with step-ca
- Issuing short-lived X.509 certificates
- Simulating certificate expiry and observing real error output
- Manual and automated certificate rotation
- Configuring nginx to serve TLS
- Implementing mTLS — mutual certificate authentication between client and server

## Why mTLS matters

Standard TLS only authenticates the server — the client verifies the server's certificate but the server doesn't verify the client. mTLS makes authentication mutual: the server also requires the client to present a valid certificate issued by a trusted CA.

This is the foundation of zero trust networking. Instead of relying on network location (VPN, firewall rules), every connection must prove identity via certificate. This pattern is used in:

- Service meshes (Istio, Linkerd) for workload-to-workload auth
- Zero trust platforms (Netskope, Zscaler, BeyondCorp)
- Kubernetes API server authentication
- Internal microservices and API gateways

## Lab structure
```
tls-lab/
├── ca/                  # step-ca PKI (root + intermediate CA)
│   ├── certs/           # CA certificates (public)
│   ├── config/          # CA configuration
│   └── secrets/         # CA private keys (gitignored)
├── certs/               # Issued leaf certificates
│   ├── svc.crt          # Server cert for nginx
│   └── client.crt       # Client cert for mTLS
├── nginx/
│   └── nginx.conf       # nginx TLS + mTLS config
├── scripts/
│   ├── start-ca.sh      # Start the CA
│   ├── issue-cert.sh    # Issue a new leaf cert
│   └── renew-cert.sh    # Renew before expiry
└── launchd/             # macOS automated renewal timer
```

## Setup

### Prerequisites
```bash
brew install step nginx
```

### Start the CA
```bash
export STEPPATH=~/labs/tls-lab/ca
./scripts/start-ca.sh
```

### Bootstrap client trust
```bash
export STEPPATH=~/labs/tls-lab/ca
step ca bootstrap \
  --ca-url https://localhost:9000 \
  --fingerprint 82bb6bce8752b08929186ec0cdfdbb1117f6e48a5a78e0e25d083e84cf99ed9f
```

### Issue a server cert
```bash
./scripts/issue-cert.sh
```

### Start nginx
```bash
nginx -c ~/labs/tls-lab/nginx/nginx.conf
```

## Certificate rotation
```bash
# Renew before expiry
./scripts/renew-cert.sh

# Reload nginx with new cert (zero downtime)
nginx -c ~/labs/tls-lab/nginx/nginx.conf -s reload
```

### What expiry looks like
```
curl: (60) SSL certificate problem: certificate has expired
```

### What successful rotation looks like
```bash
$ curl --cacert ca/certs/root_ca.crt https://localhost:8443
TLS lab is working!
```

## mTLS

### Issue a client cert
```bash
step ca certificate client@lab.local \
  certs/client.crt \
  certs/client.key \
  --ca-url https://localhost:9000 \
  --not-after=5m \
  --force
```

### Without client cert — rejected
```bash
$ curl --cacert ca/certs/root_ca.crt https://localhost:8443
400 No required SSL certificate was sent
```

### With client cert — authenticated
```bash
$ curl --cacert ca/certs/root_ca.crt \
    --cert certs/client.crt \
    --key certs/client.key \
    https://localhost:8443
mTLS working! Client: CN=client@lab.local
```

The server extracts and logs the client identity (`CN=client@lab.local`) from the certificate — no passwords, no tokens, just cryptographic proof of identity.

## Root fingerprint
```
82bb6bce8752b08929186ec0cdfdbb1117f6e48a5a78e0e25d083e84cf99ed9f
```

## Key security notes

- CA private keys are in `ca/secrets/` — gitignored, never commit
- Leaf private keys (`*.key`) are gitignored
- Public certificates (`.crt`) are safe to commit

## TLS Interception with mitmproxy (Netskope-style MITM)

This section extends the lab to demonstrate how SSL inspection works in enterprise SSE platforms like Netskope. mitmproxy acts as a forward proxy, terminating the client's TLS session, inspecting plaintext, and re-encrypting toward the destination — the same two-session MITM architecture Netskope uses in its SWG.

### How it works
```
Client → [TLS Session 1] → mitmproxy → [TLS Session 2] → Destination
                               ↓
                       Inspect plaintext
                       (DLP, threat scan, policy)
```

The proxy presents its own certificate to the client, signed by the mitmproxy CA. The client only trusts this if the mitmproxy CA is deployed to the system trust store — exactly how Netskope requires its CA cert to be deployed via MDM or GPO.

### Prerequisites
```bash
brew install mitmproxy
```

### Start the proxy
```bash
mitmproxy --mode regular --listen-port 8080
```

### Trust the mitmproxy CA
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  ~/.mitmproxy/mitmproxy-ca-cert.pem
```

### Send traffic through the proxy
```bash
curl -x http://localhost:8080 https://httpbin.org/get
```

### What you see in mitmproxy
```
>> GET https://httpbin.org/get HTTP/2.0
   ← 200 application/json 255b 89ms
```

### Without CA trust — what failure looks like
```bash
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

This is the most common SSL inspection failure in production. In Netskope environments the fix is ensuring the Netskope CA cert is deployed to all managed endpoints via MDM (Jamf, Intune) or GPO.

### Netskope parallel

| mitmproxy lab | Netskope production |
|---|---|
| mitmproxy CA cert | Netskope CA cert |
| `security add-trusted-cert` | MDM/GPO cert deployment |
| `--listen-port 8080` | Netskope client steering |
| mitmproxy TUI flow view | SkopeIT traffic telemetry |
| curl error (60) | User reports "site broken with client on" |
