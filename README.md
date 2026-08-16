# configured-not-effective

**Validating the security posture of a multi-cloud hybrid internetwork by attacking it, not by inspecting it.**

Cloud security controls are usually verified by reviewing their configuration. But a control can be present in the configuration and still be ineffective in practice: a security group that quietly permits every port, a route that skips the firewall, or a permitted DNS path abused for exfiltration. This project builds a trust-tiered hybrid network across Azure and AWS, then proves whether its controls actually hold by running attacks against them and measuring what is caught.

The guiding idea: **configured does not mean effective.**

## Architecture

Three domains (on-premises, Azure, AWS) joined by IPsec + eBGP tunnels through native gateways (Azure VPN Gateway, AWS Transit Gateway). Each cloud runs a hub-and-spoke layout with four VPCs/VNets; routing forces all inter-spoke and outbound traffic through a hub firewall. The restricted tier denies egress by default. Everything is deployed as code and gated in CI.

See [`docs/topology`](docs/) for the full diagram.

## Pipeline

1. **Prevent** — policy-as-code (OPA/Rego, Checkov, tfsec) blocks non-compliant Terraform in CI before it deploys.
2. **Detect** — detection logic authored on native telemetry (Sentinel/KQL, CloudWatch, flow and DNS logs). No third-party SIEM.
3. **Attack** — adversary emulation (CALDERA, Atomic Red Team, stratus-red-team) mapped to MITRE ATT&CK, plus manual technique.
4. **Validate** — for every scenario, record whether the control held and whether the failure was detected; engineer detections for the gaps and re-test until they fire.

The core output is a **before/after control-effectiveness matrix**: each attack scenario, its initial outcome, and its outcome after remediation, backed by log evidence.

## Stack

Terraform · GitHub Actions (OIDC, no long-lived keys) · Open Policy Agent · Azure (VNet, VPN Gateway, Azure Firewall, Sentinel, Network Watcher) · AWS (VPC, Transit Gateway, Network Firewall, GuardDuty, Reachability Analyzer) · VyOS (on-premises edge)

## Status

Work in progress. Academic capstone for the Master of Science in Internetworking (MINT 709), University of Alberta.

## License

MIT
