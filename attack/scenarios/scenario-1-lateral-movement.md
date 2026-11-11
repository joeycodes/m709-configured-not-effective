# Runbook: #1 Lateral movement, tier 2 → tier 0

| | |
|---|---|
| ATT&CK | T1021.004 |
| Pre-registration | [PREREGISTRATION.md](PREREGISTRATION.md#1-lateral-movement-tier-2--tier-0) |
| Foothold | vm-cne-tier2 (10.103.0.4), Tier2 is an assume-breach endpoint |
| Tooling | Manual, through run-command. No Atomic Red Team test for T1021.004 runs on Linux. (ADR-023 amendment) |

## Preconditions

- [ ] The latest lab deployed based on repo `main` succeeded with assertion passed
- [ ] NVA and NSG are deployed within baselines: forward chain in NVA's nftables contains `fwd-t2t0-drop`; tier0's NSG contains `DenyTier2ToTier0`
- [ ] Rule (a) and (b) were deployed: Sentinel Analytics contains both enabled rules
- [ ] TA processes the traffic: Flow logs exist in `NTANetAnalytics` within the last 30 minutes

## Steps

| # | Where | Command | Expected |
|---|---|---|---|
| 1 | vm-cne-tier2 | az vm run-command invoke -g rg-cne-lab -n vm-cne-tier2 --command-id RunShellScript --scripts 'date -u; ssh -o ConnectTimeout=5 -o BatchMode=yes azureuser@10.101.0.4' | connection timed out |

## Signals

| # | Signal | Source / table | Query | Expected | Wait |
|---|---|---|---|---|---|
| 1 | Outbound records found in tier2's flow log | NTANetAnalytics | See below | Allowed | 10-15min |
| 2 | Inbound records found in hub's flow log | NTANetAnalytics | See below | Allowed | 10-15min |
| 3 | fwd-t2t0-drop logged | Syslog | See below | Dropped | 1-2 min |
| 4 | No records found in tier0's flow log | NTANetAnalytics | See below | No record | 10-15min |
| 5 | No Sentinel alarm | Defender incidents | Defender -> Incidents, remove the filter: Priority score | No alarm | 30min |

### Queries

> Run the queries in the workspace’s Logs.

**Signal #1**:

```kql
  NTANetAnalytics
  | where SubType == "FlowLog"
  | where TargetResourceId endswith "/vnet-cne-tier2"
  | where FlowDirection == "Outbound"
  | where FlowStatus == "Allowed"
  | where ipv4_is_in_range(DestIp, "10.101.0.0/16")
  | where DestPort == 22
  | where TimeGenerated > ago(30m)
  | project FlowStartTime, SrcIp, DestIp, DestPort, L4Protocol, FlowDirection, FlowStatus, AclRule, PacketsSrcToDest, PacketsDestToSrc, TimeGenerated
```

**Signal #2**:

```kql
  NTANetAnalytics
  | where SubType == "FlowLog"
  | where TargetResourceId endswith "/vnet-cne-hub"
  | where FlowDirection == "Inbound"
  | where FlowStatus == "Allowed"
  | where ipv4_is_in_range(SrcIp, "10.103.0.0/16")
  | where ipv4_is_in_range(DestIp, "10.101.0.0/16")
  | where DestPort == 22
  | where TimeGenerated > ago(30m)
  | project FlowStartTime, SrcIp, DestIp, DestPort, L4Protocol, FlowDirection, FlowStatus, AclRule, PacketsSrcToDest, PacketsDestToSrc, TimeGenerated
```

**Signal #3**:

```kql
  Syslog
  | where HostName == "vm-cne-hub"
  | where SyslogMessage has "fwd-t2t0-drop"
  | extend SrcIp = extract(@"SRC=(\S+)", 1, SyslogMessage)
  | extend DestIp = extract(@"DST=(\S+)", 1, SyslogMessage)
  | extend DestPort = toint(extract(@"DPT=(\d+)", 1, SyslogMessage))
  | where ipv4_is_in_range(SrcIp, "10.103.0.0/16")
  | where ipv4_is_in_range(DestIp, "10.101.0.0/16")
  | where DestPort == 22
  | where TimeGenerated > ago(30m)
```

**Signal #4**:

```kql
  NTANetAnalytics
  | where SubType == "FlowLog"
  | where TargetResourceId endswith "/vnet-cne-tier0"
  | where FlowDirection == "Inbound"
  | where FlowStatus == "Allowed"
  | where ipv4_is_in_range(SrcIp, "10.103.0.0/16")
  | where TimeGenerated > ago(30m)
  | project FlowStartTime, SrcIp, DestIp, DestPort, L4Protocol, FlowDirection, FlowStatus, AclRule, PacketsSrcToDest, PacketsDestToSrc, TimeGenerated
```

## Cleanup

None: nothing is changed during the run

## Evidence
- Log files save to docs/evidence/m3/<number>-scenario-1.txt
  - Tier2 outbound logs
  - Hub inbound logs
  - NVA nftables fwd-t2t0-drop logs
  - No records related found in FlowLog associated with tier0
- Screenshots of Defender incidents
