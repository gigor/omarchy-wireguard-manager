import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "WireGuardModel.js" as Model

Panel {
  id: root
  moduleName: "io.github.alansnchz0.wireguard-manager"
  ipcTarget: "io.github.alansnchz0.wireguard-manager"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property bool statusStale: model.stale

  function open() { controller.show(); model.refresh() }
  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() { close() }
  function toggleRecord(index) {
    var record = model.connections.get(index)
    if (!record || !record.known ||
        root.statusStale ||
        (record.operationState !== "idle" && record.operationState !== "error")) return
    var action = record.active ? "down" : "up"
    model.markOperation(record.name, action === "up" ? "starting" : "stopping")
    runner.toggle(record, action)
  }

  WireGuardModel { id: model }
  WireGuardPrivilegedRunner {
    id: runner
    onFinished: function(name, action, success, errorMessage) {
      if (!success) {
        model.operationError = errorMessage
        model.markOperation(name, "error")
      } else {
        model.markOperation(name, action === "up" ? "starting" : "stopping")
      }
      model.refresh()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(360))
    contentHeight: popup.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(text) { if (text === "r" || text === "R") model.refresh() }
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) connectionList.currentIndex = Math.max(0, Math.min(model.connections.count - 1, connectionList.currentIndex + dy))
      }
      onActivateRequested: if (connectionList.currentIndex >= 0) root.toggleRecord(connectionList.currentIndex)

      ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Style.space(16)
        spacing: Style.space(10)

        Text {
          text: "WIREGUARD"
          color: root.barForeground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }
        Text {
          Layout.fillWidth: true
          text: model.loading ? "Refreshing…" : (model.errorMessage || (model.stale ? "Status is stale" : "Ready"))
          color: model.errorMessage || model.stale ? Color.urgent : root.barForeground
          elide: Text.ElideRight
        }
        PanelSeparator {
          foreground: root.barForeground
        }
        Text {
          visible: runner.operationState !== "idle" || model.operationError !== ""
          Layout.fillWidth: true
          text: runner.operationState !== "idle" ? runner.errorMessage : model.operationError
          color: Color.urgent
          wrapMode: Text.Wrap
        }
        PanelSeparator {
          visible: runner.operationState !== "idle" || model.operationError !== ""
          foreground: root.barForeground
        }
        ListView {
          id: connectionList
          Layout.fillWidth: true
          Layout.fillHeight: true
          // ListView does not provide an implicit height for ColumnLayout.
          // Keep enough room for an empty-state message and the discovered
          // rows, while still preventing a large config directory from
          // pushing the popup beyond its fitted height.
          readonly property int rowHeight: Style.space(56)
          implicitHeight: Math.min(Math.max(contentHeight, Style.space(40)), Style.space(240))
          Layout.preferredHeight: implicitHeight
          Layout.minimumHeight: Style.space(40)
          height: implicitHeight
          spacing: Style.space(6)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          model: model.connections
          currentIndex: count > 0 ? 0 : -1
          delegate: CursorSurface {
            required property int index
            required property string name
            required property bool active
            required property bool known
            required property string operationState
            width: connectionList.width
            height: connectionList.rowHeight
            implicitHeight: connectionList.rowHeight
            hasCursor: ListView.isCurrentItem
            current: ListView.isCurrentItem
            foreground: root.barForeground
            accent: Color.accent

            RowLayout {
              id: rowContent
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(2)

                Text {
                  Layout.fillWidth: true
                  text: name
                  color: root.barForeground
                  font.family: Style.font.family
                  elide: Text.ElideRight
                }
                Text {
                  Layout.fillWidth: true
                  text: operationState === "starting" ? "Starting" : operationState === "stopping" ? "Stopping" : operationState === "error" ? "Failed" : (!known || root.statusStale) ? "Unknown" : active ? "Active" : "Inactive"
                  color: operationState === "error" || !known || root.statusStale ? Color.urgent : root.barForeground
                  opacity: 0.8
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }

              ToggleSwitch {
                id: connectionToggle
                checked: active
                busy: operationState === "starting" || operationState === "stopping" || runner.operationState !== "idle"
                interactive: known && !root.statusStale &&
                  (operationState === "idle" || operationState === "error") &&
                  runner.operationState === "idle"
                hasCursor: ListView.isCurrentItem
                foreground: root.barForeground
                accent: Color.accent
                onToggled: root.toggleRecord(index)
                Accessible.name: (active ? "Disable " : "Enable ") + name
              }
            }
          }
          footer: Text {
            width: connectionList.width
            visible: connectionList.count === 0 && !model.loading && !model.errorMessage
            text: "No WireGuard .conf files found."
            color: root.barForeground
          }
        }
      }
    }
  }
}
