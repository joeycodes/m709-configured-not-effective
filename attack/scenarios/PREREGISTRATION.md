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
| ATT&CK | T1552.005 Unsecured Credentials: Cloud Instance Metadata API (tactic: Credential Access, TA0006) |
| Preconditions | Lab deployed based on repo `main`, assertion passed; vm-cne-hub (NVA) is running and has a system-assigned managed identity; The identity has no RBAC role assignment; The attacker already has command execution on vm-cne-hub (assume-breach) |
| Procedure | Baseline (identity has no role): The assume-breach endpoint on the NVA hub attempts to obtain a token through IMDS API address and call ARM (GET resources); expected it refused (no role).  Misconfigured (identity granted Reader): grant the identity Reader on rg-cne-lab; obtain a token again and call ARM; expect it to succeed. |
| Expected control | Network controls do not apply (IMDS is local, 169.254.169.254). The only control is RBAC: whether the stolen token can act depends on the identity’s role. In baseline the identity has no role, so RBAC blocks any API call. |
| Expected signal | No signal: The IMDS call leaves no log (local to the VM). The token's use for a GET (read) does not write to AzureActivity, which records only control-plane writes. So neither stealing the token nor using it to read is visible. |
| Prevented means | Baseline: the stolen token cannot act, the GET is refused (403), because the identity has no role. Misconfigured: the token acts; the GET succeeds |
| Detected means | No detected means. There is no signal to build one on: the token theft is invisible, and the read produces no AzureActivity record. So there is no path to detection in this scenario. |
| Expected outcome | Baseline: Prevented: token theft cannot be prevented (IMDS is local and always issues one), but the RBAC config prevents any further information gathering through the ARM API. Detected: No. Neither the token request nor the local IMDS call is logged, so the activity cannot be detected. Misconfigured: Prevented: token theft is equally unpreventable; this time the RBAC configuration allows information gathering within a limited scope (rg-cne-lab). Detected: No. It is equally undetectable (a read writes nothing to AzureActivity). |
