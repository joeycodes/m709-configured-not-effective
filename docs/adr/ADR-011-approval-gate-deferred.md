# ADR-011: Manual approval gate deferred

Decision D11. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
The pipeline's first end-to-end run must validate four independent mechanisms at
once: OIDC token exchange, Terraform provider auth, the azurerm backend, and Azure
RBAC across two planes. Adding an approval gate at the same time would make any
failure harder to attribute.

**Decision**
No GitHub Environment protection rule is configured during bootstrap. `apply` runs
on merge to `main` without a required reviewer.

**Consequences**
- (+) Failures in the first pipeline run are attributable to a single mechanism.
- (−) No human checkpoint exists between merge and apply. **A merge is a deploy.**
- (−) The federated credential subject cannot yet be narrowed to
  `environment:production`, since that form requires the environment to exist.

**Follow-up (M2)**
Create the `production` environment with a required reviewer; then replace the
`gh-main` federated credential with one scoped to `environment:production`.
