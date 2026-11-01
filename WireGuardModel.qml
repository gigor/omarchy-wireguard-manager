import QtQuick
import Quickshell.Io
import "WireGuardModel.js" as Model

Item {
  id: root
  visible: false
  width: 0
  height: 0

  readonly property string configDir: "/etc/wireguard"
  property ListModel connections: ListModel {}
  property bool loading: false
  property bool stale: false
  property string errorMessage: ""
  property string lastUpdated: ""
  property string operationError: ""
  property int activeCount: 0
  property string pendingOperationName: ""
  property string pendingOperationAction: ""
  signal refreshed()

  function refresh() {
    if (loading) return
    loading = true
    errorMessage = ""
    stale = true
    activeCount = 0
    for (var i = 0; i < connections.count; i++) connections.setProperty(i, "known", false)
    setRecords(Model.connectionNames())
    refreshStatus()
  }

  function refreshStatus() {
    statusProcess.command = Model.statusCommand()
    statusProcess.running = true
  }

  function setRecords(names) {
    var old = {}
    for (var i = 0; i < connections.count; i++) {
      var row = connections.get(i)
      old[row.name] = row
    }
    connections.clear()
    for (var j = 0; j < names.length; j++) {
      var previous = old[names[j]] || {}
      connections.append({
        name: names[j],
        configPath: Model.configPath(names[j]),
        active: previous.active === true,
        known: previous.known === true,
        operationState: previous.operationState || "idle"
      })
    }
  }

  function applyStatus(raw) {
    var active = Model.parseInterfaces(raw)
    var count = 0
    for (var i = 0; i < connections.count; i++) {
      var row = connections.get(i)
      var isActive = active[row.name] === true
      if (isActive) count++
      connections.setProperty(i, "active", isActive)
      connections.setProperty(i, "known", true)
      if (row.operationState === "starting" && isActive)
        connections.setProperty(i, "operationState", "idle")
      else if (row.operationState === "stopping" && !isActive)
        connections.setProperty(i, "operationState", "idle")
      if (row.name === pendingOperationName &&
          ((pendingOperationAction === "up" && isActive) ||
           (pendingOperationAction === "down" && !isActive))) {
        confirmationTimeout.stop()
        pendingOperationName = ""
        pendingOperationAction = ""
        operationError = ""
      }
    }
    activeCount = count
    stale = false
    lastUpdated = Qt.formatDateTime(new Date(), "HH:mm:ss")
    loading = false
    refreshed()
  }

  function markOperation(name, state) {
    if (state === "error") {
      confirmationTimeout.stop()
      pendingOperationName = ""
      pendingOperationAction = ""
    }
    for (var i = 0; i < connections.count; i++) {
      if (connections.get(i).name === name) {
        connections.setProperty(i, "operationState", state)
        if (state === "starting" || state === "stopping") {
          pendingOperationName = name
          pendingOperationAction = state === "starting" ? "up" : "down"
          confirmationTimeout.restart()
        }
        return
      }
    }
  }

  Timer {
    id: confirmationTimeout
    interval: 10000
    repeat: false
    onTriggered: {
      if (!root.pendingOperationName) return
      for (var i = 0; i < root.connections.count; i++) {
        if (root.connections.get(i).name === root.pendingOperationName) {
          root.connections.setProperty(i, "operationState", "error")
          root.connections.setProperty(i, "known", false)
          break
        }
      }
      root.operationError = "WireGuard status did not confirm the requested action in time."
      root.pendingOperationName = ""
      root.pendingOperationAction = ""
    }
  }

  Process {
    id: statusProcess
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    stderr: StdioCollector { id: statusError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.loading = false
        root.stale = true
        root.activeCount = 0
        for (var i = 0; i < root.connections.count; i++) root.connections.setProperty(i, "known", false)
        root.errorMessage = statusError.text && statusError.text.trim()
          ? "WireGuard status unavailable: " + statusError.text.trim()
          : "WireGuard status unavailable."
        return
      }
      root.applyStatus(statusOutput.text)
    }
  }
}
