# Architecture decision records

Decisions are numbered D1, D2, ... and referred to by number ("ADR D17").
Each decision is a file of its own. D1 to D20 were first written as sections
of ADR-000-bootstrap.md, which still holds their shared context and the known
limitations L1 to L3.

| No. | Decision | File |
|---|---|---|
| D1 | The state backend is created manually, outside Terraform | [ADR-001-state-backend-manual.md](ADR-001-state-backend-manual.md) |
| D2 | Region: `westus` | [ADR-002-region.md](ADR-002-region.md) |
| D3 | Compute capacity: 6 vCPU, fixed | [ADR-003-compute-capacity.md](ADR-003-compute-capacity.md) |
| D4 | Resource providers registered explicitly | [ADR-004-resource-providers.md](ADR-004-resource-providers.md) |
| D5 | State backend: Azure Blob Storage | [ADR-005-state-backend-blob.md](ADR-005-state-backend-blob.md) |
| D6 | Redundancy `Standard_LRS`, with versioning and soft delete | [ADR-006-state-redundancy.md](ADR-006-state-redundancy.md) |
| D7 | Shared key authentication disabled | [ADR-007-shared-key-disabled.md](ADR-007-shared-key-disabled.md) |
| D8 | RBAC split across control plane and data plane | [ADR-008-rbac-split.md](ADR-008-rbac-split.md) |
| D9 | CI authentication: workload identity federation, no client secret | [ADR-009-ci-workload-identity.md](ADR-009-ci-workload-identity.md) |
| D10 | Federated credential subject: `ref:refs/heads/main` | [ADR-010-federated-credential-subject.md](ADR-010-federated-credential-subject.md) |
| D11 | Manual approval gate deferred | [ADR-011-approval-gate-deferred.md](ADR-011-approval-gate-deferred.md) |
| D12 | Tagging and lifecycle separation | [ADR-012-tagging-lifecycle.md](ADR-012-tagging-lifecycle.md) |
| D13 | Policy gate verified by negative test | [ADR-013-policy-gate-negative-test.md](ADR-013-policy-gate-negative-test.md) |
| D14 | Documented exception: VM extension operations stay enabled | [ADR-014-extension-operations-exception.md](ADR-014-extension-operations-exception.md) |
| D15 | Compute capacity revised after the subscription offer change | [ADR-015-compute-capacity-revised.md](ADR-015-compute-capacity-revised.md) |
| D16 | The region policy was removed by an offer change, not by a decision | [ADR-016-region-policy-removed.md](ADR-016-region-policy-removed.md) |
| D17 | A persistent observability layer, in its own state | [ADR-017-observability-layer.md](ADR-017-observability-layer.md) |
| D18 | Egress through the NVA; a persistent tier-2 → tier-0 deny | [ADR-018-nva-egress.md](ADR-018-nva-egress.md) |
| D19 | The on-premises site: IPsec on the NAT-T port, eBGP, and what the M1 gate can claim | [ADR-019-onprem-site.md](ADR-019-onprem-site.md) |
| D20 | Policy as code: two rule libraries, tested rules, and what a plan can prove | [ADR-020-policy-as-code.md](ADR-020-policy-as-code.md) |
| D21 | Telemetry for the two mandatory scenarios: native tables, Sentinel from week 8 | [ADR-021-telemetry.md](ADR-021-telemetry.md) |
