# Control-effectiveness matrix

One row per scenario. Columns as in [TECHNICAL-DESIGN §8](../docs/TECHNICAL-DESIGN.md). "Prevented", "detected" and MTTD are judged by the definitions in each scenario's [pre-registration](../attack/scenarios/PREREGISTRATION.md).

| # | Scenario | ATT&CK | Expected control | Prevented? (initial) | Detected? (initial) | MTTD | Remediation | Prevented? (post) | Detected? (post) | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Lateral movement, tier 2 → tier 0 | T1021.004 | NVA drop (fwd-t2t0-drop) | Yes | No | N/A | N/A | N/A | N/A | EV-M3-04 |
| 3 | Routing misconfiguration bypasses the NVA | T1562.007 | Routing forces tier 1 → tier 0 through the NVA (/14 UDR) | No | Timing-dependent [1] | ~44 min | RBAC: operator → Reader; detection (b) fixed (time-proximity join) | Yes | Yes | EV-M3-06 |
| 4 | DNS tunnelling exfiltration | T1071.004, T1048 | None (egress control does not cover DNS) | No | Yes | ~14 min | N/A | N/A | N/A | EV-M3-05 |
| 6 | Credential abuse through the instance metadata service | T1552.005 | Least privilege (RBAC): the identity has no role | No [1] | No | N/A | Remove the SP from the NVA hub VM | Yes | No | EV-M3-07 |

## Notes

**#3**

- [1] Deviates from the pre-registered "Detected: Yes". Sentinel raised incidents (19–25 plus a 22:15 alert), but the deployed rule run by hand returned nothing: its leftanti join matches the three-tuple over all history, and a normal tier1→tier0 SSH leaves fwd-accept lines that mask the bypass. The result depends on query timing and window. See EV-M3-06 (e); EV-M2-17's Amendment.

**#6**

- [1] "Initial" is the misconfigured variant (the identity is granted Reader): the stolen token then reads the resource group (GET 200), so the least-privilege control is not effective while a role is attached. In the baseline (no role) the same token is refused (403). Remediation removes the service principal entirely, so no token can be issued at all (GET 401, token_len 0). Detected is "No" throughout: a token request and a read write nothing to AzureActivity. See EV-M3-07.
