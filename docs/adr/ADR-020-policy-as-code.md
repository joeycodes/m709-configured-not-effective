# ADR-020: Policy as code: two rule libraries, tested rules, and what a plan can prove

Decision D20. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
D13 put Checkov in front of every pull request. Checkov's library describes
misconfigurations common to any Azure estate; it knows nothing of this lab's
design. The properties that make the design what it is — which zone a resource
belongs to, that tier 0 has no public address, that the spokes reach each other
and the internet only through the NVA, that the NVA holds the address the
spokes send to — had no check before deployment. M2 week 5 adds one.

**Decision**
- **Two rule libraries, both run before deployment.** Predefined rules stay
  with Checkov, which reads the Terraform source. Rules specific to this
  design are written in Rego and evaluated by conftest against the plan in
  JSON. The post-deployment reachability assertion (W6) is a separate third
  layer, for what neither can see.
- **tfsec is not used.** Its library covers the same class of check as
  Checkov's; a second predefined scanner adds no kind of check the first
  lacks. PROJECT.md, README.md, TECHNICAL-DESIGN.md, SCHEDULE.md and
  BOOTSTRAP.md, which listed it, are corrected in the same change.
- **Rego, against the plan.** A Rego rule is independent of any one scanner and
  is code with its own unit tests. It reads the plan rather than the source
  because the design properties exist only there: zone tags derived from
  `each.key`, one entry per `for_each` instance, and the references Terraform
  resolved between resources.
- **The rules.**

  | Rule | Requirement | Evidence |
  |---|---|---|
  | `zone_tag` | Every resource that can carry tags has a `zone` tag, one of `hub`, `tier0`, `tier1`, `tier2`, `onprem`. Resource groups are exempt. | P1 |
  | `pip_tier0` | No tier-0 NIC has a public IP; no public IP is tagged tier 0. | P2 |
  | `spoke_routes` | Each tier route table sends `0.0.0.0/0` and `10.100.0.0/14` to a VirtualAppliance; its routes reference the hub NIC and nothing else; a next hop known at plan time equals `lab.nva_ip`. | P3 |
  | `nva_ip` | The hub NIC holds `lab.nva_ip` (`10.100.2.4`), statically allocated. | P4 |
  | Checkov `CKV2_AZURE_31` | Every subnet that can take an NSG has one. No Rego rule is written for it. | P5 |

- **The standard is held outside the configuration.** `lab.nva_ip` lives in
  `infra/policy/lab.rego`, so changing the address in the Terraform code does
  not change what the rule expects.
- **Fail closed.** A rule selects resources in its deny body and states the
  requirement in a negated helper, so a resource that cannot be shown
  compliant is denied, not skipped. Every rule has at least one unit test that
  expects a deny.
- **Where it runs.** `conftest verify` in the Policy workflow, with no
  credentials; `conftest test` as a step of the `plan` job. The JSON plan
  carries sensitive values in plain text, so it stays in the runner's temp
  directory and is never uploaded. Both checks are required on `main`.
  conftest is pinned to 0.71.1 and verified by SHA-256.
- **Not checked by conftest:** the observability plan, whose resources belong
  to no network zone.
- **Deferred to W6:** subnet–route table association (rule 3d) and default
  outbound access (rule 5). On a fresh build every ID is unknown at plan time,
  so the association cannot be paired with its subnet; both are observed
  directly in the effective routes, which also show whether the routes take
  effect.

**Consequences**
- (+) Every rule above was shown to fire on a deliberate violation (P1–P5),
  and the gate as a whole on a pull request into `main` (P7).
- (−) **A rule fails silently where it selects.** In P7, one wrong field name
  (`tags` → `tag`) made `spoke_routes` match nothing, and a plan missing a
  spoke route passed the plan check. Only the unit tests that expect a deny
  failed; the merge stayed blocked because they are a required check. Mock
  inputs do not protect against a provider renaming an attribute.
- (−) **A rule depends on the shape of the plan, not only its content.** The
  same absent value is `null` on a fresh build and `""` once the lab is
  deployed. `pip_tier0`, tested only on fresh builds, denied the tier-0 NIC on
  the first deployed-state plan; it now accepts both, and all eight rules
  pass on a plan of either shape (P6, P8).
- (−) **Some rules hold only together.** The spokes' next hop is unknown at
  plan time: `spoke_routes` requires it to reference the hub NIC, and `nva_ip`
  pins that NIC's address.
- (−) **Known gaps.** The zone tag is self-declared; `pip_tier0` sees a public
  IP on the NIC only, not a public load balancer; the Checkov skip on
  `azurerm_subnet.reserved` covers any subnet placed in that block (P5 e); a
  property with no rule is not checked. W6 tests the deployed result
  regardless.

**Alternatives considered**
- *Checkov custom policies* — would tie the design rules to one scanner.
- *conftest in its own job* — the plan would have to be uploaded, and
  artifacts in a public repository are readable by anyone.
- *Azure Policy* — evaluates at deployment, after the pull request; it would
  complement this gate, not replace it.

**Verification**
Evidence P1–P8 in `docs/evidence/m2/`.
