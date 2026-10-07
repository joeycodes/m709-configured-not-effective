# M1 evidence — segmentation and egress

Environment: `canadaeast`, resource group `rg-cne-lab`. Hub NVA `10.100.2.4`
with a public IP and no inbound port open; tier endpoints in `10.101.0.0/16`,
`10.102.0.0/16` and `10.103.0.0/16`, none with a public IP.

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

## Method notes

- Counter readings are differences between two readings, not absolute values.
- `systemctl restart nftables` zeroes every counter: read before restoring.
- `nft reset counters` does nothing to this ruleset, silently; anonymous
  counters are reset by `nft reset rules`.
- The NVA's public IP appears in the files as `<nva-public-ip>`.
- Private addresses are stable across rebuilds by construction, but confirm
  with `terraform output` before re-running a command verbatim.
