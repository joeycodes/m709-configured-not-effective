# ADR-001: The state backend is created manually, outside Terraform

Decision D1. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
Terraform must write state before it can create anything. If the state backend is
itself a Terraform-managed resource, initialisation depends on a resource that
does not yet exist.

Creating it with local state and then migrating the state into itself does work,
but leaves the bootstrap state on one machine, makes `terraform destroy` able to
delete the store holding its own state mid-operation, and cannot be reproduced
from a clean clone.

**Decision**
The resource group, storage account and blob container that hold Terraform state
are created once, by hand, with `az` commands recorded in `docs/BOOTSTRAP.md`.
They are never managed by Terraform.

**Consequences**
- (+) No circular dependency; `terraform destroy` can never destroy its own state store.
- (−) One step of the system is not infrastructure-as-code.
- The bootstrap is irreducible, so it is instead minimised (three commands),
  executed once, and documented here in full.
