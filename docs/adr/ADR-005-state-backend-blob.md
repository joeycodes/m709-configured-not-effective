# ADR-005: State backend: Azure Blob Storage

Decision D5. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
CI runners are ephemeral, so state cannot live on the runner. State must also be
shared between the author's workstation and CI, or the two will diverge into
conflicting records of reality. Concurrent writes must be prevented outright,
since two divergent state files cannot be merged after the fact.

The backend therefore requires three properties: durability beyond a single run,
a single shared copy, and mutual exclusion on write.

**Decision**
Azure Blob Storage via the `azurerm` backend, with `use_azuread_auth = true`.
Locking uses the native blob lease.

**Consequences**
- (+) Reuses the Entra ID identity system already required for deployment;
  no second credential system is introduced.
- (+) Blob lease provides locking before the write, not conflict detection after it.
- (−) The storage account is reachable from the public internet (see D7).

**Alternatives considered**
- *Local state* — fails on ephemeral runners and on any second operator.
- *State committed to Git* — Git has no locking primitive; state contains the IPsec
  pre-shared key in plaintext and Git history is permanent; and CI would need write
  access to `main`, defeating branch protection.
- *Terraform Cloud / HCP* — viable, but introduces a third-party dependency outside
  the system under test.
- *AWS S3* — no reason to add a second cloud account for the bootstrap.
