# ADR-000: Bootstrap of remote state backend and CI identity

**Status:** Accepted
**Date:** 2026-09-08
**Milestone:** Pre-M1 (bootstrap)

---

## Context

The project deploys all infrastructure through CI. Two things must exist before
that pipeline can run even once: a shared store for Terraform state, and an
identity CI can authenticate as. Neither can be produced by the pipeline itself.
This ADR records how both were created, under what constraints, and which
trade-offs were accepted.

Three constraints shaped every decision below:

1. **Azure for Students subscription.** Region selection is restricted by policy,
   compute quota is capped and not negotiable, and there is no support plan.
2. **No long-lived secrets.** A stated goal of the project is that no reusable
   credential exists anywhere in the deployment chain.
3. **Single operator.** The author owns the subscription and the tenant, so
   separation of duties cannot be technically enforced against himself.

### Guiding principle: staged hardening

Several decisions below defer a control rather than omit it. The bootstrap phase
prioritises a *diagnosable* baseline: the first end-to-end pipeline run already
exercises four independent mechanisms (OIDC exchange, provider auth, the azurerm
backend, and RBAC across two planes), and adding further controls in parallel
would make any failure hard to attribute. Deferred controls are recorded with an
explicit milestone, not as an open intention.

---

## Decisions

The decisions D1 to D20 were first recorded as sections of this file. Each is
now a file of its own, keeping its number; from D21 on, decisions are written
that way from the start. The full index is in [README.md](README.md).

- D1: [The state backend is created manually, outside Terraform](ADR-001-state-backend-manual.md)
- D2: [Region: `westus`](ADR-002-region.md)
- D3: [Compute capacity: 6 vCPU, fixed](ADR-003-compute-capacity.md)
- D4: [Resource providers registered explicitly](ADR-004-resource-providers.md)
- D5: [State backend: Azure Blob Storage](ADR-005-state-backend-blob.md)
- D6: [Redundancy `Standard_LRS`, with versioning and soft delete](ADR-006-state-redundancy.md)
- D7: [Shared key authentication disabled](ADR-007-shared-key-disabled.md)
- D8: [RBAC split across control plane and data plane](ADR-008-rbac-split.md)
- D9: [CI authentication: workload identity federation, no client secret](ADR-009-ci-workload-identity.md)
- D10: [Federated credential subject: `ref:refs/heads/main`](ADR-010-federated-credential-subject.md)
- D11: [Manual approval gate deferred](ADR-011-approval-gate-deferred.md)
- D12: [Tagging and lifecycle separation](ADR-012-tagging-lifecycle.md)
- D13: [Policy gate verified by negative test](ADR-013-policy-gate-negative-test.md)
- D14: [Documented exception: VM extension operations stay enabled](ADR-014-extension-operations-exception.md)
- D15: [Compute capacity revised after the subscription offer change](ADR-015-compute-capacity-revised.md)
- D16: [The region policy was removed by an offer change, not by a decision](ADR-016-region-policy-removed.md)
- D17: [A persistent observability layer, in its own state](ADR-017-observability-layer.md)
- D18: [Egress through the NVA; a persistent tier-2 → tier-0 deny](ADR-018-nva-egress.md)
- D19: [The on-premises site: IPsec on the NAT-T port, eBGP, and what the M1 gate can claim](ADR-019-onprem-site.md)
- D20: [Policy as code: two rule libraries, tested rules, and what a plan can prove](ADR-020-policy-as-code.md)

---

## Known limitations

These are properties of the bootstrap as built, carried forward into the thesis
limitations section.

**L1. Pull request and main share one identity.**
Both federated credentials point at the same service principal, so a token
obtained by a pull-request workflow carries subscription-scoped `Contributor` —
the same permission `apply` uses. Because `terraform plan` executes code from the
pull request, a malicious pull request that obtained a token could modify any
resource in the subscription.

Containing this requires two service principals, not two credentials: permission
is bound to the identity, not to the credential. The pull-request identity would
hold `Reader` at subscription scope, with `Storage Blob Data Contributor` on the
storage account (required because `plan` acquires the state lock), or `Reader`
throughout if `plan` is run with `-lock=false`.

Not implemented during bootstrap. Recorded as a known gap.

**L2. "CI is the only deploy path" is a documented discipline, not a control.**
The author holds `Owner` on the subscription and can apply from a workstation at
any time. The discipline is upheld by a dedicated CI identity, shared remote
state, and routing all infrastructure changes through pull requests — but it is
not technically enforced.

The author is also an administrator of the tenant, so a second, reduced-privilege
account could be created for day-to-day work with the `Owner` account reserved for
emergencies. This was considered and not done.

Separating accounts defends against two things: an attacker who compromises the
everyday account, and one operator making a change that another has not reviewed.
Neither improves materially here. The same person holds both accounts and can
switch between them at will, and the lab is rebuilt from code nightly, so the
damage an unreviewed change can do is bounded by one day.

The limitation is therefore a deliberate choice, not a constraint imposed by the
environment, and is stated as such.

**L3. The state backend is reachable from the public internet.**
GitHub-hosted runners have dynamic egress addresses, so network-level restriction
of the storage account would break CI. Defence rests on the data plane instead:
Entra ID authentication, explicit data-plane RBAC, and shared key access disabled
(D7, D8). Narrowing this would require self-hosted runners or a service-tag-based
rule.

---

## Verification

The bootstrap is considered complete when a pull request produces a `plan`, an
approved merge produces an `apply`, and the resulting state is written to the
remote backend (BOOTSTRAP.md step 6). Until that run succeeds end to end, every
decision above is configured but unproven — the distinction this project exists
to examine.
