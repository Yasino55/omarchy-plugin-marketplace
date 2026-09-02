import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "MarketplaceModel.js" as MarketplaceModel
import "MarketplaceSession.js" as MarketplaceSession

Item {
  id: root

  property bool opened: false
  property bool loading: false
  property bool catalogLoaded: false
  property bool catalogRequestParsed: false
  property bool installConfirmOpen: false
  property string errorMessage: ""
  property string statusMessage: ""
  property string generatedAt: ""
  property string sortMode: "added"
  property int selectedIndex: 0
  property bool preserveSelectionForNextRebuild: true
  property var catalogPlugins: []
  property var displayRows: []
  property var engagementStats: ({})
  property bool engagementAvailable: false
  property bool engagementRequestParsed: false
  property var installedIds: ({})
  property bool installedLoaded: false
  property bool installedRequestParsed: false
  property var installedPlugins: []
  property var managedRows: []
  property var updateRows: []
  property var gitManagedIds: ({})
  property var gitProbeQueue: []
  property int gitProbeGeneration: 0
  property int activeGitProbeGeneration: 0
  property string viewMode: "browse"
  property string managementFilter: "all"
  property var pendingPlugin: null
  property var pendingManagedPlugin: null
  property string pendingAction: ""
  property string pendingValidatedAction: ""
  property string pendingValidatedPluginId: ""
  property var pendingRevalidatedPlugin: null
  property string pendingUpdateLocalCommit: ""
  property string pendingUpdateRemoteCommit: ""
  property string installingPluginId: ""
  property string installingPluginName: ""
  property string failedPluginId: ""
  property string installStdout: ""
  property string installStderr: ""
  property string pendingInstallFailureMessage: ""
  property string managingPluginId: ""
  property string managingPluginName: ""
  property string managingAction: ""
  property string managementStdout: ""
  property string managementStderr: ""
  property string probingPluginId: ""
  property var updateStatusById: ({})
  property bool updateCheckLoaded: false
  property int updateCheckGeneration: 0
  property int activeUpdateCheckGeneration: 0
  property string installHandoffPluginId: ""
  property string previewPath: ""
  property string previewRequestUrl: ""
  property string previewActiveUrl: ""

  readonly property var sortOptions: {
    var options = [
      { value: "added", label: "Recently added" },
      { value: "updated", label: "Recent activity" },
      { value: "stars", label: "Most starred" }
    ]
    if (root.engagementAvailable) options = options.concat([
      { value: "views", label: "Most viewed" },
      { value: "copies", label: "Most copied" },
      { value: "hearts", label: "Most hearts" }
    ])
    return options.concat([
      { value: "name", label: "A-Z" },
      { value: "verified", label: "Verified" },
      { value: "unverified", label: "Unverified" }
    ])
  }
  readonly property var managementOptions: [
    { value: "all", label: "All plugins" },
    { value: "enabled", label: "Enabled" },
    { value: "disabled", label: "Disabled" }
  ]

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color border: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property color accent: Color.menu.selectedText
  readonly property color selectedBackground: Color.menu.selectedBackground
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int captionFontSize: Style.font.caption + 2
  readonly property int smallFontSize: Style.font.bodySmall + 2
  readonly property int bodyFontSize: Style.font.body + 2
  readonly property int titleFontSize: Style.font.title + 2
  readonly property int headingFontSize: Style.font.heading + 2
  readonly property int displayFontSize: Style.font.display + 2
  readonly property int cardWidth: Math.min(Style.space(1160), panel.width - Style.gapsOut * 4)
  readonly property int cardHeight: Math.min(Style.space(940), panel.height - Style.gapsOut * 4)
  readonly property bool compactManagementTable: cardWidth < Style.space(900)
  readonly property int updateCount: {
    var count = 0
    for (var i = 0; i < root.installedPlugins.length; i++) {
      var status = root.updateStatusById[root.installedPlugins[i].pluginId]
      if (status && status.status === "available") count++
    }
    return count
  }
  readonly property int updateErrorCount: {
    var count = 0
    for (var i = 0; i < root.installedPlugins.length; i++) {
      var status = root.updateStatusById[root.installedPlugins[i].pluginId]
      if (status && status.status === "error") count++
    }
    return count
  }
  readonly property int updateCheckedCount: {
    var count = 0
    for (var i = 0; i < root.installedPlugins.length; i++) {
      var status = root.updateStatusById[root.installedPlugins[i].pluginId]
      if (status && status.status !== "unsupported") count++
    }
    return count
  }
  readonly property var selectedPlugin: displayRows.length > 0 && selectedIndex >= 0 && selectedIndex < displayRows.length
    ? displayRows[selectedIndex]
    : null
  readonly property bool installHandoffActive: root.installHandoffPluginId !== ""
  readonly property bool operationRunning: installProc.running || managementProc.running
    || installedProc.running || actionEligibilityProc.running
    || postInstallEnableProc.running || postInstallRescanProc.running
    || postInstallPresenceProc.running
  readonly property bool installBusy: root.operationRunning || root.installHandoffActive
  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.yasino55.omarchy-plugin-marketplace"

  function open(payloadJson) {
    MarketplaceSession.openRequested = true
    root.opened = true
    root.statusMessage = ""
    root.refreshInstalled()
    if (!root.catalogLoaded && !catalogProc.running) root.refreshCatalog()
    if (!root.engagementAvailable && !engagementProc.running) root.refreshEngagement()
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function close() {
    MarketplaceSession.openRequested = false
    root.installConfirmOpen = false
    root.pendingPlugin = null
    root.pendingManagedPlugin = null
    root.pendingAction = ""
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  Component.onCompleted: {
    root.viewMode = MarketplaceSession.viewMode
    root.managementFilter = MarketplaceSession.managementFilter
    root.installHandoffPluginId = MarketplaceSession.pendingInstallId
    searchField.text = MarketplaceSession.searchText
    if (MarketplaceSession.openRequested) Qt.callLater(function() { root.open("{}") })
    else if (MarketplaceSession.pendingInstallId) Qt.callLater(function() { root.refreshInstalled() })
  }

  function refreshCatalog() {
    if (catalogProc.running) return
    root.loading = true
    root.errorMessage = ""
    root.catalogRequestParsed = false
    catalogProc.running = true
  }

  function loadCatalog(raw) {
    try {
      var catalog = JSON.parse(String(raw || ""))
      var schemaVersion = Number(catalog.stateSchemaVersion)
      if (!isFinite(schemaVersion) || schemaVersion < 1 || schemaVersion > 99
          || Math.floor(schemaVersion) !== schemaVersion
          || !Array.isArray(catalog.plugins) || catalog.plugins.length > 20000)
        throw new Error("Unsupported catalog format")
      var validPlugins = []
      for (var i = 0; i < catalog.plugins.length; i++) {
        if (MarketplaceModel.validateCatalogPlugin(catalog.plugins[i]))
          validPlugins.push(catalog.plugins[i])
      }
      if (validPlugins.length === 0)
        throw new Error("No usable plugins in catalog")
      root.catalogPlugins = validPlugins
      root.generatedAt = String(catalog.generatedAt || "")
      root.catalogLoaded = true
      root.catalogRequestParsed = true
      root.scheduleRebuild()
    } catch (error) {
      root.errorMessage = "Could not read the marketplace catalog: " + error
    }
  }

  function refreshEngagement() {
    if (engagementProc.running) return
    root.engagementRequestParsed = false
    engagementProc.running = true
  }

  function loadEngagement(raw) {
    try {
      var response = JSON.parse(String(raw || ""))
      if (response.schemaVersion !== 1 || !response.plugins
          || typeof response.plugins !== "object" || Array.isArray(response.plugins))
        throw new Error("Unsupported engagement format")
      var stats = ({})
      var ids = Object.keys(response.plugins)
      if (ids.length > 2000) throw new Error("Engagement response is too large")
      for (var i = 0; i < ids.length; i++) {
        var id = ids[i]
        if (!MarketplaceModel.pluginIdIsSafe(id) || id.length > 128) continue
        var entry = response.plugins[id]
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue
        var safeEntry = ({})
        var metrics = ["views", "copies", "hearts"]
        for (var j = 0; j < metrics.length; j++) {
          var metric = Number(entry[metrics[j]])
          if (isFinite(metric) && metric >= 0 && metric <= 1000000000)
            safeEntry[metrics[j]] = metric
        }
        stats[id] = safeEntry
      }
      root.engagementStats = stats
      root.engagementAvailable = true
      root.engagementRequestParsed = true
      if (root.catalogLoaded) root.scheduleRebuild()
    } catch (error) {
      root.engagementAvailable = false
    }
  }

  function rebuildDisplay() {
    var previousId = root.preserveSelectionForNextRebuild && root.selectedPlugin
      ? root.selectedPlugin.pluginId : ""
    root.preserveSelectionForNextRebuild = true

    var matchingPlugins = []
    for (var i = 0; i < root.catalogPlugins.length; i++) {
      var candidate = root.catalogPlugins[i]
      if (MarketplaceModel.matches(candidate, searchField.text, root.sortMode)) matchingPlugins.push(candidate)
    }
    matchingPlugins = MarketplaceModel.sortPlugins(matchingPlugins, root.sortMode, root.engagementStats)

    var rows = []
    for (var sortedIndex = 0; sortedIndex < matchingPlugins.length; sortedIndex++) {
      var plugin = matchingPlugins[sortedIndex]
      var pluginId = String(plugin.id || "")
      var stats = root.engagementStats[pluginId] || {}
      rows.push({
        pluginId: pluginId,
        pluginName: MarketplaceModel.plainText(plugin.name || plugin.id, "Unnamed plugin"),
        description: MarketplaceModel.plainText(plugin.description, "No description provided."),
        author: MarketplaceModel.plainText(plugin.author, "Unknown"),
        pluginVersion: String(plugin.version || ""),
        category: MarketplaceModel.plainText(plugin.category, "Other"),
        tagsText: (plugin.tags || []).map(function(tag) { return MarketplaceModel.plainText(tag) }).join("  ·  "),
        repo: String(plugin.repo || ""),
        kind: MarketplaceModel.plainText(plugin.kind, "Plugin"),
        verificationStatus: String(plugin.verificationStatus || "unverified"),
        installAvailable: plugin.installAvailable === true && MarketplaceModel.repoIsSafe(plugin.repo),
        installNote: MarketplaceModel.plainText(plugin.installNote),
        previewImage: MarketplaceModel.previewUrl(plugin.previewImage || plugin.previewThumbnail),
        listingCommit: String(plugin.listingValidatedCommit || ""),
        upstreamCommit: String(plugin.upstreamValidatedCommit || ""),
        installed: root.installedIds[pluginId] === true,
        viewsText: MarketplaceModel.formatCount(root.engagementAvailable ? stats.views : -1),
        starsText: MarketplaceModel.formatCount(plugin.stars),
        heartsText: MarketplaceModel.formatCount(root.engagementAvailable ? stats.hearts : -1)
      })
    }

    var nextIndex = 0
    if (previousId) {
      for (var j = 0; j < rows.length; j++) {
        if (rows[j].pluginId === previousId) {
          nextIndex = j
          break
        }
      }
    }
    root.displayRows = rows
    root.selectedIndex = rows.length > 0 ? nextIndex : 0
    Qt.callLater(function() {
      if (root.displayRows.length > 0) pluginList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
      root.refreshPreview()
    })
  }

  function refreshPreview() {
    var source = root.selectedPlugin ? String(root.selectedPlugin.previewImage || "") : ""
    root.previewRequestUrl = source
    root.previewPath = ""
    if (!source) return
    if (previewProc.running) return
    root.previewActiveUrl = source
    previewProc.command = ["bash", root.pluginDir + "/fetch-preview", source,
      Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-marketplace-preview.png"]
    previewProc.running = true
  }

  function scheduleRebuild(preserveSelection) {
    if (preserveSelection === false) root.preserveSelectionForNextRebuild = false
    rebuildTimer.restart()
  }

  function select(index) {
    if (index < 0 || index >= root.displayRows.length) return
    root.selectedIndex = index
    pluginList.positionViewAtIndex(index, ListView.Contain)
    // Selection drives the detail preview. Without this, the preview only
    // refreshed via the previewProc completion chain, which stalls after
    // landing on a plugin that has no image (no process, no onExited), so
    // the previous plugin's screenshot stayed on screen.
    root.refreshPreview()
  }

  function selectRelative(delta) {
    if (root.viewMode !== "browse") return
    if (root.displayRows.length === 0) return
    root.select((root.selectedIndex + delta + root.displayRows.length) % root.displayRows.length)
  }

  function setView(mode) {
    if (root.viewMode === mode) return
    root.viewMode = mode
    MarketplaceSession.viewMode = mode
    MarketplaceSession.searchText = ""
    searchField.clear()
    root.statusMessage = ""
    if (mode !== "browse" && !root.installedLoaded) root.refreshInstalled()
    else if (mode !== "browse") root.scheduleManagedRebuild()
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function setSort(mode) {
    if (root.sortMode === mode) return
    root.sortMode = mode
    root.scheduleRebuild(false)
  }

  function refreshInstalled() {
    if (installedProc.running || installProc.running || managementProc.running || actionEligibilityProc.running) return
    root.installedRequestParsed = false
    installedProc.running = true
  }

  function loadInstalled(raw) {
    try {
      var rows = JSON.parse(String(raw || ""))
      if (!Array.isArray(rows)) throw new Error("Plugin list is not an array")
      var ids = {}
      var plugins = []
      for (var i = 0; i < rows.length; i++) {
        var id = String(rows[i].id || "")
        if (!MarketplaceModel.pluginIdIsSafe(id)) continue
        var kinds = Array.isArray(rows[i].kinds) ? rows[i].kinds.map(String) : []
        ids[id] = true
        plugins.push({
          pluginId: id,
          pluginName: String(rows[i].name || id),
          kinds: kinds,
          kindsText: kinds.join(", "),
          enabled: rows[i].enabled === true,
          active: rows[i].active === true,
          canDisable: rows[i].canDisable === true,
          firstParty: rows[i].firstParty === true,
          clonedFrom: String(rows[i].clonedFrom || "")
        })
      }
      root.installedIds = ids
      root.installedPlugins = plugins
      root.gitManagedIds = ({})
      root.gitProbeQueue = []
      root.gitProbeGeneration++
      root.installedLoaded = true
      root.installedRequestParsed = true
      root.rebuildManaged()
      root.queueGitProbes()
      root.queueUpdateCheck()
      if (root.catalogLoaded) root.scheduleRebuild()
      if (MarketplaceSession.pendingInstallId)
        Qt.callLater(function() { root.continuePendingInstall() })
    } catch (error) {
      root.statusMessage = "Installed plugin status is unavailable."
    }
  }

  function clearInstallHandoff() {
    var token = MarketplaceSession.pendingInstallToken
    if (token && !installReceiptCleanupProc.running) {
      installReceiptCleanupProc.command = ["bash", root.pluginDir + "/plugin-add-checked",
        "--remove-receipt", token]
      installReceiptCleanupProc.running = true
    }
    MarketplaceSession.pendingInstallId = ""
    root.installHandoffPluginId = ""
    MarketplaceSession.pendingInstallName = ""
    MarketplaceSession.pendingInstallStage = ""
    MarketplaceSession.pendingInstallToken = ""
    MarketplaceSession.pendingInstallAllowEnable = false
    MarketplaceSession.pendingInstallAttempts = 0
    MarketplaceSession.pendingEnableAttempts = 0
  }

  function retryPendingInstallRefresh() {
    if (!MarketplaceSession.pendingInstallId) return
    MarketplaceSession.pendingInstallAttempts++
    if (MarketplaceSession.pendingInstallAttempts > 40) {
      var name = MarketplaceSession.pendingInstallName || MarketplaceSession.pendingInstallId
      root.clearInstallHandoff()
      root.statusMessage = "Installed plugin status remained unavailable for " + name + ". Refresh Marketplace to retry."
    } else pendingInstallTimer.restart()
  }

  function continuePendingInstall() {
    var id = MarketplaceSession.pendingInstallId
    if (!id || installedProc.running) return
    var name = MarketplaceSession.pendingInstallName || id
    if (MarketplaceSession.pendingInstallStage === "installing") {
      if (!postInstallPresenceProc.running) {
        postInstallPresenceProc.command = ["bash", root.pluginDir + "/plugin-add-checked",
          "--consume-receipt", MarketplaceSession.pendingInstallToken, id]
        postInstallPresenceProc.running = true
      }
      return
    }
    var plugin = root.installedPluginById(id)
    if (!plugin) {
      MarketplaceSession.pendingInstallAttempts++
      if (MarketplaceSession.pendingInstallAttempts > 40) {
        root.clearInstallHandoff()
        root.statusMessage = "Installation finished, but " + name
          + " could not be discovered. Refresh Marketplace or rescan plugins."
        return
      }
      root.statusMessage = "Waiting for " + name + " to be discovered…"
      if (MarketplaceSession.pendingInstallAttempts === 8 && !postInstallRescanProc.running) {
        postInstallRescanProc.running = true
      } else pendingInstallTimer.restart()
      return
    }

    root.failedPluginId = ""
    root.rebuildManaged()
    if (root.catalogLoaded) root.scheduleRebuild()
    if (plugin.kinds.indexOf("bar") !== -1) {
      root.clearInstallHandoff()
      root.statusMessage = name + " was installed. Activate full-bar plugins from the command line."
      return
    }
    if (!MarketplaceSession.pendingInstallAllowEnable) {
      root.clearInstallHandoff()
      root.statusMessage = name + " was installed without activation. Activate it from the command line."
      return
    }
    if (plugin.enabled) {
      root.clearInstallHandoff()
      root.statusMessage = name + " was installed and enabled."
      return
    }

    if (MarketplaceSession.pendingInstallStage !== "enabling") {
      MarketplaceSession.pendingInstallStage = "enabling"
      MarketplaceSession.pendingInstallAttempts = 0
      MarketplaceSession.pendingEnableAttempts++
      root.statusMessage = "Enabling " + name + "…"
      postInstallEnableProc.command = ["omarchy", "plugin", "enable", id]
      postInstallEnableProc.running = true
      return
    }

    MarketplaceSession.pendingInstallAttempts++
    if (MarketplaceSession.pendingInstallAttempts >= 8) {
      if (MarketplaceSession.pendingEnableAttempts < 2) {
        MarketplaceSession.pendingInstallStage = "discovering"
        root.continuePendingInstall()
      } else {
        root.clearInstallHandoff()
        root.statusMessage = name + " was installed but could not be enabled. Enable it from Manage."
      }
    } else pendingInstallTimer.restart()
  }

  function rebuildManaged() {
    var matching = []
    var updates = []
    for (var i = 0; i < root.installedPlugins.length; i++) {
      var plugin = root.installedPlugins[i]
      if (MarketplaceModel.matchesInstalled(plugin, searchField.text, root.managementFilter)) matching.push(plugin)
      var update = root.updateStatusById[plugin.pluginId]
      if (update && update.status === "available"
          && MarketplaceModel.matchesInstalled(plugin, searchField.text, "all")) {
        updates.push(Object.assign({}, plugin, {
          localCommit: String(update.localCommit || ""),
          remoteCommit: String(update.remoteCommit || "")
        }))
      }
    }
    root.managedRows = MarketplaceModel.sortInstalled(matching)
    root.updateRows = MarketplaceModel.sortInstalled(updates)
  }

  function scheduleManagedRebuild() {
    managedRebuildTimer.restart()
  }

  function setManagementFilter(filter) {
    if (root.managementFilter === filter) return
    root.managementFilter = filter
    MarketplaceSession.managementFilter = filter
    root.scheduleManagedRebuild()
  }

  function queueUpdateCheck() {
    root.updateCheckGeneration++
    root.updateCheckLoaded = false
    root.rebuildManaged()
    if (!updateCheckProc.running) root.startUpdateCheck()
  }

  function startUpdateCheck() {
    if (updateCheckProc.running) return
    var ids = []
    for (var i = 0; i < root.installedPlugins.length; i++) {
      var plugin = root.installedPlugins[i]
      if (!plugin.firstParty && MarketplaceModel.pluginIdIsSafe(plugin.pluginId)) ids.push(plugin.pluginId)
    }
    root.activeUpdateCheckGeneration = root.updateCheckGeneration
    if (ids.length === 0) {
      root.updateStatusById = ({})
      root.updateCheckLoaded = true
      root.rebuildManaged()
      return
    }
    updateCheckProc.command = ["bash", root.pluginDir + "/plugin-update-status"].concat(ids)
    updateCheckProc.running = true
  }

  function loadUpdateStatus(raw) {
    try {
      var payload = JSON.parse(String(raw || ""))
      if (payload.schemaVersion !== 1 || !Array.isArray(payload.plugins))
        throw new Error("Unsupported update status response")
      var statuses = {}
      for (var i = 0; i < payload.plugins.length; i++) {
        var result = payload.plugins[i]
        var id = String(result.id || "")
        var status = String(result.status || "")
        if (!MarketplaceModel.pluginIdIsSafe(id)
            || ["available", "current", "unsupported", "error"].indexOf(status) === -1) continue
        statuses[id] = {
          status: status,
          localCommit: String(result.localCommit || ""),
          remoteCommit: String(result.remoteCommit || ""),
          error: String(result.error || "")
        }
      }
      root.updateStatusById = statuses
      root.updateCheckLoaded = true
      root.rebuildManaged()
    } catch (error) {
      root.updateStatusById = ({})
      root.updateCheckLoaded = false
      root.rebuildManaged()
    }
  }

  function queueGitProbes() {
    var queue = []
    for (var i = 0; i < root.installedPlugins.length; i++) {
      var plugin = root.installedPlugins[i]
      if (!plugin.firstParty && MarketplaceModel.pluginIdIsSafe(plugin.pluginId))
        queue.push({ id: plugin.pluginId, generation: root.gitProbeGeneration })
    }
    root.gitProbeQueue = queue
    root.startNextGitProbe()
  }

  function startNextGitProbe() {
    if (gitProbeProc.running || root.gitProbeQueue.length === 0) return
    var queue = root.gitProbeQueue.slice()
    var entry = queue.shift()
    root.gitProbeQueue = queue
    root.probingPluginId = entry.id
    root.activeGitProbeGeneration = entry.generation
    gitProbeProc.command = ["test", "-d",
      Quickshell.env("HOME") + "/.config/omarchy/plugins/" + entry.id + "/.git"]
    gitProbeProc.running = true
  }

  function installedPluginById(id) {
    for (var i = 0; i < root.installedPlugins.length; i++) {
      if (root.installedPlugins[i].pluginId === id) return root.installedPlugins[i]
    }
    return null
  }

  function requestInstall(plugin) {
    if (root.installBusy || !root.installedRequestParsed || !plugin
        || plugin.installed || !plugin.installAvailable
        || !MarketplaceModel.pluginIdIsSafe(plugin.pluginId)
        || !MarketplaceModel.repoIsSafe(plugin.repo)) return
    root.pendingPlugin = plugin
    root.pendingAction = "install"
    installConfirm.selectedIndex = 0
    root.installConfirmOpen = true
  }

  function cancelInstall() {
    root.installConfirmOpen = false
    root.pendingPlugin = null
    root.pendingManagedPlugin = null
    root.pendingAction = ""
    root.pendingUpdateLocalCommit = ""
    root.pendingUpdateRemoteCommit = ""
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function confirmInstall() {
    var plugin = root.pendingPlugin
    root.installConfirmOpen = false
    if (root.installBusy || !root.installedRequestParsed || !plugin
        || plugin.installed || !plugin.installAvailable
        || !MarketplaceModel.pluginIdIsSafe(plugin.pluginId)
        || !MarketplaceModel.repoIsSafe(plugin.repo)) {
      root.pendingPlugin = null
      root.pendingAction = ""
      root.statusMessage = "Installation blocked: this plugin is not available for automatic installation."
      return
    }
    root.installingPluginId = plugin.pluginId
    root.installingPluginName = plugin.pluginName
    root.failedPluginId = ""
    root.installStdout = ""
    root.installStderr = ""
    MarketplaceSession.pendingInstallId = plugin.pluginId
    root.installHandoffPluginId = plugin.pluginId
    MarketplaceSession.pendingInstallName = plugin.pluginName
    MarketplaceSession.pendingInstallStage = "installing"
    MarketplaceSession.pendingInstallToken = String(Date.now())
    MarketplaceSession.pendingInstallAllowEnable = !root.pluginReplacesBar(plugin)
    MarketplaceSession.pendingInstallAttempts = 0
    MarketplaceSession.pendingEnableAttempts = 0
    root.statusMessage = "Installing " + plugin.pluginName + "…"
    installProc.command = ["bash", root.pluginDir + "/plugin-add-checked", plugin.repo,
      plugin.pluginId, MarketplaceSession.pendingInstallToken]
    installProc.running = true
  }

  function clearInstallState() {
    root.pendingPlugin = null
    root.pendingAction = ""
    root.installingPluginId = ""
    root.installingPluginName = ""
  }

  function confirmationMessage() {
    if (root.pendingAction === "install" && root.pendingPlugin)
      return (root.pluginReplacesBar(root.pendingPlugin)
          ? "Install " + root.pendingPlugin.pluginName
            + "?\n\nThis plugin replaces the full bar and must be activated from the command line."
          : "Install and enable " + root.pendingPlugin.pluginName + "?")
        + "\n\nCommunity plugins run as unsandboxed code inside omarchy-shell. Marketplace verification is not proof of safety. Continue only if you trust this repository."
    var plugin = root.pendingManagedPlugin
    if (!plugin) return ""
    if (root.pendingAction === "enable")
      return "Enable " + plugin.pluginName
        + "?\n\nThis third-party plugin will run as unsandboxed code inside omarchy-shell. Continue only if you trust it."
    if (root.pendingAction === "update")
      return "Check for and install updates to " + plugin.pluginName
        + (root.pendingUpdateRemoteCommit
          ? "?\n\nChecked commits: " + MarketplaceModel.shortCommit(root.pendingUpdateLocalCommit)
            + " → " + MarketplaceModel.shortCommit(root.pendingUpdateRemoteCommit)
            + ". The remote and local commit will be revalidated before updating."
          : "?")
        + "\n\nUpdated third-party code will run unsandboxed inside omarchy-shell. The non-interactive update applies upstream changes without showing a diff."
    if (root.pendingAction === "remove")
      return "Remove " + plugin.pluginName
        + "?\n\nGit checkouts are deleted. Manually installed folders are moved to a timestamped backup."
    return ""
  }

  function confirmationButtonText() {
    if (root.pendingAction === "install") return "Install"
    if (root.pendingAction === "enable") return "Enable"
    if (root.pendingAction === "update") return "Update"
    if (root.pendingAction === "remove") return "Remove"
    return "Continue"
  }

  function requestManagementAction(action, plugin) {
    if (root.operationRunning || !root.installedRequestParsed || !plugin
        || !MarketplaceModel.pluginIdIsSafe(plugin.pluginId)) return
    if (plugin.pluginId === "io.yasino55.omarchy-plugin-marketplace") {
      root.statusMessage = "Manage the running marketplace itself from the command line."
      return
    }
    if (action === "enable" && plugin.kinds.indexOf("bar") !== -1) {
      root.statusMessage = "Enable full-bar plugins from the command line so the marketplace cannot unload mid-operation."
      return
    }
    if (action === "remove" && plugin.active) {
      root.statusMessage = "Remove the active bar from the command line so the marketplace cannot unload mid-operation."
      return
    }
    if (action === "update" && plugin.active) {
      root.statusMessage = "Update the active bar from the command line so the marketplace cannot unload mid-operation."
      return
    }
    if (plugin.pluginId === root.installHandoffPluginId) {
      root.statusMessage = "Wait until " + plugin.pluginName + " finishes installing."
      return
    }
    if (action === "enable" && plugin.enabled) return
    if (action === "disable" && (!plugin.enabled || !plugin.canDisable)) return
    if (action === "update" && (plugin.firstParty
        || root.gitManagedIds[plugin.pluginId] !== true && !plugin.localCommit)) return
    if (action === "remove" && plugin.firstParty) return

    var needsConfirmation = action === "update" || action === "remove"
      || (action === "enable" && !plugin.firstParty)
    if (needsConfirmation) {
      root.pendingUpdateLocalCommit = action === "update" ? String(plugin.localCommit || "") : ""
      root.pendingUpdateRemoteCommit = action === "update" ? String(plugin.remoteCommit || "") : ""
      root.pendingManagedPlugin = plugin
      root.pendingAction = action
      installConfirm.selectedIndex = 0
      root.installConfirmOpen = true
      return
    }
    root.runManagementAction(action, plugin)
  }

  function confirmPendingAction() {
    if (root.pendingAction === "install") {
      root.confirmInstall()
      return
    }
    var action = root.pendingAction
    var plugin = root.pendingManagedPlugin
    root.installConfirmOpen = false
    root.pendingManagedPlugin = null
    root.pendingAction = ""
    if (!plugin || !MarketplaceModel.pluginIdIsSafe(plugin.pluginId)) return
    root.pendingValidatedAction = action
    root.pendingValidatedPluginId = plugin.pluginId
    root.statusMessage = "Checking current plugin state…"
    root.refreshInstalled()
  }

  function runManagementAction(action, plugin) {
    var error = root.managementActionError(action, plugin)
    if (error) {
      root.statusMessage = "Action unavailable: " + error
      return
    }

    root.managingPluginId = plugin.pluginId
    root.managingPluginName = plugin.pluginName
    root.managingAction = action
    root.managementStdout = ""
    root.managementStderr = ""
    if (action === "enable") managementProc.command = ["omarchy", "plugin", "enable", plugin.pluginId]
    else if (action === "disable") managementProc.command = ["omarchy", "plugin", "disable", plugin.pluginId]
    else if (action === "update") managementProc.command = ["omarchy", "plugin", "update", plugin.pluginId, "--yes"]
    else if (action === "remove") managementProc.command = ["omarchy", "plugin", "remove", plugin.pluginId, "--yes"]
    else return
    root.statusMessage = (action === "update" ? "Checking " : action.charAt(0).toUpperCase() + action.slice(1) + " ")
      + plugin.pluginName + "…"
    managementProc.running = true
  }

  function runCheckedUpdate(plugin, expectedLocal, expectedRemote) {
    if (root.operationRunning || !plugin || plugin.active
        || plugin.pluginId === "io.yasino55.omarchy-plugin-marketplace"
        || !MarketplaceModel.pluginIdIsSafe(plugin.pluginId)) {
      root.statusMessage = "Action unavailable: checked update state is no longer valid."
      return
    }
    root.managingPluginId = plugin.pluginId
    root.managingPluginName = plugin.pluginName
    root.managingAction = "update"
    root.managementStdout = ""
    root.managementStderr = ""
    root.statusMessage = "Updating " + plugin.pluginName + " to the checked commit…"
    managementProc.command = ["bash", root.pluginDir + "/plugin-update-checked",
      plugin.pluginId, expectedLocal, expectedRemote]
    managementProc.running = true
  }

  function managementActionError(action, plugin) {
    if (root.operationRunning) return "another plugin operation is running."
    if (!root.installedRequestParsed) return "current plugin state is unavailable."
    if (!plugin || !MarketplaceModel.pluginIdIsSafe(plugin.pluginId)) return "plugin data is invalid."
    if (plugin.pluginId === "io.yasino55.omarchy-plugin-marketplace") return "manage the running marketplace from the command line."
    if (action === "enable" && plugin.kinds.indexOf("bar") !== -1)
      return "enable full-bar plugins from the command line."
    if ((action === "remove" || action === "update") && plugin.active)
      return "manage the active bar from the command line."
    if (plugin.pluginId === root.installHandoffPluginId)
      return "wait until the plugin finishes installing."
    if (action === "enable" && plugin.enabled) return "the plugin is already enabled."
    if (action === "disable" && !plugin.enabled) return "the plugin is already disabled."
    if (action === "disable" && !plugin.canDisable) return "this plugin cannot be disabled."
    if (action === "update" && plugin.firstParty) return "built-in plugins update with Omarchy."
    if (action === "update" && root.gitManagedIds[plugin.pluginId] !== true && !plugin.localCommit)
      return "this user plugin is not Git managed."
    if (action === "remove" && plugin.firstParty) return "built-in plugins cannot be removed."
    return ""
  }

  function processDetail(stdoutText, stderrText, fallback) {
    var raw = String(stderrText || stdoutText || "").replace(/\x1b\[[0-9;]*m/g, "").trim()
    if (!raw) return fallback
    var lines = raw.split(/\r?\n/).filter(function(line) { return line.trim() !== "" })
    var detail = lines.length ? lines[lines.length - 1].trim() : raw
    return detail.length > 180 ? detail.slice(0, 177) + "…" : detail
  }

  function processSuccessDetail(stdoutText, fallback) {
    var raw = String(stdoutText || "").replace(/\x1b\[[0-9;]*m/g, "").trim()
    if (!raw) return fallback
    var lines = raw.split(/\r?\n/).filter(function(line) { return line.trim() !== "" })
    return lines.length ? lines[0].trim() : fallback
  }

  function installFailureDetail() {
    var raw = String(root.installStderr || root.installStdout || "").replace(/\x1b\[[0-9;]*m/g, "").trim()
    if (!raw) return "Installation failed."
    var lines = raw.split(/\r?\n/).filter(function(line) { return line.trim() !== "" })
    var detail = lines.length ? lines[lines.length - 1].trim() : raw
    if (detail.length > 180) detail = detail.slice(0, 177) + "…"
    return "Installation failed: " + detail
  }

  function pluginReplacesBar(plugin) {
    var kind = String(plugin && plugin.kind || "").toLowerCase().trim()
    return kind === "bar" || kind === "full bar"
  }

  function handleInstallAction(plugin) {
    if (!plugin || root.installBusy) return
    if (plugin.installAvailable) {
      if (root.installedRequestParsed) root.requestInstall(plugin)
    }
    else if (MarketplaceModel.repoIsSafe(plugin.repo)) Qt.openUrlExternally(plugin.repo)
  }

  Timer {
    id: rebuildTimer
    interval: 40
    onTriggered: root.rebuildDisplay()
  }

  Timer {
    id: managedRebuildTimer
    interval: 40
    onTriggered: root.rebuildManaged()
  }

  Timer {
    id: pendingInstallTimer
    interval: 250
    onTriggered: {
      if (MarketplaceSession.pendingInstallId) root.refreshInstalled()
    }
  }

  Process {
    id: postInstallRescanProc
    command: ["omarchy-shell", "shell", "rescanPlugins"]
    onExited: function() {
      if (MarketplaceSession.pendingInstallId) pendingInstallTimer.restart()
    }
  }

  Process {
    id: postInstallPresenceProc
    onExited: function(exitCode) {
      if (!MarketplaceSession.pendingInstallId) return
      if (exitCode === 0) {
        MarketplaceSession.pendingInstallStage = "discovering"
        MarketplaceSession.pendingInstallAttempts = 0
        root.statusMessage = (MarketplaceSession.pendingInstallName || MarketplaceSession.pendingInstallId)
          + " was installed. Waiting for plugin discovery…"
        pendingInstallTimer.restart()
      } else {
        var detail = root.pendingInstallFailureMessage || "Installation failed."
        root.clearInstallHandoff()
        root.statusMessage = detail
        Qt.callLater(function() { root.refreshInstalled() })
      }
      root.pendingInstallFailureMessage = ""
    }
  }

  Process {
    id: installReceiptCleanupProc
  }

  Process {
    id: postInstallEnableProc
    stdout: StdioCollector { id: postInstallEnableStdout; waitForEnd: true }
    stderr: StdioCollector { id: postInstallEnableStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (!MarketplaceSession.pendingInstallId) return
      if (exitCode === 0) {
        root.statusMessage = "Confirming that "
          + (MarketplaceSession.pendingInstallName || MarketplaceSession.pendingInstallId) + " is enabled…"
        pendingInstallTimer.restart()
      } else if (MarketplaceSession.pendingEnableAttempts < 2) {
        MarketplaceSession.pendingInstallStage = "discovering"
        pendingInstallTimer.restart()
      } else {
        var name = MarketplaceSession.pendingInstallName || MarketplaceSession.pendingInstallId
        var detail = root.processDetail(postInstallEnableStdout.text, postInstallEnableStderr.text,
          "the shell rejected the enable request")
        root.clearInstallHandoff()
        root.statusMessage = name + " was installed but not enabled: " + detail
        Qt.callLater(function() { root.refreshInstalled() })
      }
    }
  }

  Process {
    id: updateCheckProc
    stdout: StdioCollector { id: updateCheckStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (root.activeUpdateCheckGeneration !== root.updateCheckGeneration) {
        Qt.callLater(function() { root.startUpdateCheck() })
        return
      }
      if (exitCode === 0) root.loadUpdateStatus(updateCheckStdout.text)
      else {
        root.updateStatusById = ({})
        root.updateCheckLoaded = false
        root.rebuildManaged()
      }
    }
  }

  Process {
    id: catalogProc
    command: ["curl", "-fsSL", "--max-time", "20", "--max-filesize", "8388608",
      "https://plugins.omarchy.org/catalog.json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadCatalog(text)
    }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0 && !root.catalogRequestParsed)
        root.errorMessage = "Could not connect to plugins.omarchy.org."
    }
  }

  Process {
    id: installedProc
    command: ["omarchy", "plugin", "list", "--json"]
    stdout: StdioCollector {
      id: installedStdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0) root.loadInstalled(installedStdout.text)
      var action = root.pendingValidatedAction
      var id = root.pendingValidatedPluginId
      root.pendingValidatedAction = ""
      root.pendingValidatedPluginId = ""
      if (action && exitCode === 0 && root.installedRequestParsed) {
        var plugin = root.installedPluginById(id)
        if (plugin && action === "update") {
          root.pendingRevalidatedPlugin = plugin
          actionEligibilityProc.command = root.pendingUpdateLocalCommit
            ? ["bash", root.pluginDir + "/plugin-update-status", plugin.pluginId]
            : ["test", "-d",
              Quickshell.env("HOME") + "/.config/omarchy/plugins/" + plugin.pluginId + "/.git"]
          actionEligibilityProc.running = true
        } else if (plugin) {
          Qt.callLater(function() { root.runManagementAction(action, plugin) })
        }
        else {
          root.pendingUpdateLocalCommit = ""
          root.pendingUpdateRemoteCommit = ""
          root.statusMessage = "Action failed: plugin is no longer installed."
        }
      } else if (action) {
        root.pendingUpdateLocalCommit = ""
        root.pendingUpdateRemoteCommit = ""
        root.statusMessage = "Action failed: current plugin state is unavailable."
      } else if (exitCode !== 0 && !root.installedRequestParsed) {
        root.statusMessage = "Installed plugin status is unavailable."
      }
      if (MarketplaceSession.pendingInstallId && !root.installedRequestParsed)
        root.retryPendingInstallRefresh()
    }
  }

  Process {
    id: actionEligibilityProc
    stdout: StdioCollector { id: actionEligibilityStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var plugin = root.pendingRevalidatedPlugin
      root.pendingRevalidatedPlugin = null
      if (!plugin) return
      var expectedLocal = root.pendingUpdateLocalCommit
      var expectedRemote = root.pendingUpdateRemoteCommit
      root.pendingUpdateLocalCommit = ""
      root.pendingUpdateRemoteCommit = ""
      if (expectedLocal) {
        var valid = false
        if (exitCode === 0) {
          try {
            var payload = JSON.parse(String(actionEligibilityStdout.text || ""))
            var result = payload.schemaVersion === 1 && Array.isArray(payload.plugins)
              && payload.plugins.length === 1 ? payload.plugins[0] : null
            valid = result && result.id === plugin.pluginId && result.status === "available"
              && result.localCommit === expectedLocal && result.remoteCommit === expectedRemote
          } catch (error) {
            valid = false
          }
        }
        if (!valid) {
          root.statusMessage = "Update changed since it was checked. Refresh and review it again."
          return
        }
        Qt.callLater(function() { root.runCheckedUpdate(plugin, expectedLocal, expectedRemote) })
        return
      }
      var states = Object.assign({}, root.gitManagedIds)
      states[plugin.pluginId] = exitCode === 0
      root.gitManagedIds = states
      if (exitCode === 0) Qt.callLater(function() { root.runManagementAction("update", plugin) })
      else root.statusMessage = "Action unavailable: this user plugin is not Git managed."
    }
  }

  Process {
    id: gitProbeProc
    onExited: function(exitCode) {
      var id = root.probingPluginId
      if (root.activeGitProbeGeneration === root.gitProbeGeneration) {
        var states = Object.assign({}, root.gitManagedIds)
        states[id] = exitCode === 0
        root.gitManagedIds = states
      }
      root.probingPluginId = ""
      Qt.callLater(function() { root.startNextGitProbe() })
    }
  }

  Process {
    id: engagementProc
    command: ["curl", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
      "https://api.omarchyplugins.com/v1/stats"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadEngagement(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.engagementRequestParsed) root.engagementAvailable = false
    }
  }

  Process {
    id: previewProc
    onExited: function(exitCode) {
      var selectedSource = root.selectedPlugin ? String(root.selectedPlugin.previewImage || "") : ""
      if (root.previewActiveUrl !== selectedSource) {
        Qt.callLater(function() { root.refreshPreview() })
        return
      }
      if (exitCode === 0)
        root.previewPath = Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-marketplace-preview.png"
    }
  }

  Process {
    id: installProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.installStdout = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.installStderr = text
    }
    onExited: function(exitCode) {
      var id = root.installingPluginId
      var name = root.installingPluginName || "Plugin"
      if (exitCode === 0) {
        root.statusMessage = name + " was installed. Waiting for plugin discovery…"
        root.failedPluginId = ""
      } else {
        root.failedPluginId = id
        root.pendingInstallFailureMessage = root.installFailureDetail()
        postInstallPresenceProc.command = ["bash", root.pluginDir + "/plugin-add-checked",
          "--consume-receipt", MarketplaceSession.pendingInstallToken,
          MarketplaceSession.pendingInstallId]
        postInstallPresenceProc.running = true
      }
      root.clearInstallState()
      if (!postInstallPresenceProc.running) Qt.callLater(function() { root.refreshInstalled() })
    }
  }

  Process {
    id: managementProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.managementStdout = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.managementStderr = text
    }
    onExited: function(exitCode) {
      var name = root.managingPluginName || "Plugin"
      var action = root.managingAction
      if (exitCode === 0) {
        root.statusMessage = root.processSuccessDetail(root.managementStdout, name + " was " + action + "d.")
      } else {
        root.statusMessage = "Action failed: " + root.processDetail(root.managementStdout, root.managementStderr,
          "Could not " + action + " " + name + ".")
      }
      root.managingPluginId = ""
      root.managingPluginName = ""
      root.managingAction = ""
      Qt.callLater(function() { root.refreshInstalled() })
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "jason-marketplace"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      anchors.centerIn: parent
      color: root.background
      borderSpec: Border.surfaceSpec("menu", "border", root.border, Math.max(1, Style.normalBorderWidth))
      radius: Style.cornerRadius
      padding: Style.space(20)

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        z: root.installConfirmOpen ? 20 : 0
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.installConfirmOpen) {
            if (installConfirm.handleKey(event)) event.accepted = true
            return
          }
          if (sortDropdown.popupOpen || managementDropdown.popupOpen) return
          if (event.key === Qt.Key_Escape) {
            // Only the search field gets the "clear first, then close" step;
            // Escape from anywhere else closes the popup immediately.
            if (searchField.activeFocus && searchField.text) searchField.clear()
            else root.close()
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.selectRelative(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.selectRelative(1)
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: installConfirm
          anchors.fill: parent
          opened: root.installConfirmOpen
          z: 10
          message: root.pendingPlugin
            || root.pendingManagedPlugin ? root.confirmationMessage() : ""
          confirmText: root.confirmationButtonText()
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.accent
          fontFamily: root.fontFamily
          cornerRadius: Style.cornerRadius
          onCanceled: root.cancelInstall()
          onConfirmed: root.confirmPendingAction()
        }
      }

      Column {
        anchors.fill: parent
        // Route key events from any focused descendant (search field, tab
        // buttons, the plugin list) through the keyCatcher handler above so
        // Escape / arrow keys work regardless of where focus currently sits.
        Keys.forwardTo: [keyCatcher]
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(14)

        Row {
          width: parent.width
          height: Style.space(58)
          spacing: Style.space(14)

          Column {
            width: parent.width - refreshButton.width - parent.spacing
            spacing: Style.space(2)

            Text {
              text: "PLUGIN MARKETPLACE"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: root.headingFontSize
              font.bold: true
            }
            Text {
              text: root.viewMode === "browse"
                ? (root.catalogLoaded ? root.displayRows.length + " matching community plugins" : "Community registry")
                : root.viewMode === "manage"
                  ? (root.installedLoaded ? root.managedRows.length + " matching plugins" : "Plugin management")
                  : updateCheckProc.running
                    ? "Checking installed Git plugins"
                    : root.updateCheckLoaded
                      ? root.updateCount + (root.updateCount === 1 ? " update available" : " updates available")
                      : "Plugin update status"
              color: root.foreground
              opacity: 0.68
              font.family: root.fontFamily
              font.pixelSize: root.captionFontSize
            }
          }

          Button {
            id: refreshButton
            text: root.viewMode === "browse" && root.loading
              || root.viewMode !== "browse" && (installedProc.running || updateCheckProc.running)
              ? "Refreshing…" : "Refresh"
            bordered: true
            focusable: true
            enabled: !root.operationRunning
            foreground: root.foreground
            accent: root.accent
            fontSize: root.bodyFontSize
            onClicked: {
              if (root.viewMode === "browse") {
                root.refreshCatalog()
                root.refreshInstalled()
              } else root.refreshInstalled()
            }
          }
        }

        Row {
          width: parent.width
          height: Style.space(34)
          spacing: Style.space(8)

          Button {
            text: "Browse"
            width: Style.space(110)
            height: parent.height
            bordered: true
            focusable: true
            selected: root.viewMode === "browse"
            foreground: root.foreground
            accent: root.accent
            fontSize: root.bodyFontSize
            onClicked: root.setView("browse")
          }
          Button {
            text: "Manage"
            width: Style.space(110)
            height: parent.height
            bordered: true
            focusable: true
            selected: root.viewMode === "manage"
            foreground: root.foreground
            accent: root.accent
            fontSize: root.bodyFontSize
            onClicked: root.setView("manage")
          }
          Button {
            text: "Updates (" + root.updateCount + ")"
            width: Style.space(120)
            height: parent.height
            bordered: true
            focusable: true
            selected: root.viewMode === "updates"
            foreground: root.foreground
            accent: root.accent
            fontSize: root.bodyFontSize
            onClicked: root.setView("updates")
          }
        }

        Row {
          width: parent.width
          height: Style.space(42)
          spacing: Style.space(10)

          TextField {
            id: searchField
            width: root.viewMode === "updates"
              ? parent.width : parent.width - sortDropdown.width - parent.spacing
            height: parent.height
            placeholderText: root.viewMode === "browse"
              ? "Search plugins, tags, or authors…"
              : root.viewMode === "updates"
                ? "Search available updates…" : "Search plugins by name, ID, or type…"
            foreground: root.foreground
            accent: root.accent
            font.pixelSize: root.bodyFontSize
            onTextChanged: {
              MarketplaceSession.searchText = text
              if (root.viewMode === "browse" && root.catalogLoaded) root.scheduleRebuild()
              else if (root.viewMode !== "browse" && root.installedLoaded) root.scheduleManagedRebuild()
            }
            Keys.onDownPressed: root.selectRelative(1)
            Keys.onUpPressed: root.selectRelative(-1)
          }

          Dropdown {
            id: sortDropdown
            visible: root.viewMode === "browse"
            width: Style.space(190)
            height: parent.height
            showLabel: false
            rowHeight: parent.height
            value: root.sortMode
            options: root.sortOptions
            foreground: root.foreground
            background: root.background
            popupBorder: root.border
            accent: root.accent
            fontFamily: root.fontFamily
            onChanged: function(value) { root.setSort(value) }
          }

          Dropdown {
            id: managementDropdown
            visible: root.viewMode === "manage"
            width: Style.space(190)
            height: parent.height
            showLabel: false
            rowHeight: parent.height
            value: root.managementFilter
            options: root.managementOptions
            foreground: root.foreground
            background: root.background
            popupBorder: root.border
            accent: root.accent
            fontFamily: root.fontFamily
            onChanged: function(value) { root.setManagementFilter(value) }
          }
        }

        Item {
          width: parent.width
          height: parent.height - Style.space(58) - Style.space(34) - Style.space(42)
            - Style.space(20) - Style.space(56)

          Text {
            visible: root.viewMode === "browse" && root.loading && !root.catalogLoaded
            anchors.centerIn: parent
            text: "Loading marketplace…"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.titleFontSize
          }

          Column {
            visible: root.viewMode === "browse" && root.errorMessage !== "" && !root.catalogLoaded
            anchors.centerIn: parent
            width: Math.min(parent.width, Style.space(520))
            spacing: Style.space(14)

            Text {
              width: parent.width
              text: root.errorMessage
              color: Color.urgent
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              font.family: root.fontFamily
              font.pixelSize: root.titleFontSize
            }
            Button {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Try again"
              bordered: true
              fontSize: root.bodyFontSize
              foreground: root.foreground
              accent: root.accent
              onClicked: root.refreshCatalog()
            }
          }

          Row {
            visible: root.viewMode === "browse" && root.catalogLoaded
            anchors.fill: parent
            spacing: Style.space(18)

            Item {
              id: pluginListPane
              width: Math.round((parent.width - parent.spacing) * 0.46)
              height: parent.height

              ListView {
                id: pluginList
                anchors.fill: parent
                model: root.displayRows
                clip: true
                spacing: Style.space(6)
                boundsBehavior: Flickable.StopAtBounds

                delegate: BorderSurface {
                  id: pluginRow
                  required property int index
                  required property var modelData

                  readonly property string pluginId: String(modelData.pluginId || "")
                  readonly property string pluginName: String(modelData.pluginName || "")
                  readonly property string description: String(modelData.description || "")
                  readonly property string author: String(modelData.author || "")
                  readonly property string category: String(modelData.category || "")
                  readonly property string kind: String(modelData.kind || "")
                  readonly property string verificationStatus: String(modelData.verificationStatus || "unverified")
                  readonly property bool installed: modelData.installed === true
                  readonly property string viewsText: String(modelData.viewsText || "—")
                  readonly property string starsText: String(modelData.starsText || "0")
                  readonly property string heartsText: String(modelData.heartsText || "—")

                  readonly property bool selectedRow: index === root.selectedIndex
                  width: ListView.view.width
                  height: Style.space(92)
                  color: selectedRow ? root.selectedBackground : "transparent"
                  borderSpec: selectedRow
                    ? Border.flat(root.accent, Math.max(1, Style.normalBorderWidth))
                    : Border.none()
                  radius: Style.cornerRadius

                  Column {
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(4)

                    Row {
                      width: parent.width
                      spacing: Style.space(8)
                      Text {
                        width: parent.width - statusText.width - parent.spacing
                        text: pluginRow.pluginName
                        textFormat: Text.PlainText
                        color: pluginRow.selectedRow ? root.accent : root.foreground
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: root.titleFontSize
                        font.bold: true
                      }
                      Text {
                        id: statusText
                        text: pluginRow.installed ? "INSTALLED" : pluginRow.verificationStatus.toUpperCase()
                        textFormat: Text.PlainText
                        color: pluginRow.installed || pluginRow.verificationStatus === "verified" ? root.accent : root.foreground
                        opacity: pluginRow.installed || pluginRow.verificationStatus === "verified" ? 1 : 0.46
                        font.family: root.fontFamily
                        font.pixelSize: root.captionFontSize
                      }
                    }

                    Text {
                      width: parent.width
                      text: pluginRow.description
                      textFormat: Text.PlainText
                      color: root.foreground
                      opacity: 0.76
                      elide: Text.ElideRight
                      font.family: root.fontFamily
                      font.pixelSize: root.smallFontSize
                    }
                    Row {
                      width: parent.width
                      spacing: Style.space(8)

                      Text {
                        width: Math.max(0, parent.width - metricsText.implicitWidth - parent.spacing)
                        text: "@" + pluginRow.author + "  ·  " + pluginRow.kind + "  ·  " + pluginRow.category
                        textFormat: Text.PlainText
                        color: root.foreground
                        opacity: 0.58
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: root.captionFontSize
                      }

                      Text {
                        id: metricsText
                        text: " " + pluginRow.viewsText + "   " + pluginRow.starsText + "   " + pluginRow.heartsText
                        textFormat: Text.PlainText
                        color: root.foreground
                        opacity: 0.68
                        font.family: root.fontFamily
                        font.pixelSize: root.captionFontSize
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.select(pluginRow.index)
                    onClicked: root.select(pluginRow.index)
                  }
                }
              }

              Text {
                visible: !root.loading && root.displayRows.length === 0
                anchors.centerIn: parent
                text: "No plugins match this search."
                color: root.foreground
                opacity: 0.58
                font.family: root.fontFamily
                font.pixelSize: root.titleFontSize
              }
            }

            Rectangle {
              id: contentDivider
              width: Math.max(1, Style.normalBorderWidth)
              height: parent.height
              color: Util.alpha(root.border, 0.3)
            }

            Item {
              id: browseDetailPane
              width: parent.width - pluginListPane.width - contentDivider.width - parent.spacing * 2
              height: parent.height

              Flickable {
                visible: root.selectedPlugin !== null
                anchors.fill: parent
                contentWidth: width
                contentHeight: browseDetailColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                  id: browseDetailColumn
                  width: parent.width
                  spacing: Style.space(12)

                  BorderSurface {
                    id: previewFrame
                    readonly property bool portraitImage: detailPreview.status === Image.Ready
                      && detailPreview.sourceSize.height > detailPreview.sourceSize.width * 1.15
                    // Only render the frame when the selected plugin actually
                    // has a screenshot that loaded; otherwise show nothing.
                    visible: root.selectedPlugin !== null
                      && root.selectedPlugin.previewImage !== ""
                      && detailPreview.status !== Image.Error
                    width: parent.width
                    height: portraitImage
                      ? Math.min(Style.space(400), browseDetailPane.height * 0.58)
                      : Math.min(Style.space(270), browseDetailPane.height * 0.4)
                    color: Util.alpha(root.foreground, 0.035)
                    borderSpec: Border.flat(Util.alpha(root.border, 0.25), Math.max(1, Style.normalBorderWidth))
                    radius: Style.cornerRadius
                    clip: true

                  Image {
                    id: detailPreview
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    source: root.previewPath
                    visible: source.toString() !== ""
                    asynchronous: true
                    // Every plugin's preview is fetched to the same on-disk
                    // path, so QML's pixmap cache would keep serving the first
                    // image it decoded for that URL. Disable it to re-read the
                    // freshly downloaded file on each selection.
                    cache: false
                    fillMode: Image.PreserveAspectFit
                  }
                  }

                Row {
                  width: parent.width
                  spacing: Style.space(10)
                  Text {
                    width: parent.width - verificationBadge.width - parent.spacing
                    text: root.selectedPlugin ? root.selectedPlugin.pluginName : ""
                    textFormat: Text.PlainText
                    color: root.foreground
                    wrapMode: Text.WordWrap
                    font.family: root.fontFamily
                    font.pixelSize: root.displayFontSize
                    font.bold: true
                  }
                  BorderSurface {
                    id: verificationBadge
                    width: badgeText.implicitWidth + Style.space(16)
                    height: Style.space(28)
                    color: root.selectedPlugin && root.selectedPlugin.verificationStatus === "verified"
                      ? Util.alpha(root.accent, 0.16)
                      : Util.alpha(root.foreground, 0.06)
                    borderSpec: Border.flat(root.selectedPlugin && root.selectedPlugin.verificationStatus === "verified"
                      ? root.accent : Util.alpha(root.foreground, 0.32), Math.max(1, Style.normalBorderWidth))
                    radius: Style.cornerRadius
                    Text {
                      id: badgeText
                      anchors.centerIn: parent
                      text: root.selectedPlugin ? root.selectedPlugin.verificationStatus.toUpperCase() : ""
                      textFormat: Text.PlainText
                      color: root.selectedPlugin && root.selectedPlugin.verificationStatus === "verified" ? root.accent : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: root.captionFontSize
                    }
                  }
                }

                Text {
                  width: parent.width
                  text: root.selectedPlugin ? root.selectedPlugin.description : ""
                  textFormat: Text.PlainText
                  color: root.foreground
                  opacity: 0.8
                  wrapMode: Text.WordWrap
                  font.family: root.fontFamily
                  font.pixelSize: root.bodyFontSize
                }
                Text {
                  width: parent.width
                  text: root.selectedPlugin
                    ? "by " + root.selectedPlugin.author + "  ·  " + root.selectedPlugin.kind + "  ·  " + root.selectedPlugin.category
                    : ""
                  textFormat: Text.PlainText
                  color: root.foreground
                  opacity: 0.64
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: root.captionFontSize
                }
                Text {
                  width: parent.width
                  visible: root.selectedPlugin && root.selectedPlugin.tagsText !== ""
                  text: root.selectedPlugin ? root.selectedPlugin.tagsText : ""
                  textFormat: Text.PlainText
                  color: root.accent
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: root.captionFontSize
                }
                Text {
                  width: parent.width
                  visible: root.selectedPlugin && root.selectedPlugin.listingCommit !== ""
                  text: root.selectedPlugin
                    ? "Listed commit " + MarketplaceModel.shortCommit(root.selectedPlugin.listingCommit)
                      + (root.selectedPlugin.upstreamCommit && root.selectedPlugin.upstreamCommit !== root.selectedPlugin.listingCommit
                        ? "  ·  upstream " + MarketplaceModel.shortCommit(root.selectedPlugin.upstreamCommit)
                        : "")
                    : ""
                  textFormat: Text.PlainText
                  color: root.foreground
                  opacity: 0.52
                  font.family: root.fontFamily
                  font.pixelSize: root.captionFontSize
                }

                Text {
                  width: parent.width
                  text: "Verification is commit-bound and is not a security audit."
                  color: root.foreground
                  opacity: 0.52
                  wrapMode: Text.WordWrap
                  font.family: root.fontFamily
                  font.pixelSize: root.captionFontSize
                }

                Item { width: 1; height: Style.space(2) }

                Text {
                  width: parent.width
                  visible: root.selectedPlugin && root.selectedPlugin.installNote !== ""
                  text: root.selectedPlugin ? root.selectedPlugin.installNote : ""
                  textFormat: Text.PlainText
                  color: root.foreground
                  opacity: 0.64
                  wrapMode: Text.WordWrap
                  font.family: root.fontFamily
                  font.pixelSize: root.captionFontSize
                }

                Row {
                  width: parent.width
                  spacing: Style.space(10)
                  Button {
                    text: "View repository"
                    bordered: true
                    focusable: true
                    foreground: root.foreground
                    accent: root.accent
                    fontSize: root.bodyFontSize
                    onClicked: if (root.selectedPlugin && MarketplaceModel.repoIsSafe(root.selectedPlugin.repo)) Qt.openUrlExternally(root.selectedPlugin.repo)
                  }
                  Button {
                    text: root.selectedPlugin && root.selectedPlugin.installAvailable && !root.installedRequestParsed
                      ? "Status unavailable"
                      : root.selectedPlugin && root.selectedPlugin.installed
                        ? "Installed"
                      : root.selectedPlugin && (root.selectedPlugin.pluginId === root.installingPluginId
                          || root.selectedPlugin.pluginId === root.installHandoffPluginId)
                        ? "Installing…"
                        : root.selectedPlugin && root.selectedPlugin.pluginId === root.failedPluginId
                          ? "Retry install"
                      : root.selectedPlugin && root.selectedPlugin.installAvailable
                        ? root.pluginReplacesBar(root.selectedPlugin) ? "Install" : "Install & enable"
                        : "View setup guide"
                    bordered: true
                    focusable: true
                    selected: root.selectedPlugin && root.selectedPlugin.installAvailable && !root.selectedPlugin.installed
                    enabled: root.selectedPlugin !== null && !root.installBusy
                      && !root.selectedPlugin.installed
                      && (!root.selectedPlugin.installAvailable || root.installedRequestParsed)
                    foreground: root.foreground
                    accent: root.accent
                    fontSize: root.bodyFontSize
                    onClicked: root.handleInstallAction(root.selectedPlugin)
                  }
                }
                }
              }
            }
          }

          Text {
            visible: root.viewMode !== "browse"
              && (installedProc.running || root.viewMode === "updates" && updateCheckProc.running)
            anchors.centerIn: parent
            text: root.viewMode === "updates" && updateCheckProc.running
              ? "Checking for plugin updates…" : "Loading plugins…"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.titleFontSize
          }

          Row {
            visible: root.viewMode !== "browse" && root.installedLoaded
              && (root.viewMode !== "updates" || !updateCheckProc.running)
            anchors.fill: parent
            spacing: 0

            Item {
              id: managedListPane
              readonly property real tableContentWidth: width - Style.space(20)
              readonly property real kindColumnWidth: root.compactManagementTable ? 0 : tableContentWidth * 0.13
              readonly property real sourceColumnWidth: root.compactManagementTable ? 0 : tableContentWidth * 0.16
              readonly property real statusColumnWidth: root.compactManagementTable
                ? Style.space(84) : tableContentWidth * 0.11
              readonly property real actionsColumnWidth: root.compactManagementTable
                ? Style.space(210) : tableContentWidth * 0.31
              readonly property real pluginColumnWidth: tableContentWidth - kindColumnWidth - sourceColumnWidth
                - statusColumnWidth - actionsColumnWidth
              width: parent.width
              height: parent.height

              Rectangle {
                id: managementTableHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Style.space(34)
                color: Util.alpha(root.foreground, 0.035)

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)

                  Text {
                    width: managedListPane.pluginColumnWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PLUGIN"
                    color: root.foreground
                    opacity: 0.55
                    font.family: root.fontFamily
                    font.pixelSize: root.captionFontSize
                    font.bold: true
                  }
                  Text {
                    visible: !root.compactManagementTable
                    width: managedListPane.kindColumnWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TYPE"
                    color: root.foreground
                    opacity: 0.55
                    font.family: root.fontFamily
                    font.pixelSize: root.captionFontSize
                    font.bold: true
                  }
                  Text {
                    visible: !root.compactManagementTable
                    width: managedListPane.sourceColumnWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SOURCE"
                    color: root.foreground
                    opacity: 0.55
                    font.family: root.fontFamily
                    font.pixelSize: root.captionFontSize
                    font.bold: true
                  }
                  Text {
                    width: managedListPane.statusColumnWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "STATUS"
                    color: root.foreground
                    opacity: 0.55
                    font.family: root.fontFamily
                    font.pixelSize: root.captionFontSize
                    font.bold: true
                  }
                  Text {
                    width: managedListPane.actionsColumnWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ACTIONS"
                    color: root.foreground
                    opacity: 0.55
                    horizontalAlignment: Text.AlignRight
                    font.family: root.fontFamily
                    font.pixelSize: root.captionFontSize
                    font.bold: true
                  }
                }

                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: Math.max(1, Style.normalBorderWidth)
                  color: Util.alpha(root.border, 0.45)
                }
              }

              ListView {
                id: managedList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: managementTableHeader.bottom
                anchors.bottom: parent.bottom
                model: root.viewMode === "updates" ? root.updateRows : root.managedRows
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                  id: managedRow
                  required property int index
                  required property var modelData

                  width: ListView.view.width
                  height: Style.space(root.compactManagementTable ? 72 : 66)
                  color: index % 2 === 0 ? Util.alpha(root.foreground, 0.018) : "transparent"

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)

                    Column {
                      width: managedListPane.pluginColumnWidth
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)
                      Text {
                        width: parent.width - Style.space(8)
                        text: String(managedRow.modelData.pluginName || "")
                        color: root.foreground
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: root.bodyFontSize
                        font.bold: true
                      }
                      Text {
                        width: parent.width - Style.space(8)
                        text: root.viewMode === "updates"
                          ? String(managedRow.modelData.pluginId || "") + "  ·  "
                            + MarketplaceModel.shortCommit(managedRow.modelData.localCommit) + " → "
                            + MarketplaceModel.shortCommit(managedRow.modelData.remoteCommit)
                          : root.compactManagementTable
                          ? String(managedRow.modelData.pluginId || "") + "  ·  " + String(managedRow.modelData.kindsText || "Plugin")
                          : String(managedRow.modelData.pluginId || "")
                        color: root.foreground
                        opacity: 0.46
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: root.captionFontSize
                      }
                    }

                    Text {
                      visible: !root.compactManagementTable
                      width: managedListPane.kindColumnWidth
                      anchors.verticalCenter: parent.verticalCenter
                      text: String(managedRow.modelData.kindsText || "Plugin")
                      color: root.foreground
                      opacity: 0.64
                      elide: Text.ElideRight
                      font.family: root.fontFamily
                      font.pixelSize: root.captionFontSize
                    }

                    Text {
                      visible: !root.compactManagementTable
                      width: managedListPane.sourceColumnWidth
                      anchors.verticalCenter: parent.verticalCenter
                      text: {
                        if (root.viewMode === "updates") return "Git"
                        if (managedRow.modelData.firstParty) return "Built-in"
                        if (root.gitManagedIds[managedRow.modelData.pluginId] === true) return "Git"
                        if (root.gitManagedIds[managedRow.modelData.pluginId] === false) return "Manual"
                        return "Checking…"
                      }
                      color: root.foreground
                      opacity: 0.64
                      font.family: root.fontFamily
                      font.pixelSize: root.captionFontSize
                    }

                    Text {
                      width: managedListPane.statusColumnWidth
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.viewMode === "updates" ? "AVAILABLE"
                        : managedRow.modelData.enabled ? "ENABLED" : "DISABLED"
                      color: root.viewMode === "updates" || managedRow.modelData.enabled
                        ? root.accent : root.foreground
                      opacity: root.viewMode === "updates" || managedRow.modelData.enabled ? 1 : 0.5
                      font.family: root.fontFamily
                      font.pixelSize: root.captionFontSize
                      font.bold: true
                    }

                    Item {
                      width: managedListPane.actionsColumnWidth
                      height: parent.height

                      Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(6)

                        Text {
                          visible: managedRow.modelData.pluginId === "io.yasino55.omarchy-plugin-marketplace"
                            || managedRow.modelData.kinds.indexOf("bar") !== -1
                          anchors.verticalCenter: parent.verticalCenter
                          text: "CLI only"
                          color: root.foreground
                          opacity: 0.45
                          font.family: root.fontFamily
                          font.pixelSize: root.captionFontSize
                        }

                        Button {
                          visible: root.viewMode === "manage"
                            && managedRow.modelData.pluginId !== "io.yasino55.omarchy-plugin-marketplace"
                            && managedRow.modelData.kinds.indexOf("bar") === -1
                            && (!managedRow.modelData.enabled || managedRow.modelData.canDisable)
                          width: Style.space(root.compactManagementTable ? 68 : 78)
                          height: Style.space(32)
                          text: managedRow.modelData.pluginId === root.managingPluginId
                            && (root.managingAction === "enable" || root.managingAction === "disable")
                            ? (root.managingAction === "enable" ? "Enabling…" : "Disabling…")
                            : managedRow.modelData.enabled ? "Disable" : "Enable"
                          bordered: true
                          focusable: true
                          selected: !managedRow.modelData.enabled
                          enabled: root.installedRequestParsed && !root.operationRunning
                          foreground: root.foreground
                          accent: root.accent
                          fontSize: root.bodyFontSize
                          onClicked: root.requestManagementAction(managedRow.modelData.enabled ? "disable" : "enable",
                            managedRow.modelData)
                        }

                        Button {
                          visible: !managedRow.modelData.firstParty
                            && managedRow.modelData.pluginId !== "io.yasino55.omarchy-plugin-marketplace"
                            && !managedRow.modelData.active
                            && (root.viewMode === "updates"
                              || root.gitManagedIds[managedRow.modelData.pluginId] === true)
                          width: Style.space(root.compactManagementTable ? 58 : 72)
                          height: Style.space(32)
                          text: managedRow.modelData.pluginId === root.managingPluginId
                            && root.managingAction === "update" ? "Checking…" : "Update"
                          bordered: true
                          focusable: true
                          selected: root.viewMode === "updates"
                          enabled: root.installedRequestParsed && !root.operationRunning
                          foreground: root.foreground
                          accent: root.accent
                          fontSize: root.bodyFontSize
                          onClicked: root.requestManagementAction("update", managedRow.modelData)
                        }

                        Button {
                          visible: root.viewMode === "manage" && !managedRow.modelData.firstParty
                            && managedRow.modelData.pluginId !== "io.yasino55.omarchy-plugin-marketplace"
                            && !managedRow.modelData.active
                          width: Style.space(root.compactManagementTable ? 58 : 72)
                          height: Style.space(32)
                          text: managedRow.modelData.pluginId === root.managingPluginId
                            && root.managingAction === "remove" ? "Removing…" : "Remove"
                          bordered: true
                          focusable: true
                          enabled: root.installedRequestParsed && !root.operationRunning
                          foreground: Color.urgent
                          accent: Color.urgent
                          fontSize: root.bodyFontSize
                          onClicked: root.requestManagementAction("remove", managedRow.modelData)
                        }
                      }
                    }
                  }

                  Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(1, Style.normalBorderWidth)
                    color: Util.alpha(root.border, 0.2)
                  }
                }
              }

              Text {
                visible: (root.viewMode === "updates" ? root.updateRows.length : root.managedRows.length) === 0
                anchors.centerIn: parent
                text: root.viewMode === "updates"
                  ? !root.updateCheckLoaded
                    ? "Update status is unavailable."
                    : root.updateCount > 0
                      ? "No updates match this search."
                    : root.updateCheckedCount === 0
                      ? "No supported Git plugins to check."
                    : root.updateErrorCount > 0
                      ? "No updates found. " + root.updateErrorCount
                        + (root.updateErrorCount === 1 ? " plugin could not be checked." : " plugins could not be checked.")
                      : "All checked Git plugins are up to date."
                  : "No plugins match this filter."
                color: root.foreground
                opacity: 0.58
                font.family: root.fontFamily
                font.pixelSize: root.titleFontSize
              }
            }

          }
        }

        Text {
          width: parent.width
          height: Style.space(20)
          text: root.statusMessage || (root.errorMessage && root.catalogLoaded
            ? root.errorMessage
            : root.viewMode !== "browse"
              ? "Esc closes  ·  Tab moves between actions"
              : "Esc closes  ·  ↑/↓ selects")
          color: root.statusMessage.indexOf("failed") !== -1 || root.errorMessage ? Color.urgent : root.foreground
          opacity: root.statusMessage || root.errorMessage ? 1 : 0.52
          elide: Text.ElideRight
          font.family: root.fontFamily
          font.pixelSize: root.captionFontSize
        }
      }
    }
  }
}
