# Telemetry inventory

What the observability workspace (`log-cne-observability`, `rg-cne-observability`) receives, how long it keeps it, and what each source can and cannot prove. Decisions are in [ADR D21](adr/ADR-021-telemetry.md); each row was verified with a query against the lab, not assumed from configuration (evidence in [`evidence/m2`](evidence/m2)).

Workspace: Analytics plan, retention 90 days (`log_retention_days`), daily ingestion cap 1 GB (`daily_quota_gb`), local (shared-key) auth disabled. Microsoft Sentinel is enabled on it.

| Source | Path | Table | Retention | Latency seen | Verified |
|---|---|---|---|---|---|
| Activity Log (subscription) | diagnostic setting (`activity-log.tf`) | `AzureActivity` | 90 d | minutes | EV-M2-10 (f), EV-M2-13 (d) |
| VNet flow logs, all five VNets | flow log per VNet → `sacneflowlogs` (raw) → Traffic Analytics, 10-min interval | `NTANetAnalytics` | 90 d (raw blobs: 30 d) | ~14 min | EV-M2-10, EV-M2-13 (e), EV-M2-16 |
| NVA nftables | kernel log → rsyslog → Azure Monitor Agent (NVA's managed identity) → DCR `dcr-cne-nva-syslog` (facility `kern`, Warning and above) | `Syslog` | 90 d | < 1 min | EV-M2-11, EV-M2-14 |
| Sentinel detections | analytics rules in `infra/detections/`, deployed by `detections.tf` | `SecurityAlert`, `SecurityIncident` | 90 d | rule schedule + ~5 min | EV-M2-16 |
| DNS queries (planned, M3 week 9) | DNS security policy linked to the tier VNets | `DNSQueryLogs` | 90 d | — | not built |

The flow-log table is `NTANetAnalytics` (current Traffic Analytics schema for VNet flow logs), not the legacy `AzureNetworkAnalytics_CL`; detections are written against it.

## What each source can prove

**`AzureActivity`.** Who changed what in the control plane, and when: an NSG rule's access flipped (EV-M2-16), a subnet detached from its route table (EV-M2-09), storage-account and workspace keys read (EV-M2-10 (f)). It says nothing about traffic, and nothing about changes inside a VM.

**`NTANetAnalytics`.** Every connection at every NIC it crosses (tier out, NVA in, NVA out, tier in), with the NSG decision and the rule that made it (`AclRule`), per 10-minute interval. Only a row at the destination NIC shows that a packet arrived; rows on the way say Allowed even when the NVA drops the packet later (EV-M2-13 (e), EV-M2-16 (e)). Recorded outside the VMs, so root on a VM cannot remove it.

**`Syslog` (NVA).** What the NVA itself did with forwarded traffic: `fwd-accept:` once per accepted new connection, `fwd-t2t0-drop:` per packet dropped by the tier-2 to tier-0 rule, `fwd-drop:` per packet dropped by the default. Joined with `NTANetAnalytics`, it shows whether a connection that reached tier 0 was inspected (detection (b)).

**`SecurityAlert` / `SecurityIncident`.** That a rule fired, on which query window, and the incident it produced.

## What they cannot prove (known limits)

- **No payload.** Flow logs and nftables see addresses, ports and verdicts; nothing at the application layer.
- **ICMP not seen in `NTANetAnalytics`.** A tier-1 to tier-0 ping left no row; tests use TCP (EV-M2-16).
- **Flow-based detection is late.** ~14 minutes from connection to row; the T2→T0 incident came 25 min 44 s after the connection (EV-M2-16 (g)).
- **No topology.** `FlowType` was `Unknown` for every flow; `NTATopologyDetails` never appeared (EV-M2-10 (g5)). Detections select on addresses and NICs, not on flow type.
- **Processing is not guaranteed by configuration.** On 2026-10-20 Traffic Analytics was correctly configured and wrote nothing; on 2026-10-26 the same configuration worked (EV-M2-10). Each source is checked by query, not by its configuration.
- **The NVA log reflects the NVA's running ruleset.** Traffic accepted by a rule without `log` leaves no line, and Terraform does not see runtime ruleset changes (EV-M2-16 (h)). Root on the NVA can stop logging altogether; the flow logs then still record the traffic.
- **The NVA log misses what does not cross its forward chain:** traffic inside one VNet, and the NVA's own connections.
- **Defender's default incident view filters by priority score 15–100.** Both T2→T0 incidents scored 2 and were hidden until the filter was removed (EV-M2-16 (g)).
