# ADR-012: Tagging and lifecycle separation

Decision D12. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
The topology is destroyed nightly to conserve credit. The state backend must
survive that teardown — it is infrastructure *about* the infrastructure, not part
of the lab.

**Decision**
Every resource carries a `layer` tag. `rg-tfstate` and its contents are
`layer=persistent`; everything Terraform creates for the lab is `layer=ephemeral`.
Teardown is bounded by the Terraform state, not by tags. The layer tag is retained
as an independently queryable assertion: any resource tagged layer=ephemeral that
survives a teardown, or that exists in Azure without a corresponding entry in 
state, is by definition drift.

**Consequences**
- (+) The blast radius is defined by the state file. Terraform can only destroy
  what it created, so the persistent layer is structurally out of reach rather
  than merely labelled differently -- a mistyped tag cannot widen it.
- (−) Anything created outside Terraform is invisible to the teardown and will
  accumulate cost. The `layer` tag makes that class findable (compare
  `az resource list --tag layer=ephemeral` against `terraform state list`), but
  finding it and destroying it remain separate actions.
- (−) Tag presence is not yet enforced. An untagged resource does not escape
  teardown, but it does weaken the drift check above. Policy-as-code (M2).
