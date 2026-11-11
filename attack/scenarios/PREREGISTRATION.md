# Pre-registration

Expected control, signal and outcome for each scenario, committed before the scenario's first run. An entry is not edited after a run; a correction is appended under it as a dated amendment, with the reason.

Scenarios as in [TECHNICAL-DESIGN.md](../../docs/TECHNICAL-DESIGN.md); detections in [`infra/detections/`](../../infra/detections); measured detection latency in [EV-M2-16](../../docs/evidence/m2/EV-M2-16-detection-t2-to-t0.txt) and [EV-M2-17](../../docs/evidence/m2/EV-M2-17-detection-t0-without-nva-record.txt).

## #1 Lateral movement, tier 2 → tier 0

| Field | Entry |
|---|---|
| ATT&CK | T1021.004 Remote Services: SSH (tactic: Lateral Movement, TA0008) |
| Preconditions | Lab deployed based on repo `main`; NVA and NSG are deployed within baselines; tier2 is an assume-breach endpoint; rule (a) and (b) were deployed; TA processes the traffic. |
| Procedure | The assume-breach endpoint on tier2 attempts to connect tier0 over SSH through shell |
| Expected control | NVA drops it (fwd-t2t0-drop); the tier-0 NSG (DenyTier2ToTier0) is a second layer, not reached |
| Expected signal | Syslog: fwd-t2t0-drop lines; NTANetAnalytics: tier-2 out and NVA in, no row at the tier-0 NIC; detections (a) and (b) silent |
| Prevented means | Tier 2's TCP connections to tier 0 port 22 fail, and no allowed row at the tier-0 NIC |
| Detected means | A Sentinel incident is created for the attempt; MTTD from the first connection attempt to incident creation |
| Expected outcome | Prevented: Yes, dropped by the NVA (fwd-t2t0-drop) · Detected: No, no rule alerts on a drop; the attempt shows only in Syslog · MTTD: n/a |

## #4 DNS tunnelling exfiltration

| Field | Entry |
|---|---|
| ATT&CK | T1071.004 Application Layer Protocol: DNS (tactic: Command and Control, TA0011) |
| Preconditions | Lab deployed based on repo `main`; NVA and NSG are deployed within baselines that block outbound traffic by default for tier0 (EV-M2-14 (e) to be fixed); tier0 is an assume-breach endpoint sending manifested DNS queries with high entropic domain names; queries to Azure DNS (168.63.129.16) are platform traffic that the UDRs do not steer through the NVA, so the egress rules do not apply to them; DNS security policy and rule (c) are deployed |
| Procedure | The assume-breach endpoint on tier0 attempts to send DNS requests with high entropic domain names. |
| Expected control | No control presented |
| Expected signal | DNSQueryLogs: queries with long, high-entropy labels under one domain, at a rate well above the tier's baseline; detection (c) fires |
| Prevented means | The queries are refused or not resolved upstream (e.g. blocked by the DNS policy) |
| Detected means | A Sentinel incident is created for the attempt; MTTD from the first query to incident creation |
| Expected outcome | Prevented: No, no control presented · Detected: Yes, detection (c) fires · MTTD: ~10 minutes (not yet measured) |

## #3 Routing misconfiguration bypasses the NVA

| Field | Entry |
|---|---|
| ATT&CK | T1562.007 Impair Defenses: Disable or Modify Cloud Firewall (tactic: Defense Evasion, TA0005) |
| Preconditions | Lab deployed based on repo `main`; NVA and UDRs are deployed within baselines that prevent spoke networks from reaching out to each other without the NVA; the baselines leave both nftables `fwd-accept` log at the NVA and its flow log at tier0's NIC when tier1 attempts to access tier0 ;a lab operator account is present and allowed to do configuration changes. |
| Procedure | The lab operator account attempts to create a VNet peering between tier0 and tier1 |
| Expected control | Presented UDRs are meant to force the traffic from tier1 to tier0 through the NVA (10.100.0.0/14). The newly created VNet peering installs a more specific /16 route that wins, so the traffic skips the NVA. |
| Expected signal | NTANetAnalytics: an allowed access log shown at the tier0's NIC from tier1; Syslog: no related fwd-accept log from the NVA for it, so detection (b) fires; AzureActivity: a peering creation execution log captured. |
| Prevented means | tier1 -> tier0 traffic is still visible both in the flow log (an Allowed row at the tier0's NIC) and in the NVA’s Syslog (a matching `fwd-accept` line). Both present means the traffic still crosses the NVA; the peering did not bypass it. |
| Detected means | a Sentinel incident from detection (b), which fires when the tier0's NIC shows an Allowed row with no matching NVA `fwd-accept` line; MTTD from the peering creation to incident creation. |
| Expected outcome | Prevented: No, the peering’s /16 route bypasses the NVA, no control stops it · Detected: Yes, detection (b) fires · MTTD: ~10 minutes (not yet measured) |

## #6 Cloud credential abuse via the instance metadata service

| Field | Entry |
|---|---|
| ATT&CK |  |
| Preconditions |  |
| Procedure |  |
| Expected control |  |
| Expected signal |  |
| Prevented means |  |
| Detected means |  |
| Expected outcome |  |
