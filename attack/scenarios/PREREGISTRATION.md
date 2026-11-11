# Pre-registration

Expected control, signal and outcome for each scenario, committed before the scenario's first run. An entry is not edited after a run; a correction is appended under it as a dated amendment, with the reason.

Scenarios as in [TECHNICAL-DESIGN.md](../../docs/TECHNICAL-DESIGN.md); detections in [`infra/detections/`](../../infra/detections); measured detection latency in [EV-M2-16](../../docs/evidence/m2/EV-M2-16-detection-t2-to-t0.txt) and [EV-M2-17](../../docs/evidence/m2/EV-M2-17-detection-t0-without-nva-record.txt).

## #1 Lateral movement, tier 2 → tier 0

| Field | Entry |
|---|---|
| ATT&CK | T1021.004 Remote Services: SSH (tactic: Lateral Movement, TA0008) |
| Preconditions | lab deployed based on repo `main`; NVA and NSG are deployed within baselines; tier2 is an assume-breach endpoint; rule (a) and (b) were deployed; TA processes the traffic. |
| Procedure | the assume-breach endpoint on tier2 attempts to connect tier0 over SSH through shell |
| Expected control | NVA drops it (fwd-t2t0-drop); the tier-0 NSG (DenyTier2ToTier0) is a second layer, not reached |
| Expected signal | Syslog: fwd-t2t0-drop lines; NTANetAnalytics: tier-2 out and NVA in, no row at the tier-0 NIC; detections (a) and (b) silent |
| Prevented means | tier 2's TCP connections to tier 0 port 22 fail, and no allowed row at the tier-0 NIC |
| Detected means | a Sentinel incident is created for the attempt; MTTD from the first connection attempt to incident creation |
| Expected outcome | Prevented: Yes, dropped by the NVA (fwd-t2t0-drop) · Detected: No, no rule alerts on a drop; the attempt shows only in Syslog · MTTD: n/a |

## #4 DNS tunnelling exfiltration

| Field | Entry |
|---|---|
| ATT&CK | T1071.004 Application Layer Protocol: DNS (tactic: Command and Control, TA0011) |
| Preconditions | lab deployed based on repo `main`; NVA and NSG are deployed within baselines that block outbound traffic by default for tier0 (EV-M2-14 (e) to be fixed); tier0 is an assume-breach endpoint sending manifested DNS queries with high entropic domain names; queries to Azure DNS (168.63.129.16) are platform traffic that the UDRs do not steer through the NVA, so the egress rules do not apply to them; DNS security policy and rule (c) are deployed |
| Procedure | the assume-breach endpoint on tier0 attempts to send DNS requests with high entropic domain names. |
| Expected control | No control presented |
| Expected signal | DNSQueryLogs: queries with long, high-entropy labels under one domain, at a rate well above the tier's baseline; detection (c) fires |
| Prevented means | the queries are refused or not resolved upstream (e.g. blocked by the DNS policy) |
| Detected means | a Sentinel incident is created for the attempt; MTTD from the first query to incident creation |
| Expected outcome | Prevented: No, no control presented · Detected: Yes, detection (c) fires · MTTD: ~10 minutes (not yet measured) |

## #3 Routing misconfiguration bypasses the NVA

To be registered before the first run.

## #6 Cloud credential abuse via the instance metadata service

To be registered before the first run.
