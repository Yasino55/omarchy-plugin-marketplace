import QtQuick
import qs.Ui

BarWidget {
  id: root

  moduleName: "jason.marketplace"
  readonly property bool opened: marketplaceLoader.item
    ? marketplaceLoader.item.opened === true
    : false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open(payloadJson) {
    if (marketplaceLoader.item) marketplaceLoader.item.open(payloadJson || "{}")
  }

  function close() {
    if (marketplaceLoader.item) marketplaceLoader.item.close()
  }

  function toggle() {
    if (marketplaceLoader.item) marketplaceLoader.item.toggle()
  }

  Loader {
    id: marketplaceLoader
    active: true
    source: Qt.resolvedUrl("Marketplace.qml")
    visible: false
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Open Plugin Marketplace"

    iconComponent: Component {
      Item {
        MarketplaceIcon {
          anchors.centerIn: parent
          iconSize: Math.min(parent.width, parent.height) * 0.82
          color: button.foreground
        }
      }
    }

    onPressed: function(buttonCode) {
      root.toggle()
    }
  }
}
