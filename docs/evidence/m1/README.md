# M1 evidence — east-west segmentation

Environment: `canadaeast`, resource group `rg-cne-lab`, 2026-09-23.
Topology: hub NVA `10.100.2.4` (`Standard_D2s_v6`), tier endpoints in
`10.101.0.0/16`, `10.102.0.0/16`, `10.103.0.0/16` (`Standard_D2ls_v6`).
All observations were taken through `az vm run-command invoke`; no virtual
machine has a public IP or an inbound management port (ADR D14).

These readings were taken against the ruleset as deployed on 2026-09-23, before
counters were added to the two `ct state` rules in `cloud-init-nva.yaml` in this
same change. A re-run after the next rebuild will report higher packet counts for
identical traffic, because packets that previously matched an uncounted rule are
now counted. Every comparison recorded below is zero against non-zero, or a
difference between two readings, and none of them depends on the absolute value.

## Assertions

| ID | Assertion | Expected | Observed | File |
|----|-----------|----------|----------|------|
| A1 | The NVA is configured as intended at both layers | `cloud-init status: done`, `nft` present and active, `net.ipv4.ip_forward = 1`, forward chain loaded | all four hold; counters at zero | `A1-nva-cloudinit-nft-sysctl.txt` |
| B1 | The route table redirects tier-to-tier traffic only | `10.100.0.0/14` → `VirtualAppliance` `10.100.2.4` (source `User`); own VNet and hub keep their system routes | holds; `10.103.0.0/16` stays `VnetLocal`, `10.100.0.0/16` stays `VNetPeering` | `B1-effective-routes-tier2.txt` |
| C1 | tier-2 reaches tier-0, and the path is through the NVA | reachable; one TTL decrement; first hop `10.100.2.4` | 3/3 received, `ttl=63`, `tracepath` hop 1 `10.100.2.4`, hop 2 the target | `C1-tier2-to-tier0-ping-tracepath.txt` |
| C2 | The traffic is accounted for on the NVA, not merely reachable | forward-chain accept counter rises from zero | observed at 2 packets, raw output not retained — see *Gaps* | — |
| D1 | A deny rule can be placed ahead of the stateful accept | rule at the head of the chain, before `ct state established` | inserted as handle 14, first in chain | `D1-t4-rule-inserted.txt` |
| D2 | The NVA denies tier-2 → tier-0 while the rule is present | no reply | 3 transmitted, 0 received, 100% loss, `exit=1` | `D2-t4-tier2-blocked.txt` |
| D3 | The denial is directed, not a loss of forwarding | tier-1 → tier-0 unaffected | 3/3 received, `exit=0` | `D3-t4-tier1-unaffected.txt` |
| D4 | The denial is attributable to that rule, and is reversible | drop counter accounts for exactly the denied packets; ruleset returns to the file-defined state | drop 3 packets / 252 bytes (= 3 × 84, the ICMP echo requests); accept 6 packets; after `systemctl restart nftables` the rule is gone and counters are zero | `D4-t4-counters-and-restore.txt` |
| E  | Forwarding requires both the fabric and the kernel | with `ip_forwarding_enabled` false on the NVA NIC, tier-2 → tier-0 fails | fails (3 transmitted, 0 received, `exit=1`) while the NVA reports `net.ipv4.ip_forward = 1` and its accept counter advances 0 → 3 packets / 252 bytes; restored, the same test returns 3/3 | `E1-t5-ipforward-disabled.txt`, `E2-t5-restored.txt` |
| F  | The deployed environment matches the configuration | `apply` reports no remaining difference | `No changes` — but see below: the drift had already been undone by hand in E2, so this shows convergence, not reclamation | `F1-apply-after-drift.txt` |

## What the numbers mean

D4 is the test that carries the argument. `ping` failing shows only that
something stopped the traffic. The drop counter reading 3 packets / 252 bytes
identifies *what* stopped it and *where*: 84 bytes is a 56-byte ICMP payload
plus its 8-byte header and a 20-byte IP header, so the count is exactly the
three echo requests tier-2 sent, dropped in the NVA's forward chain. D3 rules
out the alternative explanation that forwarding broke in general.

E separates the two independent switches that both have to be on, and it did not
behave as predicted. The expectation written before the run was that the NVA's
counters would stay at zero, on the assumption that the fabric refuses the
packets on the way in. The measurement says otherwise: with `ip_forwarding_enabled`
false, the accept counter still advanced by exactly the three echo requests
(252 bytes = 3 × 84). The packets reach the NVA, the kernel routes them, nftables
accepts them, and the fabric discards them on the way out — a NIC without IP
forwarding may not emit a packet whose source address is not its own.

The consequence is worth more than the prediction would have been. Every check
available on the NVA reports success: `net.ipv4.ip_forward = 1`, the ruleset is
intact, and the forward chain's counter shows the traffic being accepted and
forwarded. Nothing arrives. Host-level packet accounting, the measurement this
project relies on elsewhere, gives the wrong answer for this failure, because the
discard happens in the fabric, outside the operating system's view and without a
local log. An operator on the NVA sees a correct configuration and concludes the
problem is elsewhere.

This is also a caution about the method: the counters are evidence of what the
host did, not of what was delivered. Where delivery is the claim, it has to be
observed at the destination.

## Gaps

- **C2 was not retained.** The counter was read as 2 packets during the run but
  the raw output was not captured. Re-run C1 and capture the counter read in the
  same sequence before treating C2 as evidence.
- **The counters under-report.** `ct state established,related accept` and
  `ct state invalid drop` carry no counter, so the accept counter records the
  first packet of each new flow rather than every forwarded packet — which is
  why D3's six-packet exchange advanced it by one. The comparisons above are
  zero-versus-non-zero and are unaffected, but any absolute packet count taken
  from this ruleset is wrong. Counters are to be added to both `ct` rules in
  `cloud-init-nva.yaml`.
- **Counters reset on reload.** `systemctl restart nftables` returns the ruleset
  to the file and zeroes every counter, so a reading has to be taken before the
  restore step, not after.
- **A reset that resets nothing.** `nft reset counters` acts on named counter
  objects; this ruleset uses anonymous counters inside rules, which are reset by
  `nft reset rules`. The first command succeeds, reports no error and changes
  nothing. C2 was read as a before/after pair for that reason, and a difference
  is in any case a stronger measurement than an absolute value, because it does
  not assume the baseline was zero.
- **Drift reclamation is not demonstrated.** F was run after the NIC had already
  been restored by hand at the end of E, so `apply` had nothing to correct and
  reported `No changes`. That establishes that the deployed environment matches
  the configuration and that a repeated `apply` is a no-op, which is worth
  having, but it is a weaker claim than the one the assertion was written for.
  The test that demonstrates reclamation leaves the change in place — disable
  `ip_forwarding_enabled` on the NIC, run `apply` without restoring it by hand,
  and confirm the property is set back — and is the form to use next time.
- **Rule order is untested.** The deny rule was placed ahead of the stateful
  accept, so it also severed the flow established earlier. Placed after it, the
  same rule would leave existing connections running while appearing identical
  in `nft list ruleset`. That case belongs in M3.

## Reproducing

Each file records the command that produced it. The lab is rebuilt from
`infra/envs/lab` and destroyed nightly, so addresses are stable by construction
(`10.100.2.4` is static; endpoint addresses are the first available in each
subnet) but a rebuild should be confirmed with `terraform output` before the
commands are re-run verbatim.
