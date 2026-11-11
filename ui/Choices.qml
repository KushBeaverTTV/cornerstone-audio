import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "../Audio.js" as Audio

// The open list under an app: the places it can go. Each choice is
// { key, glyph, label, current }; the current one carries a check mark. Every
// choice is a cursor stop of its own, keyed by `key`.
Column {
  id: list

  property QtObject bar: null
  property var choices: []
  // The panel cursor's key, so the choice under it can be drawn so.
  property string cursorKey: ""
  property real indent: Style.space(30)

  signal chosen(var choice)
  signal pointed(var choice)
  // a choice took the keyboard cursor; the panel scrolls it into view
  signal revealed(Item item)

  spacing: 0

  Repeater {
    model: list.choices

    CursorSurface {
      id: option
      required property var modelData

      width: list.width
      implicitHeight: label.implicitHeight + Style.space(10)
      foreground: list.bar.foreground
      hasCursor: list.cursorKey !== "" && list.cursorKey === modelData.key
      onHasCursorChanged: if (hasCursor) list.revealed(option)

      PlainLabel {
        id: mark
        bar: list.bar
        text: option.modelData.current ? Audio.GLYPH.check : option.modelData.glyph
        color: option.modelData.current ? Commons.Color.accent : mark.ink
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideNone
        anchors.left: parent.left
        anchors.leftMargin: list.indent
        anchors.verticalCenter: parent.verticalCenter
      }

      PlainLabel {
        id: label
        bar: list.bar
        text: option.modelData.label
        font.bold: option.modelData.current
        anchors.left: mark.right
        anchors.leftMargin: Style.space(8)
        anchors.right: parent.right
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) list.pointed(option.modelData)
        onClicked: list.chosen(option.modelData)
      }
    }
  }
}
