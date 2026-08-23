.pragma library

function normalized(value) {
  return String(value || "").toLowerCase().trim()
}

function matches(plugin, query, filter) {
  if (!plugin || (plugin.sourceType || "community") !== "community") return false
  if ((filter === "verified" || filter === "unverified")
      && (plugin.repositoryLayout === "suite" || plugin.verificationStatus !== filter)) return false

  var terms = normalized(query).split(/\s+/).filter(function(term) { return term.length > 0 })
  if (terms.length === 0) return true

  var text = normalized([
    plugin.name,
    plugin.description,
    plugin.author,
    plugin.id,
    plugin.category,
    plugin.kind,
    (plugin.tags || []).join(" ")
  ].join(" "))
  return terms.every(function(term) { return text.indexOf(term) !== -1 })
}

function pluginIdIsSafe(value) {
  var id = String(value || "")
  return /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id) && id.indexOf("..") === -1
}

function matchesInstalled(plugin, query, filter) {
  if (!plugin) return false
  if (filter === "enabled" && !plugin.enabled) return false
  if (filter === "disabled" && plugin.enabled) return false

  var terms = normalized(query).split(/\s+/).filter(function(term) { return term.length > 0 })
  if (terms.length === 0) return true
  var text = normalized([
    plugin.pluginName,
    plugin.pluginId,
    plugin.kindsText,
    plugin.firstParty ? "built-in first-party" : "user-installed third-party"
  ].join(" "))
  return terms.every(function(term) { return text.indexOf(term) !== -1 })
}

function sortInstalled(plugins) {
  return plugins.slice().sort(function(first, second) {
    if (first.enabled !== second.enabled) return first.enabled ? -1 : 1
    return compareNames(
      { name: first.pluginName, id: first.pluginId },
      { name: second.pluginName, id: second.pluginId }
    )
  })
}

function parsedTime(value) {
  var time = Date.parse(String(value || ""))
  return isNaN(time) ? 0 : time
}

function listingTime(plugin) {
  return parsedTime(plugin.listedAt || (plugin.addedAt ? plugin.addedAt + "T00:00:00Z" : ""))
}

function activityTime(plugin) {
  return Math.max(parsedTime(plugin.versionUpdatedAt), parsedTime(plugin.repositoryUpdatedAt))
}

function count(value) {
  var result = Math.floor(Number(value))
  return isFinite(result) && result >= 0 ? result : 0
}

function formatCount(value) {
  var raw = Number(value)
  if (!isFinite(raw) || raw < 0) return "—"
  var result = count(raw)
  if (result < 1000) return String(result)
  if (result < 10000) return (result / 1000).toFixed(1).replace(/\.0$/, "") + "k"
  if (result < 1000000) return String(Math.round(result / 1000)) + "k"
  return (result / 1000000).toFixed(1).replace(/\.0$/, "") + "m"
}

function compareNames(first, second) {
  var firstName = normalized(first.name || first.id)
  var secondName = normalized(second.name || second.id)
  if (firstName < secondName) return -1
  if (firstName > secondName) return 1
  var firstId = normalized(first.id)
  var secondId = normalized(second.id)
  return firstId < secondId ? -1 : firstId > secondId ? 1 : 0
}

function sortPlugins(plugins, mode, engagement) {
  var metric = mode === "views" || mode === "copies" || mode === "hearts" ? mode : ""
  var effectiveMode = mode === "verified" || mode === "unverified" ? "added" : mode
  var decorated = plugins.map(function(plugin) {
    var key = 0
    if (effectiveMode === "added") key = listingTime(plugin)
    else if (effectiveMode === "updated") key = activityTime(plugin)
    else if (effectiveMode === "stars") key = count(plugin.stars)
    else if (metric) {
      var stats = engagement && engagement[plugin.id] ? engagement[plugin.id] : {}
      key = count(stats[metric])
    }
    return { plugin: plugin, key: key }
  })
  decorated.sort(function(first, second) {
    return second.key - first.key || compareNames(first.plugin, second.plugin)
  })
  return decorated.map(function(entry) { return entry.plugin })
}

function repoIsSafe(value) {
  return /^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+(?:\.git)?$/.test(String(value || ""))
}

function validateCatalogPlugin(plugin) {
  if (!plugin || typeof plugin !== "object" || Array.isArray(plugin)) return false
  var id = String(plugin.id || "")
  if (!pluginIdIsSafe(id)) return false
  if (!String(plugin.name || "")) return false
  if (!repoIsSafe(plugin.repo)) return false
  if (plugin.installAvailable !== true && plugin.installAvailable !== false) return false
  if (String(plugin.sourceType || "community") !== "community") return false
  return true
}

function previewUrl(value) {
  var source = String(value || "")
  if (!source) return ""
  if (/^https:\/\//.test(source)) return source
  return "https://omarchyplugins.com/" + source.replace(/^\/+/, "")
}

function shortCommit(value) {
  var commit = String(value || "")
  return commit.length >= 8 ? commit.slice(0, 8) : commit
}
