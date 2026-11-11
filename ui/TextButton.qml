import QtQuick
import qs.Ui
import qs.Commons

// A quiet one-line button ("Show 8 more apps"), a cursor stop like any row.
CursorSurface {
  id: button

  property QtObject bar: null
  property string text: ""

  signal clicked()
  signal pointed()

  foreground: bar.foreground
  implicitHeight: words.implicitHeight + Style.space(10)

  PlainLabel {
    id: words
    bar: button.bar
    text: button.text
    dim: true
    anchors.left: parent.left
    anchors.leftMargin: Style.space(36)
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: if (containsMouse) button.pointed()
    onClicked: button.clicked()
  }
}
