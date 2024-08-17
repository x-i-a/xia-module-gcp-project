locals {
  landscape = yamldecode(file(var.landscape_file))
  settings = lookup(local.landscape, "settings", {})
  cosmos_org = local.settings["cosmos_org"]
  cosmos_name = local.settings["cosmos_name"]
  cosmos_bucket = lookup(local.settings, "cosmos_bucket", local.cosmos_name)
  cosmos_project = local.settings["cosmos_project"]
  structure = local.landscape["structure"]
  github_owner = lookup(local.settings, "github_owner", "")
}

locals {
  level_0_foundations = {
    for foundation, foundation_details in lookup(local.structure, "foundations", {}) : foundation => {
      name = foundation
      parent = "root"
      repository = lookup(foundation_details == null ?  {} : foundation_details, "repository", "foundation-${foundation}")
    }
  }

  level_1_realms = {
    for realm, details in lookup(local.structure, "realms", {}) : realm => {
      name = realm
      parent = "root"
    }
  }

  level_1_foundations = {
    for idx, pair in flatten([
      for realm, details in lookup(local.structure, "realms", {}) : [
        for foundation, foundation_details in lookup(details, "foundations", {}) : {
          realm = realm
          foundation = foundation
          repository = lookup(foundation_details == null ?  {} : foundation_details, "repository", "foundation-${foundation}")
        }
      ]
    ]) : "${pair.realm}/${pair.foundation}" => {
      parent = pair.realm
      name = pair.foundation
      repository = pair.repository
    }
  }

  level_2_realms = {
    for idx, pair in flatten([
      for realm, details in lookup(local.structure, "realms", {}) : [
        for sub_realm, sub_details in lookup(details, "realms", {}) : {
          realm = realm
          sub_realm = sub_realm
        }
      ]
    ]) : "${pair.realm}/${pair.sub_realm}" => {
      parent = pair.realm
      name = pair.sub_realm
    }
  }

  level_2_foundations = {
    for idx, pair in flatten([
      for realm, details in lookup(local.structure, "realms", {}) : [
        for sub_realm, sub_details in lookup(details, "realms", {}) : [
          for foundation, foundation_details in lookup(sub_details, "foundations", {}) : {
            realm = realm
            sub_realm = sub_realm
            foundation = foundation
            repository = lookup(foundation_details == null ?  {} : foundation_details, "repository", "foundation-${foundation}")
          }
        ]
      ]
    ]) : "${pair.realm}/${pair.sub_realm}/${pair.foundation}" => {
      parent = "${pair.realm}/${pair.sub_realm}"
      name = pair.foundation
      repository = pair.repository
    }
  }

  level_3_realms = {
    for idx, pair in flatten([
      for realm, details in lookup(local.structure, "realms", {}) : [
        for sub_realm, sub_details in lookup(details, "realms", {}) : [
          for bis_realm, bis_details in lookup(sub_details, "realms", {}) : {
            realm = realm
            sub_realm = sub_realm
            bis_realm = bis_realm
          }
        ]
      ]
    ]) : "${pair.realm}/${pair.sub_realm}/${pair.bis_realm}" => {
      parent = "${pair.realm}/${pair.sub_realm}"
      name = pair.bis_realm
    }
  }

  level_3_foundations = {
    for idx, pair in flatten([
      for realm, details in lookup(local.structure, "realms", {}) : [
        for sub_realm, sub_details in lookup(details, "realms", {}) : [
          for bis_realm, bis_details in lookup(sub_details, "realms", {}) : [
            for foundation, foundation_details in lookup(bis_details, "foundations", {}) : {
              realm = realm
              sub_realm = sub_realm
              bis_realm = bis_realm
              foundation = foundation
              repository = lookup(foundation_details == null ?  {} : foundation_details, "repository", "foundation-${foundation}")
            }
          ]
        ]
      ]
    ]) : "${pair.realm}/${pair.sub_realm}/${pair.bis_realm}/${pair.foundation}" => {
      parent = "${pair.realm}/${pair.sub_realm}/${pair.bis_realm}"
      name = pair.foundation
      repository = pair.repository
    }
  }

  all_realms = merge(local.level_1_realms, local.level_2_realms, local.level_3_realms)
  all_foundations = merge(local.level_0_foundations, local.level_1_foundations, local.level_2_foundations, local.level_3_foundations)
}
