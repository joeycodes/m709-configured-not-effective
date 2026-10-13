package terraform.zone_tag

# Resource types exempt from the zone rules.
# A resource group spans every zone, so no single zone value fits it.
# Exempting the type is safer than adding a catch-all value such as
# "shared": that value would also be accepted on a VM or a NIC, and any
# later rule keyed on tier0/tier1/tier2 would then skip that resource.
# A resource group carries no routing or traffic, and Azure does not copy
# its tags to the resources inside it by default, so leaving it without a
# zone weakens no zone-based check.
exempt_types := {"azurerm_resource_group"}

# A resource can carry tags if its planned state has a tags attribute,
# or if the tags are only known after apply (after_unknown). Without the
# second case, a resource whose tags are unknown at plan time would be
# skipped silently instead of being checked.
has_tags(r) if "tags" in object.keys(r.change.after)
has_tags(r) if r.change.after_unknown.tags == true

# A resource is checked if it can carry tags and is not exempt.
checked(r) if {
	r.change.after != null
	not r.type in exempt_types
	has_tags(r)
}

# Every checked resource must carry a zone tag.
deny contains msg if {
	some r in input.resource_changes
	checked(r)
	not r.change.after.tags.zone
	msg := sprintf("%s: missing zone tag", [r.address])
}

allowed := {"tier0", "tier1", "tier2", "hub", "onprem"}

# A zone tag must name one of the allowed zones.
deny contains msg if {
	some r in input.resource_changes
	checked(r)
	zone := r.change.after.tags.zone
	not zone in allowed
	msg := sprintf("%s: zone tag %q is not allowed", [r.address, zone])
}
