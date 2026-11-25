import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "../Audio.js" as Audio

// An app that uses a microphone, whether or not it is listening now, and the
// mic chosen for it. The choice holds from the next time it records.
CursorSurface {
  id: mic

  property QtObject bar: null
  property string name: ""
  property string iconSource: ""
  property bool live: false
  property string routeGlyph: ""
  property string routeLabel: ""
  property bool open: false
  property var choices: []
  property string cursorKey: ""

  signal pointed()
  signal routeToggled()
  signal choicePointed(var choice)
  signal choiceChosen(var choice)
  signal choiceRevealed(Item item)

  foreground: bar.foreground
  implicitHeight: body.implicitHeight + Style.spacing.md

  Column {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(6)
    spacing: Style.space(2)

    Column {
      width: parent.width
      spacing: Style.space(2)

      Item {
        width: parent.width
        implicitHeight: Math.max(Style.space(22), title.implicitHeight)

        Item {
          id: glyph
          width: Style.space(22)
          height: Style.space(22)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          Image {
            id: appImg
            anchors.centerIn: parent
            width: Style.space(18)
            height: width
            visible: mic.iconSource !== "" && status === Image.Ready
            source: mic.iconSource
            sourceSize.width: 48
            sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
            opacity: mic.live ? 1 : 0.7
            asynchronous: true
            smooth: true
            mipmap: true
          }

          PlainLabel {
            id: micGlyph
            anchors.centerIn: parent
            visible: !appImg.visible
            bar: mic.bar
            tier: "title"
            text: Audio.GLYPH.mic
            color: mic.live ? Commons.Color.accent : micGlyph.ink
            opacity: mic.live ? 1 : 0.55
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideNone
          }
        }

        PlainLabel {
          id: title
          bar: mic.bar
          text: mic.name
          width: Math.min(implicitWidth, parent.width - glyph.width - Style.space(8) - (listening.visible ? listening.implicitWidth + Style.space(8) : 0))
          anchors.left: glyph.right
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }

        PlainLabel {
          id: listening
          visible: mic.live
          bar: mic.bar
          tier: "caption"
          text: "listening"
          color: Commons.Color.accent
          elide: Text.ElideNone
          anchors.left: title.right
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      RouteLine {
        width: parent.width
        bar: mic.bar
        glyph: mic.routeGlyph
        label: mic.routeLabel
        open: mic.open
        onToggled: mic.routeToggled()
      }

      HoverHandler {
        onHoveredChanged: if (hovered) mic.pointed()
      }
    }

    Choices {
      width: parent.width
      visible: mic.open
      bar: mic.bar
      choices: mic.open ? mic.choices : []
      cursorKey: mic.cursorKey
      onPointed: function(choice) { mic.choicePointed(choice) }
      onChosen: function(choice) { mic.choiceChosen(choice) }
      onRevealed: function(item) { mic.choiceRevealed(item) }
    }
  }
}
