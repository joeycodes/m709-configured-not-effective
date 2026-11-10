# Control-effectiveness matrix

One row per scenario. Columns as in [TECHNICAL-DESIGN §8](../docs/TECHNICAL-DESIGN.md). "Prevented", "detected" and MTTD are judged by the definitions in each scenario's [pre-registration](../attack/scenarios/PREREGISTRATION.md).

| Scenario | ATT&CK | Expected control | Prevented? (initial) | Detected? (initial) | MTTD | Remediation | Prevented? (post) | Detected? (post) | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| #1 Lateral movement, tier 2 → tier 0 | T1021.004 | NVA drop (fwd-t2t0-drop) | Yes | No | N/A | N/A | N/A | N/A | A1 |
| #3 Routing misconfiguration bypasses the NVA | T1562 | | | | | | | | |
| #4 DNS tunnelling exfiltration | T1071.004, T1048 | None (egress control does not cover DNS) | No | Yes | 13 minutes 58 seconds | N/A | N/A | N/A | A4 |
| #6 Credential abuse through the instance metadata service | T1552.005 | | | | | | | | |
| #9 Internal network discovery from tier 2 (optional) | T1046 | | | | | | | | |

## Notes

<!-- One short note per row where a cell needs context: a deviation from the pre-registration, a platform fault during the run, why a cell is n/a. -->
