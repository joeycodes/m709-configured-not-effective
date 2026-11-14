# Runbook: #6 Credential abuse through the instance metadata service

| | |
|---|---|
| ATT&CK | T1552.005 |
| Pre-registration | [PREREGISTRATION.md](PREREGISTRATION.md#6-cloud-credential-abuse-via-the-instance-metadata-service) |
| Foothold | vm-cne-hub (10.100.2.4), Hub is an assume-breach endpoint |
| Tooling | Manual, through run-command. No Atomic Red Team test for T1552.005 runs on Linux. |

## Preconditions

- [ ] The latest lab deployed based on repo `main` succeeded with assertion passed
- [ ] vm-cne-hub (NVA) is running and has a system-assigned managed identity
- [ ] The identity has no RBAC role assignment
- [ ] The attacker already has command execution on vm-cne-hub

## Steps

| # | Where | Command | Expected |
|---|---|---|---|
| 1 | vm-cne-hub | See below | IMDS token obtained; ARM GET refused (403) |
| 2 | Azure RBAC | See below | Role `Reader` assigned to the SP of the NVA hub VM |
| 3 | vm-cne-hub | See below | IMDS token obtained; ARM GET succeeds (200) |
| 4 | Azure RBAC | See below | Role `Reader` removed; the SP has no role |
| 5 | vm-cne-hub | See below | IMDS token obtained; ARM GET refused (403) |

> Remediation: Remove the managed identity from the NVA (compute.tf identity block). This closes the token endpoint entirely.

### Commands

Step #1, #3 and #5:

```shell
az vm run-command invoke -g rg-cne-lab -n vm-cne-hub --command-id RunShellScript --scripts '
date -u
SUB="<sub-id>"
TOKEN=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" | python3 -c "import sys,json;print(json.load(sys.stdin)[\"access_token\"])")
echo "token_len ${#TOKEN}"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Authorization: Bearer $TOKEN" \
  "https://management.azure.com/subscriptions/$SUB/resourceGroups/rg-cne-lab/resources?api-version=2021-04-01"'
```

Step #2 and #4

```shell
PID=$(az vm show -g rg-cne-lab -n vm-cne-hub --query identity.principalId -o tsv)

# Grant SP of the NVA hub the reader permission (#2) 
az role assignment create --assignee-object-id "$PID" --assignee-principal-type ServicePrincipal \
  --role "Reader" --scope "/subscriptions/$SUB/resourceGroups/rg-cne-lab"

# Delete the reader permission (#4)
az role assignment delete --assignee "$PID" --role "Reader" --scope "/subscriptions/$SUB/resourceGroups/rg-cne-lab"
```



## Signals

| # | Signal | Source / table | Query | Expected | Wait |
|---|---|---|---|---|---|
| 1 | No AzureActivity record for the GET (read) by the SP | AzureActivity | See below | No line for read action; only the role assignment/removal | 10 min |

### Queries

**Signal #1**:

```kql
AzureActivity
| where TimeGenerated > ago(1h)
| where Caller == "<nva-sp-principal-id>"
| project TimeGenerated, OperationNameValue, ActivityStatusValue, Caller
```

## Cleanup

- The Reader role granted in step 2 is removed in step 4; verify the SP has no role

## Evidence

- Log files save to docs/evidence/m3/<number>-scenario-6.txt
  - token_len (not the token itself) and ARM GET status (403 / 200 / 403)
  - AzureActivity query result (no GET read; only the manual role operations)
  - `Reader` role assignment and removal on the NVA's SP
  - **Remediation**: remove the identity from compute.tf (expected)
- Screenshots of GET actions