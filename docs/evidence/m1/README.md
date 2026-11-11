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
| EV-M1-01 | The NVA is configured from code: cloud-init complete, nftables active, kernel forwarding on |
| EV-M1-20 | The NVA rebuilds with the intended ruleset |
| EV-M1-19 | A tier's routes send everything beyond its own VNet to the NVA |
| EV-M1-18 | The run-command management path survives the default route |
| EV-M1-05 to EV-M1-07 | Every forwarded packet is accounted for on the NVA |
| EV-M1-23 to EV-M1-25 | The deny for tier-2 → tier-0 is persistent, directional and attributable to one rule |
| EV-M1-21 | Tier egress leaves through the NVA |
| EV-M1-22 | Inbound from the internet is refused, by configuration and in effect |
| E | Forwarding requires both the fabric and the kernel |
| EV-M1-15 to EV-M1-17 | A change made outside the configuration is detected and reverted by `apply` |
| EV-M1-26 | The on-premises server reaches the internet through the on-premises gateway |
| EV-M1-27 | Before the tunnel exists there is no path between on-premises and Azure |
| EV-M1-29 | The IPsec tunnel establishes on the NAT-T port at both ends |
| EV-M1-30 | Data crosses the tunnel in both directions, and the two ends account for it identically |
| EV-M1-31 | eBGP is established over the tunnel; each gateway learns only the other's aggregate and installs it in the kernel |
| EV-M1-32 | Without the outbound rules, forwarded traffic leaves the forwarding gateway and is never delivered, each direction at a different gateway; restoring the rules through the pipeline restores delivery |
| EV-M1-33 | Forwarded traffic between the two aggregates is allowed outbound at both gateways' NSGs, and nothing wider |
| EV-M1-34 | The on-premises server and tier-1 reach each other through the tunnel in both directions, seen at every hop |
| EV-M1-35 | `ipsec0` transmit errors do not grow: at most one, at start-up |
| EV-M1-36 | The whole lab builds from main in one run, from no resource group, and is usable in about 4 min 15 s |

The evidence for each ID is in this directory, in the file or files whose name
begins with that ID, for example `EV-M1-22-inbound-from-internet.txt`.

### Earlier readings

Kept because later arguments refer to them; each describes the lab before a
later change and is not re-runnable verbatim.

| ID | Shows | Superseded by |
|----|-------|---------------|
| EV-M1-02 | routes before the default route was added | EV-M1-19 |
| EV-M1-03 | tier-2 → tier-0 through the NVA, before the persistent deny | EV-M1-24 |
| EV-M1-04 | counters before the `ct state` rules carried them | EV-M1-05 to EV-M1-07 |
| EV-M1-08 to EV-M1-11 | a deny inserted at run time, ahead of the stateful accept | EV-M1-23 to EV-M1-25 |
| EV-M1-14 | `apply` after the drift had been undone by hand | EV-M1-15 to EV-M1-17 |
| EV-M1-28 | IKE sent from port 500 to port 4500: accepted by every layer up to the daemon, silently dropped by the kernel | EV-M1-29 |

EV-M1-05 to EV-M1-07 and EV-M1-12 to EV-M1-13 used tier-2 → tier-0 as their test flow, which is now refused; a
re-run uses tier-1 → tier-0.

## Findings

- **A counter attributes; a failed ping does not.** The deny counter accounts
  for exactly the refused packets, which identifies the rule and the host that
  stopped them. (EV-M1-25, EV-M1-11)
- **A rule's position decides its behaviour.** After the stateful accept the
  deny refuses new flows only; ahead of it, the same text blocks both
  directions. The ruleset listing does not distinguish the two. (EV-M1-24, EV-M1-08)
- **Host accounting has a blind spot.** With IP forwarding off on the NIC, every
  check on the NVA reports success and nothing is delivered: the fabric discards
  the packets outside the operating system's view. The prediction made before
  the run was refuted. (EV-M1-12)
- **Drift detection covers that blind spot,** because `plan` compares the
  configuration with what the platform reports. (EV-M1-16)
- **The `VirtualNetwork` tag is per NIC, and it decides forwarded traffic.**
  Traffic forwarded from on-premises left the hub and was dropped silently by
  the hub NIC's default outbound rules, because its source is outside that
  NIC's tag; the reverse direction was dropped the same way at the on-premises
  gateway. Every host-side check passed. Tier-2 → tier-0 had crossed the same
  NIC only because its source is inside the tag. (EV-M1-32, EV-M1-33, EV-M1-34)
- **A failed connection is evidence of a control only if its failure mode
  matches that control and the test path is known.** A VPN client on the test
  workstation answered on the target's behalf and produced two other failure
  modes before the real one was seen. (EV-M1-22)

## Open gaps

- **Tier-0 egress contradicts the design.** TECHNICAL-DESIGN.md gives tier-0
  default-deny egress; the deployed ruleset lets tier-0 reach the internet and
  open flows to other tiers. Found in review, not by a test; deferred to M3
  (ADR D18). (EV-M1-20, EV-M1-24 c)
- **The forward chain is not quiet.** With egress open the tiers generate
  background traffic of unknown purpose, so only counters on rules specific to
  the tested flow can be read exactly. (EV-M1-23, EV-M1-25)
- **The second layer is not exercised.** Tier-0's NSG also denies tier-2, but
  the NVA drops those packets first.
- **EV-M1-18 covers tier-2 only.** It does not show that run-command works on a VM
  with no egress.
- **BGP routes stop at the gateways.** They are in FRR and the kernel on both
  gateways, not in Azure effective routes; the tiers reach on-premises through
  their default route to the NVA. The M1 gate, which asked for effective
  routes, is restated in ADR D19. (EV-M1-31, EV-M1-19)
- **The hub's port-4500 rule reads zero once the tunnel is up.** Its traffic
  matches `ct state established` first, consistent with the tunnel having been
  negotiated before the ruleset was loaded at boot; unconfirmed. (EV-M1-29 c)

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
