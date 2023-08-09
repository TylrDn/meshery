package meshmodel_policy

import data.meshmodel_policy.extract_components
import data.meshmodel_policy.contains
import data.meshmodel_policy.get_array_pos
import future.keywords.in

binding_types := ["mount", "permission"]

binding_relationship[results] {
    binding_type := binding_types[_]

    binding_comps := { type |
        selector := data[binding_type].selectors.allow.from[_].match
        selector[key]
        key != "self"
        type = key
    }

    some comp in binding_comps
    
    result = evaluate with data.selectors as data[binding_type].selectors with data.binding_comp as comp
    results = {binding_type: result}
}

evaluate[results] {

    from_selectors := { kind: selectors |
        s := data.selectors.allow.from[_]
        kind := s.kind
        selectors := s
    }

    to_selectors :=  { kind: selectors |
        t := data.selectors.allow.to[_]
        kind := t.kind
        selectors := t
    }

    # contains "selectors.from" components only, eg: Role/ClusterRole(s) comps only
    from := extract_components(input.services, from_selectors)
    to := extract_components(input.services, to_selectors)

    binding_resources := extract_components(input.services, [{"kind": data.binding_comp}])

    services_map := { service.traits.meshmap.id: service |
        service := input.services[_]
    }
    some i, j, k
        resource := from[i]
            binding_resource := binding_resources[j]

        r := is_related(resource, binding_resource, from_selectors[resource.type])
        r == true  
            to_resource := to[k]
            q := is_related(to_resource, binding_resource, to_selectors[to_resource.type])
            q == true

    results = {
        "from": {
            "id": resource.traits.meshmap.id
        },
        "to": {
            "id": to_resource.traits.meshmap.id
        },
        "binded_by": {
            "id": binding_resource.traits.meshmap.id
        }
    }
}

is_related(resource1, resource2, from_selectors) {
    some i
    match_from := from_selectors.match.self[i]
    match_to := from_selectors.match[data.binding_comp][i]
    ans := is_feasible(match_from, match_to, resource1, resource2) 
} 

is_feasible(from, to, resource1, resource2) {
    not contains(to, "_")
    object.get(resource1, from, "") == object.get(resource2, to, "")
}

is_feasible(from, to, resource1, resource2) {
    match(from, to, resource1, resource2)    
}

is_feasible(from, to, resource1, resource2) {
    match(to, from, resource2, resource1)    
}

match(from, to, resource1, resource2) {
    contains(to, "_")

    index := get_array_pos(to)
    prefix_path := array.slice(to, 0, index)
    suffix_path := array.slice(to, index + 1, count(to))

    resource_val := object.get(resource2, prefix_path, "")
    value := [val |
        v := resource_val[_]
        val := object.get(v, suffix_path, "")
    ]

    some i in value 
     i == object.get(resource1, from, "")
}