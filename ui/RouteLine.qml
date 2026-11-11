import QtQuick
import qs.Commons
import "../Audio.js" as Audio

// The line under an app saying where it goes ("moto buds+", "Default input").
// Clicking it opens or closes the list of other places.
Item {
  id: line

  property QtObject bar: null
  property string glyph: ""
  property string label: ""
  property bool open: false
  property real indent: Style.space(30)

  signal toggled()

  implicitHeight: words.implicitHeight + Style.space(6)

  PlainLabel {
    id: words
    bar: line.bar
    text: line.glyph + "  " + line.label + "  " + (line.open ? Audio.GLYPH.open : Audio.GLYPH.closed)
    font.bold: line.open
    opacity: line.open ? 1 : 0.7
    anchors.left: parent.left
    anchors.leftMargin: line.indent
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: line.toggled()
  }
}
