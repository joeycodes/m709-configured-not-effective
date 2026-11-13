# Runbook: #3 Routing misconfiguration bypasses the NVA

| | |
|---|---|
| ATT&CK | T1562.007 |
| Pre-registration | [PREREGISTRATION.md](PREREGISTRATION.md#3-routing-misconfiguration-bypasses-the-nva) |
| Foothold | vm-cne-tier1 (10.102.0.4), Tier1 is an assume-breach endpoint |
| Tooling | Manual, through run-command. No Atomic Red Team test for T1562.007 runs on Linux. |

## Preconditions

- [ ] The latest lab deployed based on repo `main` succeeded with assertion passed
- [ ] NVA and UDRs are deployed within baselines that prevent spoke networks from reaching out to each other without the NVA
- [ ] The nftables `fwd-accept` log at the NVA and its correlated flow log at tier0's NIC can be found when tier1 attempts to access tier0
- [ ] Rule (b) was deployed: Sentinel Analytics contains the enabled rule  
- [ ] A lab operator account is present and allowed to do configuration changes

## Steps

| # | Where | Command | Expected |
|---|---|---|---|
| 1 | Microsoft Entra ID | See below | Operator account created |
| 2 | Azure RBAC | See below | Role `Network Contributor` assigned to the operator account |
| 3 | Tier0 and Tier1 VNets | See below | The peering between tier0 and tier1 VNets created by lab operator and is established |
| 4 | vm-cne-tier1 | See below | TCP connects (no timeout); SSH then fails on auth |

### Commands

Variables:

```shell
# Setting variables before execution
TENANT=<tenant>
OPERATOR="lab.operator@${TENANT}.onmicrosoft.com"
SUB=$(az account show --query id -o tsv)
RG="rg-cne-lab"
VNET_T0="vnet-cne-tier0"
VNET_T1="vnet-cne-tier1"

# Getting resource ID of each VNet, used in Step #3
VNET_T0_ID=$(az network vnet show -g $RG -n $VNET_T0 --query id -o tsv)
VNET_T1_ID=$(az network vnet show -g $RG -n $VNET_T1 --query id -o tsv)
```

Step #1:

```
az ad user create \
  --display-name "Lab Operator" \
  --user-principal-name $OPERATOR \
  --password "<password>" \
  --force-change-password-next-sign-in true
```

Step #2:

```shell
# Getting the user ID after it is created
USER_ID=$(az ad user show --id "$OPERATOR" --query id -o tsv)

az role assignment create \
  --assignee-object-id "$USER_ID" \
  --assignee-principal-type User \
  --role "Network Contributor" \
  --scope "/subscriptions/$SUB/resourceGroups/$RG"
```

Step #3:

```shell
# Tier0 -> Tier1
az network vnet peering create \
  --name tier0-to-tier1 \
  --resource-group $RG \
  --vnet-name $VNET_T0 \
  --remote-vnet $VNET_T1_ID \
  --allow-vnet-access

# Tier1 -> Tier0
az network vnet peering create \
  --name tier1-to-tier0 \
  --resource-group $RG \
  --vnet-name $VNET_T1 \
  --remote-vnet $VNET_T0_ID \
  --allow-vnet-access
```

Step #4:

```shell
az vm run-command invoke -g rg-cne-lab -n vm-cne-tier1 --command-id RunShellScript --scripts 'date -u; ssh -o ConnectTimeout=5 -o BatchMode=yes azureuser@10.101.0.4'
```

## Signals

| # | Signal | Source / table | Query/Command | Expected | Wait |
|---|---|---|---|---|---|
| 1 | Flow log at tier0’s NIC matches the NVA’s nftables log for tier1->tier0 SSH connection | Syslog, NTANetAnalytics | See below | The flow log of tier0's NIC shows inbound SSH requests from tier1 and the NVA’s nftables log shows related entry | 10 min |
| 2   | The peering created by lab operator, and its operation log found in AzureActivity, and it succeeded | AzureActivity, Run-command | See below                                                | The peering successfully established, and operation log exists | 10 min |
| 3   | Flow log at tier0’s NIC doesn't match the NVA’s nftables log for tier1->tier0 SSH connection | Syslog, NTANetAnalytics    | See below                                                | The flow log of tier0's NIC shows inbound SSH requests from tier1 while the NVA’s nftables log shows no related entry | 10 min |
| 4 | Sentinel alarm fires | Defender incidents | Defender -> Incidents, remove the filter: Priority score | Alarm fires | 30min |

### Queries/Commands

**Signal #1**:

```kql
NTANetAnalytics
| where TimeGenerated > ago(30m)
| where SubType == "FlowLog"
| where TargetResourceId endswith "/vnet-cne-tier0"
| where FlowDirection == "Inbound"
| where FlowStatus == "Allowed"
| where ipv4_is_in_any_range(SrcIp, "10.100.0.0/14", "10.0.0.0/16")
| where not(ipv4_is_in_range(SrcIp, "10.101.0.0/16")) and SrcIp != "10.100.2.4"
| project SrcIp, DestIp, DestPort, AllowedInFlows, FlowStartTime, FlowEndTime
| join kind=leftanti (
    Syslog
    | where HostName == "vm-cne-hub"
    | where SyslogMessage has "fwd-accept:"
    | extend SrcIp = extract(@"SRC=(\S+)", 1, SyslogMessage), DestIp = extract(@"DST=(\S+)", 1, SyslogMessage), DestPort = toint(extract(@"DPT=(\d+)", 1, SyslogMessage))
    | project SrcIp, DestIp, DestPort
  ) on SrcIp, DestIp, DestPort
| summarize Count = count(), Flows = sum(AllowedInFlows), FirstSeen = min(FlowStartTime), LastSeen = max(FlowEndTime) by SrcIp, DestIp, DestPort
```

**Signal #2**:

Show the peering operation log by quering table `AzureActivity`:

```kql
AzureActivity
| where TimeGenerated > ago(30m)
| where OperationNameValue == "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write"
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, OperationNameValue, _ResourceId, ActivityStatusValue
```

List the peerings for tier0 and tier1 VNets:

```shell
az network vnet peering list -g $RG --vnet-name $VNET_T1 \
  --query "[].{name:name, state:peeringState, sync:peeringSyncLevel}" -o table
  
az network vnet peering list -g $RG --vnet-name $VNET_T0 \
  --query "[].{name:name, state:peeringState, sync:peeringSyncLevel}" -o table
```

**Signal #3**:

```kql
NTANetAnalytics
| where TimeGenerated > ago(30m)
| where SubType == "FlowLog"
| where TargetResourceId endswith "/vnet-cne-tier0"
| where FlowDirection == "Inbound"
| where FlowStatus == "Allowed"
| where ipv4_is_in_any_range(SrcIp, "10.100.0.0/14", "10.0.0.0/16")
| where not(ipv4_is_in_range(SrcIp, "10.101.0.0/16")) and SrcIp != "10.100.2.4"
| project SrcIp, DestIp, DestPort, AllowedInFlows, FlowStartTime, FlowEndTime
| join kind=leftanti (
    Syslog
    | where HostName == "vm-cne-hub"
    | where SyslogMessage has "fwd-accept:"
    | extend SrcIp = extract(@"SRC=(\S+)", 1, SyslogMessage), DestIp = extract(@"DST=(\S+)", 1, SyslogMessage), DestPort = toint(extract(@"DPT=(\d+)", 1, SyslogMessage))
    | project SrcIp, DestIp, DestPort
  ) on SrcIp, DestIp, DestPort
| summarize Count = count(), Flows = sum(AllowedInFlows), FirstSeen = min(FlowStartTime), LastSeen = max(FlowEndTime) by SrcIp, DestIp, DestPort
```

## Cleanup

Delete the two peerings by using commands:

```
  az network vnet peering delete -g rg-cne-lab --vnet-name vnet-cne-tier0 -n tier0-to-tier1
  az network vnet peering delete -g rg-cne-lab --vnet-name vnet-cne-tier1 -n tier1-to-tier0
```

After the re-run that follows the remediation, and after the final run, delete the test user (ADR-024). The role assignment is removed with it.

```shell
az ad user delete --id "$OPERATOR"
```



## Evidence

- Log files save to docs/evidence/m3/<number>-scenario-3.txt
  - Peering creation log (AzureActivity)
  - The flow log of tier0's NIC
  - The SSH request log not found in the NVA's nftables log
  - Sentinel alarm (b) fires
- Calculated MTTD
- Screenshots of Defender incidents