---
name: openssl
runtime: r
package: openssl
package_source: CRAN
package_url: https://jeroen.r-universe.dev/openssl
package_version_pinned: ">=2.4.0"
license: MIT
maintainer: "Jeroen Ooms <jeroenooms@gmail.com>"
---

# Skill: openssl

This package provides bindings to OpenSSL libssl and libcrypto. It enables cryptographic operations including RSA, DSA, and EC curve implementations, AES symmetric encryption, and various hash functions.

An agent should use this skill when tasks require digital signatures, certificate verification, symmetric or asymmetric encryption, or the generation of cryptographic keys and hashes.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("openss")`.

## Functions exposed

### `base64_encode`: Encode binary data to a base64 string

**Input**

```json
{ "fn": "base64_encode", "data": { "type": "array", "items": { "type": "integer", "minimum": 0, "maximum": 255 } } }
```

**Output**

```json
{ "ok": true, "fn": "base64_encode", "result": { "type": "string" } }
```

### `bignum`: Convert input to a bignum object for large integer arithmetic

**Input**

```json
{ "fn": "bignum", "x": { "type": "string" }, "hex": { "type": "boolean" } }
```

**Output**

```json
{ "ok": true, "fn": "bignum", "result": { "type": "object" } }
```

### `ec_dh`: Perform Diffie-Hellman key agreement

**Input**

```json
{ "fn": "ec_dh", "key": { "type": "object" }, "pubkey": { "type": "object" } }
```

**Output**

```json
{ "ok": true, "fn": "ec_dh", "result": { "type": "raw" } }
```

### `encrypt_envelope`: Encrypt data using an RSA public key and AES session key

**Input**

```json
{ "fn": "encrypt_envelope", "data": { "type": "array", "items": { "type": "integer", "minimum": 0, "maximum": 255 } }, "pubkey": { "type": "object" } }
```

**Output**

```json
{ "ok": true, "fn": "encrypt_envelope", "result": { "type": "object", "properties": { "data": { "type": "array" }, "iv": { "type": "array" }, "session": { "type": "array" } } } }
```

### `sha256`: Compute the SHA-256 hash of a raw vector

**Input**

```json
{ "fn": "sha256", "data": { "type": "array", "items": { "type": "integer", "minimum": 0, "maximum": 255 } } }
```

**Output**

```json
{ "ok": true, "fn": "sha256", "result": { "type": "raw" } }
```

## When to invoke

- When a task requires converting binary payloads into ASCII strings for transport via Base64.
- When performing large integer calculations that exceed standard 64-bit integer limits.
- When establishing a shared secret between two parties using Elliptic Curve Diffie-Hellman.
- When securing arbitrary sized data payloads using a combination of RSA and AES.
- When verifying the integrity of a file or message using SHA-256 or other cryptographic hash functions.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "base64_encode", "data": [102, 111, 111]}' | Rscript --vanilla skills/openssl/invoke.R
```
