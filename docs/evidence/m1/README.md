# M1 evidence — segmentation, egress and the site-to-site tunnel

Environment: `canadaeast`, resource group `rg-cne-lab`. Hub NVA `10.100.2.4`
with a public IP, open inbound only to UDP 4500 from the on-premises gateway.
Tier endpoints in `10.101.0.0/16`, `10.102.0.0/16` and `10.103.0.0/16`, none
with a public IP. On-premises site in `10.0.0.0/16`, not peered: a gateway
`10.0.0.4` with a public IP and a server in `10.0.1.0/24` routed through it.
The two gateways are joined by an IKEv2 tunnel on UDP 4500, route-based
through `ipsec0` (`169.254.100.1` and `.2`), and run eBGP across it (hub
AS 65010, gateway AS 65020), each advertising its own aggregate.

This page is an index. The commands, outputs and dates are in the files; each
file's header states the assertion it tests. Design intent is in
`docs/TECHNICAL-DESIGN.md`, decisions and their history in `docs/adr/`.

## Assertions

Every assertion below holds in the files cited. What does not hold, or is not
shown, is under *Open gaps*.

| ID | Assertion |
|----|-----------|
| A1 | The NVA is configured from code: cloud-init complete, nftables active, kernel forwarding on |
| G3 | The NVA rebuilds with the intended ruleset |
| G2 | A tier's routes send everything beyond its own VNet to the NVA |
| G1 | The run-command management path survives the default route |
| C3–C5 | Every forwarded packet is accounted for on the NVA |
| H1–H3 | The deny for tier-2 → tier-0 is persistent, directional and attributable to one rule |
| G4 | Tier egress leaves through the NVA |
| G5 | Inbound from the internet is refused, by configuration and in effect |
| E | Forwarding requires both the fabric and the kernel |
| F2–F4 | A change made outside the configuration is detected and reverted by `apply` |
| I1 | The on-premises server reaches the internet through the on-premises gateway |
| I2 | Before the tunnel exists there is no path between on-premises and Azure |
| J2 | The IPsec tunnel establishes on the NAT-T port at both ends |
| J3 | Data crosses the tunnel in both directions, and the two ends account for it identically |
| K1 | eBGP is established over the tunnel; each gateway learns only the other's aggregate and installs it in the kernel |
| K3 | Forwarded traffic between the two aggregates is allowed outbound at both gateways' NSGs, and nothing wider |
| K4 | The on-premises server and tier-1 reach each other through the tunnel in both directions, seen at every hop |

The evidence for each ID is in this directory, in the file or files whose name
begins with that ID, for example `G5-inbound-from-internet.txt`.

### Earlier readings

Kept because later arguments refer to them; each describes the lab before a
later change and is not re-runnable verbatim.

| ID | Shows | Superseded by |
|----|-------|---------------|
| B1 | routes before the default route was added | G2 |
| C1 | tier-2 → tier-0 through the NVA, before the persistent deny | H2 |
| C2 | counters before the `ct state` rules carried them | C3–C5 |
| D1–D4 | a deny inserted at run time, ahead of the stateful accept | H1–H3 |
| F1 | `apply` after the drift had been undone by hand | F2–F4 |
| J1 | IKE sent from port 500 to port 4500: accepted by every layer up to the daemon, silently dropped by the kernel | J2 |

C3–C5 and E used tier-2 → tier-0 as their test flow, which is now refused; a
re-run uses tier-1 → tier-0.

## Findings

- **A counter attributes; a failed ping does not.** The deny counter accounts
  for exactly the refused packets, which identifies the rule and the host that
  stopped them. (H3, D4)
- **A rule's position decides its behaviour.** After the stateful accept the
  deny refuses new flows only; ahead of it, the same text blocks both
  directions. The ruleset listing does not distinguish the two. (H2, D1)
- **Host accounting has a blind spot.** With IP forwarding off on the NIC, every
  check on the NVA reports success and nothing is delivered: the fabric discards
  the packets outside the operating system's view. The prediction made before
  the run was refuted. (E1)
- **Drift detection covers that blind spot,** because `plan` compares the
  configuration with what the platform reports. (F3)
- **A failed connection is evidence of a control only if its failure mode
  matches that control and the test path is known.** A VPN client on the test
  workstation answered on the target's behalf and produced two other failure
  modes before the real one was seen. (G5)

## Open gaps

- **Tier-0 egress contradicts the design.** TECHNICAL-DESIGN.md gives tier-0
  default-deny egress; the deployed ruleset lets tier-0 reach the internet and
  open flows to other tiers. Found in review, not by a test; deferred to M3
  (ADR D18). (G3, H2 c)
- **The forward chain is not quiet.** With egress open the tiers generate
  background traffic of unknown purpose, so only counters on rules specific to
  the tested flow can be read exactly. (H1, H3)
- **The second layer is not exercised.** Tier-0's NSG also denies tier-2, but
  the NVA drops those packets first.
- **G1 covers tier-2 only.** It does not show that run-command works on a VM
  with no egress.
- **`ipsec0` transmit errors are reduced, not shown to be gone.** With
  link-local addressing off, `ipsec0` has no IPv6 address and the hub reads 0
  errors; the gateway reads 1 after about 90 minutes, against 7-8 and growing
  before. Whether that one recurs is not yet read. (J3, K1)
- **BGP routes stop at the gateways.** They are in FRR and the kernel on both
  gateways, not in Azure effective routes; the tiers reach on-premises through
  their default route to the NVA. The schedule's M1 gate asks for effective
  routes. (K1, G2)
- **The hub's port-4500 rule reads zero once the tunnel is up.** Its traffic
  matches `ct state established` first, consistent with the tunnel having been
  negotiated before the ruleset was loaded at boot; unconfirmed. (J2 c)

## Method notes

- Counter readings are differences between two readings, not absolute values.
- `systemctl restart nftables` zeroes every counter: read before restoring.
- `nft reset counters` does nothing to this ruleset, silently; anonymous
  counters are reset by `nft reset rules`.
- Public IPs appear in the files as `<nva-public-ip>` and `<onprem-gw-public-ip>`.
- swanctl prints warnings for optional plugins that are not installed; they are
  omitted from the files.
- Private addresses are stable across rebuilds by construction, but confirm
  with `terraform output` before re-running a command verbatim.
