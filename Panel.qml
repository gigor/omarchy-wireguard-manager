import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.alansnchz0.wireguard-manager"
  ipcTarget: "io.github.alansnchz0.wireguard-manager"
  property var anchorItem: null
  property var hostWidget: null
  property int cursorIndex: 0
  property bool cursorActive: false
  readonly property var barIdentity: hostWidget || root
  readonly property bool statusStale: wg.stale
  // Shared with the bar label (BarWidget.qml) so there is one status source.
  readonly property var connectionModel: wg

  // Same palette and font as the built-in Tailscale panel.
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // One line under the header: the password prompt while an action runs,
  // otherwise the last failure.
  readonly property bool operationRunning: runner.operationState !== "idle"
  readonly property string statusLine: operationRunning ? runner.errorMessage : (wg.operationError || wg.errorMessage)

  function toggleRecord(index) {
    var record = wg.connections.get(index)
    if (!record || !record.known ||
        root.statusStale ||
        (record.operationState !== "idle" && record.operationState !== "error")) return
    var action = record.active ? "down" : "up"
    wg.markOperation(record.name, action === "up" ? "starting" : "stopping")
    runner.toggle(record, action)
  }

  function setCursor(index) {
    cursorActive = true
    cursorIndex = index
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    wg.refresh()
  }

  WireGuardModel { id: wg }
  WireGuardPrivilegedRunner {
    id: runner
    onFinished: function(name, action, success, errorMessage) {
      if (!success) {
        wg.operationError = errorMessage
        wg.markOperation(name, "error")
      } else {
        wg.markOperation(name, action === "up" ? "starting" : "stopping")
      }
      wg.refresh()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") wg.refresh()
        else if (text === "t" || text === "T") root.toggleRecord(root.cursorIndex)
      }
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.cursorIndex = Math.max(0, Math.min(wg.connections.count - 1, root.cursorIndex + dy))
      }
      onActivateRequested: if (root.cursorActive) root.toggleRecord(root.cursorIndex)

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        Repeater {
          model: wg.connections

          Column {
            id: entry
            required property int index
            required property string name
            required property bool active
            required property bool known
            required property string operationState

            // The hero's icon and switch are built inside PanelHero, so they
            // reach panel state through these rather than through `root`.
            readonly property bool operating: operationState === "starting" || operationState === "stopping"
            readonly property bool statusUnknown: (!known || root.statusStale) && !wg.loading
            readonly property bool switchEnabled: known && !root.statusStale &&
              (operationState === "idle" || operationState === "error") &&
              !root.operationRunning
            readonly property bool switchBusy: operating || root.operationRunning
            readonly property bool hasCursor: root.cursorActive && root.cursorIndex === index
            readonly property color iconColor: active ? root.foreground : root.dim
            function toggle() { root.toggleRecord(index) }
            function focusRow() { root.setCursor(index) }

            width: column.width
            spacing: Style.space(12)

            PanelSeparator {
              visible: entry.index > 0
              foreground: root.foreground
            }

            PanelHero {
              id: hero
              width: parent.width
              title: entry.name
              meta: entry.operationState === "starting" ? "Connecting"
                : entry.operationState === "stopping" ? "Disconnecting"
                : entry.operationState === "error" ? "Failed"
                : entry.statusUnknown ? "Status unknown"
                : entry.active ? "Connected" : "Disconnected"
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: entry.active ? 1.0 : 0.5
              iconComponent: Component {
                Text {
                  text: "󰦝"
                  color: entry.iconColor
                  font.family: hero.fontFamily
                  font.pixelSize: Style.font.display
                }
              }
              trailingControl: Component {
                ToggleSwitch {
                  id: powerSwitch
                  checked: entry.active
                  busy: entry.switchBusy
                  interactive: entry.switchEnabled
                  hasCursor: entry.hasCursor
                  foreground: hero.foreground
                  onHovered: function(on) { if (on) entry.focusRow() }
                  onToggled: entry.toggle()
                  Accessible.name: (entry.active ? "Disable " : "Enable ") + entry.name

                  PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: (entry.active ? "Turn off " : "Turn on ") + entry.name
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.statusLine !== ""
          width: parent.width
          text: root.statusLine
          color: root.operationRunning ? root.dim : root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          textFormat: Text.PlainText
          visible: wg.connections.count === 0
          width: parent.width
          text: "No WireGuard connections configured."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
