# ADR-019: The on-premises site: IPsec on the NAT-T port, eBGP, and what the M1 gate can claim

Decision D19. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
M1 requires a simulated on-premises site joined to the hub by IPsec, with each
side's prefixes learned by eBGP. TECHNICAL-DESIGN.md placed it in one edge VM
on `10.0.0.0/24`. Building it raised three questions the earlier decisions did
not answer: which ports the tunnel needs on a cloud VM whose public address is
1:1 NAT, how the routing exchange is bounded, and how NSGs treat traffic that
one VM forwards on behalf of another. The schedule's M1 gate also assumed a
managed VPN Gateway in one respect, below.

**Decision**
- **Two subnets on-premises.** `10.0.0.0/16`, not peered: a gateway
  (`10.0.0.4`, public IP, IP forwarding) in `10.0.0.0/24`, and a server in
  `10.0.1.0/24` whose route table sends `10.100.0.0/14` and `0.0.0.0/0` to the
  gateway. A server behind the gateway is what makes the tunnel carry
  forwarded traffic rather than only the gateways' own.
- **IKEv2 on UDP 4500 only.** Each gateway's private address sits behind a 1:1
  NAT, so IKE would move to 4500 after the first exchange in any case.
  `local_port = 4500` and `remote_port = 4500` start it there, and UDP 500 is
  never opened. Each gateway's NSG and nftables accept UDP 4500 from the peer's
  public address only.
- **Route-based tunnel.** Traffic selectors `0.0.0.0/0` on both sides, bound to
  an XFRM interface (`ipsec0`, interface ID 42); routing, not the SA, decides
  what enters the tunnel. `ipsec0` runs at MTU 1400 with link-local addressing
  off.
- **A generated pre-shared key.** `random_password` (48 characters), passed to
  both gateways through cloud-init. It exists in Terraform state and on the two
  gateways, never in the repository, in GitHub, or in logs.
- **eBGP bounded on both sides.** Private ASNs 65010 (hub) and 65020
  (on-premises), peering on the tunnel addresses `169.254.100.1/.2`. Each side
  advertises one aggregate and accepts only the other's, by prefix-list and
  route-map (FRR's `ebgp-requires-policy` refuses to exchange anything without
  them), with `maximum-prefix 10` as a ceiling.
- **A static anchor for each aggregate.** `network 10.100.0.0/14` is advertised
  only if a matching route exists, so the hub carries
  `ip route 10.100.0.0/14 10.100.2.1`, pointing at the fabric gateway. A Null0
  anchor would satisfy BGP and blackhole the spokes on the NVA itself. The
  gateway mirrors this for `10.0.0.0/16`.
- **Outbound NSG rules for forwarded traffic at both gateways.**
  `AllowForwardedFromOnpremOut` on the hub (`10.0.0.0/16 → 10.100.0.0/14`) and
  `AllowForwardedFromAzureOut` on the on-premises gateway (the reverse).
  See the finding under Consequences.
- **The M1 gate is restated.** The schedule asks for BGP-learned routes in
  Azure effective routes. Only a managed gateway or Route Server injects routes
  into the Azure fabric; a self-hosted NVA cannot. The gate is met instead by
  BGP routes in FRR and in the kernel on both gateways (K1), with the tiers
  reaching on-premises through their default route to the NVA (G2, K4). The
  rebuild half of the gate is met by L1.
- **Validation window #1 is dropped.** It would test whether the tunnel design
  holds on the managed VPN Gateway: a connectivity product, not a security
  control. The thesis tests controls. The window is not a success criterion in
  PROJECT.md §8, needs paid resources and its own routing design (a UDR on
  GatewaySubnet to keep inspection in the path), and the schedule is behind.
  Validation window #2 (managed Azure Firewall) tests a control and is not
  affected; it is decided at the 23 November decision point.
- **Suricata moves to M2 week 7.** Its value is the inspection log, which
  belongs with the telemetry layer and the detections built on it.

**Consequences**
- (+) The tunnel needs one inbound port, from one address, on each gateway.
- (+) A mis-advertisement on either side is bounded to one prefix in, one out.
- (+) The whole lab, tunnel and routing included, rebuilds from `main` in one
  run and is usable in about four minutes; the gateways finish cloud-init and
  establish BGP before Terraform has finished creating peerings. (L1)
- (−) **Finding: the `VirtualNetwork` tag is evaluated per NIC, and it governs
  forwarded traffic in both directions.** On-premises → tier-1 reached the hub,
  left its `eth0`, and never arrived. The hub subnet has no route table, so its
  NIC's tag does not include `10.0.0.0/16`; the default `AllowVnetOutBound`
  needs source and destination both inside the tag, and the packet fell to
  `DenyAllOutBound` — silently, after every host-side check had passed. The
  reverse direction failed the same way at the on-premises gateway. Tier-2 →
  tier-0 had worked through the hub NIC only because its source is inside the
  tag. The existing inbound rules had been read as sufficient. (K2–K4)
- (−) An advertised route is not a reachable one. The anchor makes the
  aggregate permanent: the hub advertises `10.100.0.0/14` while any spoke is
  unreachable, and an Established session says nothing about the data path.
  Reachability is shown by K4, not K1.
- (−) Behaviour on tunnel loss is untested. With the routes withdrawn, traffic
  to on-premises should follow the hub's default route and be dropped, since
  the masquerade excludes RFC 1918 destinations and the fabric has no route to
  `10.0.0.0/16`; that is a prediction, not a result. Testing it is on the
  optional list in SCHEDULE.md.
- (−) MSS is not clamped. ICMP at default size passes; TCP across the 1400-byte
  path depends on PMTUD. The experiment is on the optional list in SCHEDULE.md.
- (−) The conclusions hold for a self-hosted tunnel endpoint. Whether they
  transfer to the managed gateway is not tested; stated as a limitation of
  external validity in the report.
- `CKV_AZURE_119` is accepted inline on the gateway NIC, as on the hub (D18).
- **Structure differs from the schedule.** The schedule names
  `modules/network`, `modules/tiers` and `modules/logging`, with the address
  table generated from a `locals` map. As built, the code is split by
  environment rather than by component: `envs/lab` (ephemeral, destroyed
  nightly) and `envs/observability` (persistent, D17), each a root module with
  its own state. The split that matters here is lifecycle, persistent against
  ephemeral (D12), and a directory per state expresses it directly. Child
  modules would make the component boundaries more visible, but each would
  have exactly one caller, so they would add the cost of passing every input
  and output across a module boundary without giving any reuse, in a lab whose
  subject is network security rather than code structure. The `locals` map in
  `network.tf` is the single source of the address plan; the table in
  TECHNICAL-DESIGN.md is maintained from it by hand.

**Alternatives considered**
- *IKE starting on UDP 500* — needs a second port open, and was shown not to
  complete when only one end moved (J1).
- *Policy-based IPsec* — every new prefix would need a new SA; BGP would have
  nothing to decide.
- *Azure Route Server* — puts BGP routes into effective routes, as the original
  gate assumed; billed by the hour, and needed only for the gate's wording.
- *Child modules per component* — see the last consequence.

**Verification**
Evidence in `docs/evidence/m1/`: J1–J3 for the tunnel, K1 for BGP, K2–K4 for
the NSG finding and the data path in both directions, K5 for `ipsec0` after
link-local addressing was turned off, and L1 for the rebuild from `main`.
