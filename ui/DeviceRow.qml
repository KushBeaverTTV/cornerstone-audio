import QtQuick
import qs.Ui
import qs.Commons

// One output or input device. Click makes it the default; the default one is
// drawn as current. A name too long for the row shows whole on hover.
CursorSurface {
  id: device

  property QtObject bar: null
  property string glyph: ""
  property string label: ""
  property bool active: false

  signal chosen()
  signal pointed()

  current: active
  foreground: bar.foreground
  implicitHeight: name.implicitHeight + Style.spacing.xl

  PlainLabel {
    id: icon
    bar: device.bar
    tier: "title"
    text: device.glyph
    width: Style.space(22)
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideNone
    anchors.left: parent.left
    anchors.leftMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
  }

  PlainLabel {
    id: name
    bar: device.bar
    text: device.label
    font.bold: device.active
    anchors.left: icon.right
    anchors.leftMargin: Style.space(8)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: if (containsMouse) device.pointed()
    onClicked: device.chosen()
  }

  PanelToolTip {
    visible: mouse.containsMouse && name.truncated
    text: device.label
    fontFamily: device.bar.fontFamily
  }
}
