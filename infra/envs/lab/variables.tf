variable "subscription_id" {
  type        = string
  description = "Azure subscription the lab deploys into."

  # Not a secret: a subscription ID grants nothing on its own. Kept in
  # version control so a clean clone deploys to the right place with no
  # local setup.
  default = "23f19e67-5d24-4e37-9258-707daef49af0"
}

variable "location" {
  type        = string
  description = "Azure region. No longer constrained by policy (ADR D16); canadaeast is the region where the required VM sizes are both available and in quota (ADR D15)."
  default     = "canadaeast"
}

variable "project" {
  type        = string
  description = "Project name, applied as a tag to every resource."
  default     = "configured-not-effective"
}

variable "enable_firewall" {
  type        = bool
  description = <<-EOT
    Whether to stand up the managed Azure Firewall.

    Default false. The managed firewall bills by the hour and would consume
    the student credit quickly, so routine work uses the self-hosted
    inspection host instead. This flag exists so a time-boxed validation
    window is a deliberate, reviewable change to a variable rather than an
    accident.

    Not consumed yet -- declared now so the guardrail exists before the
    resource it guards.
  EOT
  default     = false
}

variable "admin_ssh_public_key" {
  type        = string
  description = "Ed25519 public key (the key itself, not a path). Break-glass only; routine access uses run-command."
  validation {
    condition     = startswith(var.admin_ssh_public_key, "ssh-ed25519 ")
    error_message = "must be the contents of an Ed25519 .pub file (starts with 'ssh-ed25519 '), not a path or a private key."
  }
}

# current generations; earlier generations are not available to student subscription
variable "nva_vm_size" {
  type        = string
  description = "Size of the hub NVA VM."
  default     = "Standard_D2s_v6"
}

variable "endpoint_vm_size" {
  type        = string
  description = "Size of the spoke endpoint VMs."
  default     = "Standard_D2ls_v6"
}
