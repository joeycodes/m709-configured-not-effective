# Architecture decision records

Each decision is a file, ADR-NNN, and is referred to by that number (for
example ADR-017). ADR-001 to ADR-020 were first written as sections of
ADR-000-bootstrap.md, which still holds their shared context and the known
limitations L1 to L3.

| No. | Decision | File |
|---|---|---|
| ADR-001 | The state backend is created manually, outside Terraform | [ADR-001-state-backend-manual.md](ADR-001-state-backend-manual.md) |
| ADR-002 | Region: `westus` | [ADR-002-region.md](ADR-002-region.md) |
| ADR-003 | Compute capacity: 6 vCPU, fixed | [ADR-003-compute-capacity.md](ADR-003-compute-capacity.md) |
| ADR-004 | Resource providers registered explicitly | [ADR-004-resource-providers.md](ADR-004-resource-providers.md) |
| ADR-005 | State backend: Azure Blob Storage | [ADR-005-state-backend-blob.md](ADR-005-state-backend-blob.md) |
| ADR-006 | Redundancy `Standard_LRS`, with versioning and soft delete | [ADR-006-state-redundancy.md](ADR-006-state-redundancy.md) |
| ADR-007 | Shared key authentication disabled | [ADR-007-shared-key-disabled.md](ADR-007-shared-key-disabled.md) |
| ADR-008 | RBAC split across control plane and data plane | [ADR-008-rbac-split.md](ADR-008-rbac-split.md) |
| ADR-009 | CI authentication: workload identity federation, no client secret | [ADR-009-ci-workload-identity.md](ADR-009-ci-workload-identity.md) |
| ADR-010 | Federated credential subject: `ref:refs/heads/main` | [ADR-010-federated-credential-subject.md](ADR-010-federated-credential-subject.md) |
| ADR-011 | Manual approval gate deferred | [ADR-011-approval-gate-deferred.md](ADR-011-approval-gate-deferred.md) |
| ADR-012 | Tagging and lifecycle separation | [ADR-012-tagging-lifecycle.md](ADR-012-tagging-lifecycle.md) |
| ADR-013 | Policy gate verified by negative test | [ADR-013-policy-gate-negative-test.md](ADR-013-policy-gate-negative-test.md) |
| ADR-014 | Documented exception: VM extension operations stay enabled | [ADR-014-extension-operations-exception.md](ADR-014-extension-operations-exception.md) |
| ADR-015 | Compute capacity revised after the subscription offer change | [ADR-015-compute-capacity-revised.md](ADR-015-compute-capacity-revised.md) |
| ADR-016 | The region policy was removed by an offer change, not by a decision | [ADR-016-region-policy-removed.md](ADR-016-region-policy-removed.md) |
| ADR-017 | A persistent observability layer, in its own state | [ADR-017-observability-layer.md](ADR-017-observability-layer.md) |
| ADR-018 | Egress through the NVA; a persistent tier-2 → tier-0 deny | [ADR-018-nva-egress.md](ADR-018-nva-egress.md) |
| ADR-019 | The on-premises site: IPsec on the NAT-T port, eBGP, and what the M1 gate can claim | [ADR-019-onprem-site.md](ADR-019-onprem-site.md) |
| ADR-020 | Policy as code: two rule libraries, tested rules, and what a plan can prove | [ADR-020-policy-as-code.md](ADR-020-policy-as-code.md) |
| ADR-021 | Telemetry for the two mandatory scenarios: native tables, Sentinel from week 8 | [ADR-021-telemetry.md](ADR-021-telemetry.md) |
| ADR-023 | M3 scope and method: four mandatory scenarios, pre-registered, Atomic Red Team first | [ADR-023-m3-scope-and-method.md](ADR-023-m3-scope-and-method.md) |
| ADR-024 | The scenario #3 test operator is created by hand, outside CI | [ADR-024-scenario-3-test-operator.md](ADR-024-scenario-3-test-operator.md) |
