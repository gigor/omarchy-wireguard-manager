import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.alansnchz0.wireguard-manager"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
  readonly property string summary: "WG"
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.settings = root.settings
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function togglePanel() { toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  WireGuardModel { id: model }
  Component.onCompleted: model.refresh()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.summary
    labelVisible: !root.vertical
    hasVisualContent: true
    tooltipText: model.stale ? "WireGuard: unavailable" : ("WireGuard: " + model.activeCount + " active")
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.MiddleButton) model.refresh()
    }
  }
}
