# ADR-015: Compute capacity revised after the subscription offer change

Decision D15. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

> Supersedes D3.

**Context**
D3 treated `Total Regional vCPUs` as the single binding limit on the topology.
Deploying the first virtual machines showed that to be incomplete. `terraform
apply` failed for all four with `SkuNotAvailable`, and `az vm list-skus`
reported `NotAvailableForSubscription` for both `Standard_B1s` and
`Standard_B2ls_v2` in all five regions the location policy permits (D2).

Three independent gates must all pass before an instance can be created:

1. **SKU availability** — whether the subscription may allocate that size in
   that region at all.
2. **Family quota** — `Standard <family> Family vCPUs`.
3. **Regional total** — `Total Regional vCPUs`, evaluated in addition to the
   family quota.

Only the second and third appear in `az vm list-usage`, and the two listings
disagree in both directions: families with a quota above zero were unavailable,
while D and F v6/v7 sizes listed as available had no quota entry at all. A size
is deployable only where the two listings agree.

The subscription was then upgraded from Azure for Students to pay-as-you-go
(`quotaId` `PayAsYouGo_2014-09-01`, `spendingLimit` `Off`). The two gates moved
independently:

- **Quota rose without a request.** `Total Regional vCPUs` 6 to 10, `Standard BS
  Family` 4 to 10, and the D, E and F v6/v7 families gained entries at 10.
- **SKU availability did not change.** x86 burstable (`BS`, `Bsv2`, `Basv2`)
  remains unavailable, as does every generation from v1 to v5. Available are
  current-generation `D` v6/v7 and `F` v6/v7, and all Arm64 sizes.

Availability is not a property of a size. It is a property of the pair (size,
region) for this subscription, and the two listings disagree in four distinct
ways across the regions examined:

| Case | Where |
|------|-------|
| SKU unavailable, quota present | `Standard_B1s`, every region examined |
| SKU available, family quota absent | `Basv2`, `Bsv2` in `canadaeast` |
| Family quota present, SKU not offered at all | `Fasv7` in both Canadian regions |
| SKU available, no published price | `Standard_D2als_v6` in `canadaeast` |

Generation is a good predictor but not the rule: `canadacentral` refuses every
size examined, current generation included, while `canadaeast` allows both
current-generation `D` sizes and the x86 burstable families that `westus`
refuses. `Standard_B1s` is separately announced for retirement on 15 November
2028, which is consistent with subscriptions being steered away from it
everywhere.

The practical consequence is that a size cannot be chosen and then placed. The
region and the size are one decision, and it has to be made from the
intersection of two listings that are each incomplete.

D3 attributed the two rejected quota-increase requests to the absence of a
support plan. That was wrong: the offer type was the cause. After the upgrade
the quota rose with no request submitted, and increases became self-service.

**Decision**
The lab moves to `canadaeast` and is re-sized onto current-generation `Dsv6` and
`Dlsv6`, the two families that are simultaneously available, in quota and priced
there:

| Role                                                 | Size                | vCPU | RAM   | CAD/hour |
|------------------------------------------------------|---------------------|------|-------|----------|
| Hub NVA (StrongSwan + FRR + nftables + Suricata)     | `Standard_D2s_v6`   | 2    | 8 GiB | 0.1552   |
| Tier-0 endpoint                                      | `Standard_D2ls_v6`  | 2    | 4 GiB | 0.1354   |
| Tier-1 endpoint                                      | `Standard_D2ls_v6`  | 2    | 4 GiB | 0.1354   |
| Tier-2 endpoint                                      | `Standard_D2ls_v6`  | 2    | 4 GiB | 0.1354   |
| Simulated on-premises edge router (FRR + StrongSwan) | `Standard_D2ls_v6`  | 2    | 4 GiB | 0.1354   |
| **Total**                                            |                     | **10 of 25** | | **0.697** |

Family usage: `Dsv6` 2/15, `Dlsv6` 8/10. Prices are the Linux pay-as-you-go
retail rates for `canadaeast`, read from the retail price API on 2026-09-23.

Both `Total Regional vCPUs` (10 to 25) and `Dsv6` (10 to 15) were raised by
self-service request, granted within minutes and without a support plan — the
mechanism D3 recorded as unavailable.

Both sizes are expressed as Terraform variables (`nva_vm_size`,
`endpoint_vm_size`) rather than literals. This change is the reason: the value
depends on an external constraint that moves without notice and is invisible to
the configuration, so it belongs where a change to it is a reviewable one-line
diff.

**Consequences**
- (+) Fifteen vCPU of headroom remain, enough to separate inspection onto its own
  instance. D3 recorded that no instance could be added without removing another;
  that is no longer true.
- (+) Both families are current generation, on no announced retirement path, x86
  and generation 2, so one image serves every role and cloud-init is unchanged.
  `Dsv6` and `Dlsv6` accept every managed disk type, so the OS disks stay
  `Standard_LRS`.
- (+) The NVA gains memory over the size D3 chose (8 GiB against 4 GiB), which
  matters once Suricata runs on it, and each endpoint gains 4 GiB against the
  1 GiB of a `B1s`.
- (−) Neither family has a local temporary disk, so anything that assumes one is
  present has to be written to the OS disk or to a data disk added later.
- (−) The hub still terminates the tunnel, runs BGP, filters and inspects on one
  instance — but the headroom to separate inspection now exists. From here that
  consolidation is a deliberate choice to match a common deployment shape, not a
  capacity constraint. D3's framing of it as forced no longer holds.
- (−) Compute is now billed rather than drawn from a credit: CAD 0.697 per hour
  with all five instances running, against CAD 0.111 for the Arm64 sizes priced
  in `westus`. The topology is not cheap per hour and hours are the only lever,
  so the controls that bound spend are the nightly teardown and the budget
  alerts, not the SKU choice.
- Availability was established from a listing, not from a deployment. The listing
  is itself a claim; the decision is confirmed only when an apply creates these
  instances.

**Alternatives considered**
- *Arm64* is consistently the cheapest option where it is priced at all
  (`B2pls_v2` at USD 0.040/hour, `B2pts_v2` at USD 0.010/hour in `westus`), and
  the endpoints do not care about instruction set — they generate and receive
  traffic. It was rejected for `canadaeast` because the Arm64 `D2pls_v6` returns
  no price there, and adopting it would mean a second image for a saving that
  cannot be quantified in the region actually being used.
- *A second subscription* — superseded. Upgrading this subscription in place kept
  the subscription ID, the federated credential, the role assignments, the state
  backend and the location policy of D2, so nothing had to be migrated.
- *Staying in `westus` on Arm64* (`B2pls_v2` for the NVA, `B2pts_v2` for the
  endpoints) was the plan until `canadaeast` was probed. It is cheaper by a
  factor of five, but every size in that family is 2 vCPU with 1 GiB of memory
  at the low end, and it requires Arm64 images throughout. `canadaeast` keeps
  the lab on one architecture and, incidentally, in Canada — a consequence of
  the choice rather than a reason for it.

**Thesis note**
None of the three gates is visible to the configuration, to `terraform plan`, or
to the policy gate. Both checks passed on a topology that could not be deployed
at all, in any permitted region. The failure surfaced only at apply, from the
Azure control plane. Before *configured does not mean effective* there is a
plainer step: configured does not mean deployable.
