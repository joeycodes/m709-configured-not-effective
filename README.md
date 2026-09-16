# configured-not-effective

**Validating the security posture of a hybrid cloud internetwork by attacking it, not by inspecting it.**

Cloud security controls are usually verified by reviewing their configuration. But a control can be present in the configuration and still be ineffective in practice: a security group that quietly permits every port, a route that skips the firewall, or a permitted DNS path abused for exfiltration. This project builds a trust-tiered hybrid internetwork across a simulated on-premises site and Microsoft Azure, then proves whether its controls actually hold by running attacks against them and measuring what is caught.

The guiding idea: **configured does not mean effective.**

## Architecture

Two domains — a simulated on-premises site and Azure — joined by an IPsec tunnel running eBGP. On-premises is a single edge router (FRRouting + StrongSwan) standing in for a customer edge device. Azure is a hub-and-spoke of four virtual networks: a hub carrying the tunnel endpoint and the firewall, and three spokes as trust tiers (restricted, application, low-trust). Routing forces all inter-spoke and outbound traffic through the hub firewall; the restricted tier denies egress by default. Everything is deployed as code and gated in CI.

See [`docs/diagrams`](docs/diagrams) for the topology and [`docs/TECHNICAL-DESIGN.md`](docs/TECHNICAL-DESIGN.md) for the full design.

## Pipeline

1. **Prevent** — policy-as-code (OPA/Rego, Checkov, tfsec) blocks non-compliant Terraform in CI before it deploys.
2. **Detect** — detection logic authored on Azure-native telemetry (Sentinel/KQL, flow logs, firewall and DNS logs). No third-party SIEM.
3. **Attack** — adversary emulation (CALDERA, Atomic Red Team, stratus-red-team) mapped to MITRE ATT&CK, plus manual technique, under an assume-breach model.
4. **Validate** — for every scenario, record whether the control held and whether the failure was detected; engineer detections for the gaps and re-test until they fire.

The core output is a **before/after control-effectiveness matrix**: each attack scenario, its initial outcome, and its outcome after remediation, backed by log evidence.

## Scope

The baseline is deliberately **one cloud**. Depth of adversarial validation is the contribution here, not provider count — a second cloud would multiply the build effort without strengthening the central claim. Address space is reserved for a second provider (`10.200.0.0/14`) and the design would mirror across, but AWS and a Kubernetes tier are explicit non-goals of the baseline and will only be attempted if the schedule allows. Application-layer penetration testing is out of scope: there is no production application, and this is an assume-breach test of network controls.

## Stack

Terraform · GitHub Actions (OIDC, no long-lived keys) · Open Policy Agent · Azure (VNet, VPN Gateway, Azure Firewall, Microsoft Sentinel, Network Watcher) · FRRouting + StrongSwan (on-premises edge)

## Status

Work in progress. Academic capstone for the Master of Science in Internetworking (MINT 709), University of Alberta. Schedule in [`docs/SCHEDULE.md`](docs/SCHEDULE.md).

## License

MIT
