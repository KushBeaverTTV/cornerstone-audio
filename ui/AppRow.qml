import QtQuick
import qs.Ui
import qs.Commons
import "../Audio.js" as Audio

// An app that is playing: mute, name, volume (up to 150%, as PipeWire allows),
// and the output it plays on, with the list of outputs to send it to.
CursorSurface {
  id: app

  property QtObject bar: null
  property string name: ""
  property real volume: 0
  property bool muted: false
  // the media player the shell treats as current
  property bool featured: false
  property string routeGlyph: ""
  property string routeLabel: ""
  property bool open: false
  property var choices: []
  property string cursorKey: ""

  signal pointed()
  signal volumeMoved(real value)
  signal muteToggled()
  signal routeToggled()
  signal choicePointed(var choice)
  signal choiceChosen(var choice)
  signal choiceRevealed(Item item)

  current: featured
  foreground: bar.foreground
  implicitHeight: body.implicitHeight + Style.spacing.xl

  Column {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(6)
    spacing: Style.space(2)

    Column {
      id: main
      width: parent.width
      spacing: Style.space(2)

      Item {
        width: parent.width
        implicitHeight: Math.max(muteGlyph.implicitHeight, title.implicitHeight)

        PlainLabel {
          id: muteGlyph
          bar: app.bar
          tier: "title"
          text: app.muted ? Audio.GLYPH.appMuted : Audio.GLYPH.appOn
          opacity: app.muted ? 0.5 : 1
          width: Style.space(22)
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideNone
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: app.muteToggled()
          }
        }

        PlainLabel {
          id: title
          bar: app.bar
          text: app.name
          font.bold: app.featured
          anchors.left: muteGlyph.right
          anchors.leftMargin: Style.space(8)
          anchors.right: reading.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }

        PlainLabel {
          id: reading
          bar: app.bar
          tier: "caption"
          dim: true
          font.bold: true
          text: Audio.percent(slider.dragging ? slider.liveValue : app.volume)
          opacity: app.muted ? 0.5 : 1
          width: Style.space(40)
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideNone
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      PanelSlider {
        id: slider
        bar: app.bar
        width: parent.width
        minimum: 0
        maximum: 1.5
        step: 0.05
        value: app.volume
        opacity: app.muted ? 0.5 : 1
        onMoved: function(v) { app.volumeMoved(v) }
        onRightClicked: app.muteToggled()
      }

      RouteLine {
        width: parent.width
        bar: app.bar
        glyph: app.routeGlyph
        label: app.routeLabel
        open: app.open
        onToggled: app.routeToggled()
      }

      HoverHandler {
        onHoveredChanged: if (hovered) app.pointed()
      }
    }

    Choices {
      width: parent.width
      visible: app.open
      bar: app.bar
      choices: app.open ? app.choices : []
      cursorKey: app.cursorKey
      onPointed: function(choice) { app.choicePointed(choice) }
      onChosen: function(choice) { app.choiceChosen(choice) }
      onRevealed: function(item) { app.choiceRevealed(item) }
    }
  }
}
