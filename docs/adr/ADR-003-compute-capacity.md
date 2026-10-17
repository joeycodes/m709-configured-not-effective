# ADR-003: Compute capacity: 6 vCPU, fixed

Decision D3. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

> Superseded by D15. The vCPU cap was not the binding limit, and the
> attribution of the rejected quota requests below is corrected there.

**Context**
`Total Regional vCPUs` in `westus` is capped at 6. Per-family quotas are higher
(`Standard BS Family` 4; `Bsv2`, `Basv2`, `Bpsv2` 10 each), but the regional total
is evaluated in addition to the family quota, so 6 is the binding limit.

Two quota-increase requests (to 16, then to 10) were submitted and automatically
rejected. Azure for Students has no support plan, so these requests do not reach
human review. The cap is treated as fixed.

**Decision**
The topology is sized to exactly 6 vCPU, exhausting the non-adjustable legacy
`BS` family first and reserving the `Bsv2` allocation for the only role that
needs more than 1 GiB of memory:

| Role                                              | Size       | vCPU | Quota bucket |
|---------------------------------------------------|------------|------|--------------|
| Simulated on-premises edge router (FRR + StrongSwan) | B1s      | 1    | BS 1/4       |
| Hub NVA (StrongSwan + FRR + nftables + Suricata)   | B2ls_v2    | 2    | Bsv2 2/10    |
| Tier-0 endpoint                                    | B1s        | 1    | BS 2/4       |
| Tier-1 endpoint                                    | B1s        | 1    | BS 3/4       |
| Tier-2 endpoint                                    | B1s        | 1    | BS 4/4       |
| **Total**                                          |            | **6**|              |

**Consequences**
- (+) Every role in the design has a dedicated instance; the three trust tiers each
  have an independent endpoint, so segmentation can be tested as designed.
- (−) No spare capacity. Any additional instance requires deallocating another.
- (−) The hub terminates the tunnel, runs BGP, filters and inspects on a single
  NVA, because the 6 vCPU cap leaves no room to separate them. This is a common
  real-world deployment shape, but a compromise of the hub NVA collapses several
  controls at once — which the threat model must account for.
- Managed Azure Firewall and VPN Gateway are PaaS and consume no vCPU quota, so
  the time-boxed managed-service validation windows are unaffected.

**Alternatives considered**
- *Spot instances* (`Total Regional Spot vCPUs` = 3, a separate bucket) would add
  headroom, but eviction during a measurement run would invalidate results.
  Retained as a fallback for non-measurement traffic generators.
- *A second subscription* (pay-as-you-go, reimbursed) has its own quota. Held in
  reserve for managed-service validation windows if the credit proves insufficient.
