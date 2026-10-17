# ADR-013: Policy gate verified by negative test

Decision D13. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

Configuring a gate does not demonstrate that it gates. The Checkov check was
therefore exercised against a deliberate violation (PR #5): a storage account
with anonymous blob access, plaintext HTTP and TLS 1.0.

Observed:
- `Terraform plan` passed — the configuration was syntactically deployable
- `Policy / checkov` failed with exit code 1 and multiple CKV2_AZURE findings
- The ruleset marked both checks Required and disabled the merge button

The pull request was closed without merging. Nothing was created in Azure;
what was verified is the process control, not a cloud resource.

This is the same method the project applies to network controls in M3:
introduce a known-bad input, observe whether the control holds, and record
the evidence. Applying it first to the pipeline establishes that the
measurement apparatus itself has been validated.
