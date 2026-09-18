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
  description = "Azure region. Constrained to five regions by a subscription-scoped policy; westus is the closest permitted one (ADR D2)."
  default     = "westus"
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
