# ADR-021: Telemetry for the two mandatory scenarios: native tables, Sentinel from week 8

**Status:** Accepted; partly built (flow logs, NVA log, Activity Log); DNS deferred to M3 week 9, see Amendment
**Date:** 2026-10-17
**Milestone:** M2 (week 7)

Decision D21. Index of all decisions: [README.md](README.md).

---

**Context**
M3's floor is scenarios #1 (lateral movement tier 2 → tier 0) and #4 (DNS
tunnelling), detected by three rules planned for week 8: (a) an accepted flow
from tier 2 to tier 0, (b) a flow reaching tier 0 with no matching NVA record,
and (c) DNS query entropy, length and rate. The workspace from D17,
`log-cne-observability`, already receives the subscription's Activity Log. The
rest of the telemetry has to be chosen.

**Decision**
- **Collect only what those detections need.**

  | Source | Table | Serves |
  |---|---|---|
  | VNet flow logs with Traffic Analytics, 10-minute interval | `NTANetAnalytics` | (a), (b) |
  | NVA nftables log rules → rsyslog → Azure Monitor Agent and a DCR | `Syslog` | (b), and that the NVA drop fires |
  | DNS security policy linked to the tier VNets | `DNSQueryLogs` | (c) |
  | Activity Log (D17) | `AzureActivity` | control-plane changes, such as the drift in evidence Q1 |

- **DNS is logged by a DNS security policy, not by a resolver on the NVA.** The
  VMs keep resolving through Azure DNS, and the policy logs those queries with
  named columns (`QueryName`, `SourceIpAddress`, `ResponseCode`). A resolver on
  the NVA would add a single point of failure and free-text logs to parse, and
  it could be bypassed: queries to `168.63.129.16` are platform traffic that the
  user-defined routes do not steer, so a VM can reach Azure DNS directly unless
  an NSG rule prevents it. DNS sent to an outside resolver crosses the NVA on
  the default route and is covered by the flow logs and the NVA log.
- **Microsoft Sentinel, on the D17 workspace, enabled when week 8 starts.**
  Sentinel stores nothing of its own; it queries the workspace's tables. Its
  31-day trial waives ingestion up to 10 GB/day and counts from the day it is
  enabled, so it is started when detections are written rather than when data
  starts to flow. Until then each source is verified in the workspace with KQL.
  The workspace's daily quota stays as the cost bound after the trial.
- **Detections query the native tables directly.** No ASIM parsers are written.
  `NTANetAnalytics` has one in ASIM's network-session schema; `DNSQueryLogs` has
  none in its DNS schema.

**Consequences**
- (+) Three of the four sources are Azure-native tables with documented,
  fixed columns; only the NVA log needs parsing.
- (−) Flow-based detections cannot fire before Traffic Analytics has processed
  the flow, up to its 10-minute interval. That delay is a floor on MTTD for (a)
  and (b) and is stated in the M3 pre-registration.
- (−) NVA log lines arrive as free text in `SyslogMessage` and are parsed at
  query time. A change to a log prefix breaks the parse; the one-query-per-source
  check in the telemetry inventory is what makes that visible.
- (−) Detection (c) is bound to `DNSQueryLogs`; with no ASIM parser, it does not
  carry over to another DNS source unchanged.
- (−) The trial ends during M3. After that, ingestion is billed per GB; the lab's
  volume is small and capped by the daily quota.
- To confirm before building: DNS security policy pricing (the price page lists
  no figures), availability in `canadaeast`, support in the azurerm provider,
  and whether a traffic rule is needed for queries to be logged.

**Alternatives considered**
- *Resolver on the NVA* (unbound or dnsmasq, query log to syslog) — see Decision.
- *Log Analytics scheduled-query alerts without Sentinel* — workable and
  cheaper, but without incidents, entities or the investigation view that the
  M3 matrix uses as evidence.
- *ASIM normalisation* — the route to one detection over many sources; not
  needed for one source per signal.
- *Suricata on the NVA* — moved to the optional list; neither mandatory
  scenario depends on it.

**Verification**
The week-7 telemetry inventory: for each source, one KQL query that returns
rows from the lab, recorded as evidence.

**Amendment (2026-10-26): DNS moves to M3, week 9**
- The DNS source and detection (c) are deferred from M2 to M3 week 9. M2 closes
  on rules (a) and (b), whose sources are built and verified (evidence R1, R2,
  R4). (c) must be in place before scenario #4 runs in week 10.
- Checked: `dnsResolverPolicies` is offered in `canadaeast`
  (`az provider show -n Microsoft.Network`, 2026-10-26). Its logs go to
  `DNSQueryLogs`, resource type `microsoft.network/dnsresolverpolicies`, with
  `QueryName`, `SourceIpAddress`, `VirtualNetworkId` and
  `ResolverPolicyRuleAction` among the columns. One policy per VNet; policy and
  VNet in the same region.
- Still open: no DNS resolver policy resource was found in the azurerm provider
  docs, so azapi is expected; the price page lists no figure; whether a traffic
  rule is needed for queries to be logged.
