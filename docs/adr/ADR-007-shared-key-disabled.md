# ADR-007: Shared key authentication disabled

Decision D7. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
Storage account keys grant unrestricted access to every blob in the account, with
no per-identity attribution, no expiry, and no granularity. They are a shared
password.

They also constitute a privilege-escalation path: a principal holding
`Contributor` on the storage account can call `listKeys`, retrieve the account
key, and obtain full data-plane access without ever being granted a data-plane
role. While shared key access is enabled, control-plane permission is effectively
data-plane permission.

Terraform state additionally contains every resource attribute in plaintext,
including values marked `sensitive` — for this project, the IPsec pre-shared key.

**Decision**
`--allow-shared-key-access false` on the storage account. All access, by the
author and by CI, is via Entra ID. `--allow-blob-public-access false` and
`--min-tls-version TLS1_2` are also set explicitly.

**Consequences**
- (+) The `listKeys` escalation path is closed. `Contributor` no longer implies
  data access.
- (+) "No long-lived secrets" becomes technically enforced rather than a convention.
- (−) Tooling that assumes key-based auth breaks: `az storage` commands require
  `--auth-mode login`, and the portal's storage browser must be switched to
  Entra ID authentication.

**Evidence**
Key-based access now fails with:

    ErrorCode: KeyBasedAuthenticationNotPermitted

Verification covered both directions: that the Entra ID path still works, and that
the key path no longer does. Confirming only the former would not demonstrate the
control.
