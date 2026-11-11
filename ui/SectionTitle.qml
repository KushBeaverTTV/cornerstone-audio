import QtQuick
import qs.Ui
import qs.Commons

// A section's small-caps title with an optional reading on the right (a
// volume percentage).
Item {
  id: title

  property QtObject bar: null
  property string text: ""
  property string reading: ""
  property bool readingFaded: false

  implicitHeight: Math.max(heading.implicitHeight, value.implicitHeight)

  PanelSectionHeader {
    id: heading
    text: title.text
    foreground: title.bar.foreground
    fontFamily: title.bar.fontFamily
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
  }

  PlainLabel {
    id: value
    bar: title.bar
    tier: "caption"
    dim: true
    font.bold: true
    text: title.reading
    opacity: title.readingFaded ? 0.5 : 1
    anchors.right: parent.right
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
  }
}
