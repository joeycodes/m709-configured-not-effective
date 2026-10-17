# ADR-018: Egress through the NVA; a persistent tier-2 → tier-0 deny

Decision D18. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
After D15 the tiers were segmented from each other but each still reached the
internet directly through Azure's default route, outside any inspection.
TECHNICAL-DESIGN.md requires the hub to be the only path to the internet. The
tier-2 → tier-0 deny also existed only as a rule inserted by hand during a test
(evidence D1–D4), lost at every rebuild.

**Decision**
- **One egress point.** The NVA has a Standard static public IP. Each tier route
  table gains `0.0.0.0/0 → 10.100.2.4`. The NVA masquerades traffic from
  `10.100.0.0/14` to non-RFC 1918 destinations only, so tier-to-tier traffic,
  and later traffic to on-premises, keeps its real source address.
- **Persistent segmentation in the NVA ruleset.** Tier-2 → tier-0 is dropped by
  a rule in `cloud-init-nva.yaml`, placed after `ct state established`. The rule
  is loaded at boot, before any flow exists, so there is nothing for an earlier
  position to sever; placed later, it refuses new flows only.
- **A second layer at the destination.** Tier-0's NSG also denies inbound from
  tier-2.
- **Hub NSG.** One rule allows inbound from `10.100.0.0/14` to any destination,
  because forwarded packets bound for the internet carry a destination outside
  the `VirtualNetwork` tag. Nothing is opened to the internet.

**Consequences**
- (+) Every packet a tier sends beyond its own VNet crosses one host, where it
  can be counted and, later, inspected.
- (−) The NVA is a single point of failure for egress and for tier-to-tier
  traffic alike.
- (−) The NSG rule on tier-0 depends on the NVA preserving source addresses. A
  masquerade rule without the destination restriction rewrites every forwarded
  source to `10.100.2.4`; the NSG rule then never matches and looks unchanged.
  The first draft of this change had exactly that rule.
- (−) Tier-0 is not yet restricted as designed. TECHNICAL-DESIGN.md gives it
  default-deny egress and, as the tier for the most sensitive services, inbound
  from named sources and ports only. As built, tier-0 has the same egress as the
  other tiers and accepts any flow from tier-1. Tightening it, together with
  narrowing tier-1 and tier-2 egress, is deferred to M3 so that the base
  architecture (on-premises, IPsec, BGP) is completed first. Until then the only
  claim made about tier-0's isolation is the one tested: tier-2 cannot open a
  flow to it.
- (−) Whether run-command still works on a VM with no egress at all is unknown
  and will be the first check when tier-0 is closed.
- `CKV_AZURE_119` (no public IP on a network interface) is accepted inline on the
  hub NIC: the address is the egress point and will be the IPsec endpoint.
- The `hub_public_ip` output is marked sensitive so that it is not printed in
  public workflow logs.

**Alternatives considered**
- *Azure NAT Gateway or Azure Firewall* — managed and billed by the hour; the
  design reserves managed services for validation windows.
- *Deny placed before the stateful accept* — also drops replies, which blocks
  both directions with a rule that reads as one.
- *Segmentation in NSGs only* — no per-rule packet accounting, which the
  evidence in D4 and H relies on.

**Verification**
Evidence in `docs/evidence/m1/`, G1–G5 and H1–H3: the default route, the
management path, the egress address, the inbound refusal, and the directional
deny with its counter.
