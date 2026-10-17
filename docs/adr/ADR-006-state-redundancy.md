# ADR-006: Redundancy `Standard_LRS`, with versioning and soft delete

Decision D6. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
Redundancy tier and data-protection features defend against different failure
modes. LRS/GRS protect against infrastructure failure — disk, rack, datacentre.
Versioning and soft delete protect against operator error — a corrupted write, an
accidental deletion.

For a state file, the realistic risk is overwhelmingly the second. Losing state
does not lose the resources; it loses the mapping between code and reality, and
recovery means a manual `terraform import` for every object in the topology.

**Decision**
`Standard_LRS`, with blob versioning enabled, blob soft delete at 30 days, and
**container** soft delete at 30 days.

**Consequences**
- (+) Protection is allocated against the likely failure mode rather than the
  dramatic one.
- (−) A full datacentre loss in `westus` would lose the state file. Accepted: the
  lab is rebuildable from code, and the topology is destroyed nightly in any case.
- Container soft delete is configured separately from blob soft delete. Deleting a
  container removes its blobs with it, so blob-level protection alone would not
  cover the more damaging operation.

**Alternatives considered**
- *`Standard_GRS`* — cost difference is negligible at this volume, but geo-redundancy
  addresses a failure mode that is not the operative risk here.
