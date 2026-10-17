# ADR-014: Documented exception: VM extension operations stay enabled

Decision D14. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

Checkov `CKV_AZURE_50` requires `allow_extension_operations = false` on every
virtual machine. The check failed on all four VMs in the lab. It is skipped
inline on each resource, with the reason recorded in the code.

No VM in the lab has a public IP, and no inbound management port is opened.
`az vm run-command invoke` is therefore the only management path, and it is
carried out through the VM agent's extension mechanism. Setting the property the
check asks for would remove that path and leave the serial console as the only
way into a VM.

The check's premise is that extensions are an additional attack surface layered
on top of an existing management path. That does not hold here: run-command
replaces SSH rather than supplementing it. Applying the suggested remediation
would raise the compliance score while increasing the risk the check exists to
reduce.

Two properties of the skip matter as much as the decision itself:
- It is declared inline on each resource, not as a global `skip-check` in
  `.checkov.yml`. A virtual machine added later is evaluated again rather than
  inheriting the exception silently.
- `soft-fail` remains off. Every other finding still blocks the merge, so the
  gate verified in D13 is not weakened.

The exception is conditional, not permanent. It holds only while no VM has an
inbound exposure. Giving the hub NVA a public IP for the IPsec tunnel changes
that premise, and this decision is to be revisited in the same change.

The wider point belongs in the thesis. A static policy gate evaluates whether a
property is set, not whether setting it improves security in the architecture it
is set in. Here the two diverge, and the divergence is only visible to a reviewer
who knows how the environment is administered. An exception is therefore only as
sound as the reason attached to it, which is why the reason lives in the code and
the skip is reviewed in the pull request that introduces it.

**Revisited 2026-10-06 (D18).** The NVA now has a public IP. The premise is
restated more exactly: the exception holds while no VM has an inbound
*management* exposure. That is still true — the hub NSG opens nothing to the
internet, verified in evidence G5 — and run-command remains the only management
path, so the exception stands for all four VMs. It is to be revisited again when
UDP 500 and 4500 are opened for IPsec.

**Revisited 2026-10-10 (D19).** Both gateways now accept inbound UDP 4500 from
the peer's public address only; UDP 500 was never opened. No management port is
exposed on any VM, so the exception stands for all six.
