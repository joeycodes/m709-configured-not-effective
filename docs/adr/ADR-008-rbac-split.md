# ADR-008: RBAC split across control plane and data plane

Decision D8. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
Azure separates control-plane operations (managing resources, via
`management.azure.com`) from data-plane operations (reading and writing the data
inside them, via the service endpoint). The two use different roles and, in
practice, different access tokens with different audiences.

`Contributor` covers only the control plane. It can delete the storage account but
cannot read a blob in it — and with D7 applied, there is no longer a key-based
route around that. Terraform needs both: control-plane rights to create
infrastructure, and data-plane rights to read, write and lease the state blob.

**Decision**
Two role assignments per principal, at deliberately different scopes:

| Principal            | Role                          | Scope             |
|----------------------|-------------------------------|-------------------|
| CI service principal | `Contributor`                 | Subscription      |
| CI service principal | `Storage Blob Data Contributor` | Storage account |
| Author (user)        | `Owner`                       | Subscription      |
| Author (user)        | `Storage Blob Data Contributor` | Storage account |

**Consequences**
- (+) The broad grant is broad only because creating resource groups requires
  subscription scope; the data-plane grant is confined to a single resource.
- (−) `Contributor` at subscription scope is a large blast radius. It is the
  minimum that permits resource group creation.
- `Storage Blob Data Reader` is insufficient even for `terraform plan`, because
  acquiring the state lock is itself a write.

**Follow-up**
Scope the data-plane assignment to the `tfstate` container rather than the storage
account. Not done at bootstrap because the container did not yet exist when the
role was first required.
