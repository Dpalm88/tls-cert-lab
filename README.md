# TLS Lab

Local PKI using step-ca for cert rotation practice.

## Start the CA
```
export STEPPATH=~/labs/tls-lab/ca
./scripts/start-ca.sh
```

## Issue a cert
```
./scripts/issue-cert.sh
```

## Renew a cert
```
./scripts/renew-cert.sh
```

## Inspect a cert
```
step certificate inspect certs/svc.crt --short
```

## Root fingerprint
82bb6bce8752b08929186ec0cdfdbb1117f6e48a5a78e0e25d083e84cf99ed9f

## Provisioner password
stored in ca/secrets/ — do not commit
