import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// A channel's volume slider as one cursor stop, with an optional live level
// meter under it. Right-click mutes, as on every slider in the shell.
CursorSurface {
  id: level

  property QtObject bar: null
  property real value: 0
  property real maximum: 1
  property bool muted: false
  property bool meterShown: false
  property real meter: 0

  readonly property bool dragging: slider.dragging
  readonly property real shownValue: slider.dragging ? slider.liveValue : value

  signal moved(real value)
  signal muteToggled()
  signal pointed()

  foreground: bar.foreground
  outline: true
  implicitHeight: stack.implicitHeight + Style.spacing.controlGap

  Column {
    id: stack
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(6)
    spacing: Style.space(5)

    PanelSlider {
      id: slider
      bar: level.bar
      width: parent.width
      minimum: 0
      maximum: level.maximum
      step: 0.05
      value: level.value
      enabled: level.enabled
      opacity: level.muted ? 0.5 : 1
      onMoved: function(v) { level.moved(v) }
      onRightClicked: level.muteToggled()
    }

    Rectangle {
      visible: level.meterShown
      width: parent.width
      height: Math.max(Style.space(5), Style.spacing.xs)
      color: Util.alpha(level.bar.foreground, 0.18)
      opacity: level.muted ? 0.35 : 1

      Rectangle {
        height: parent.height
        width: parent.width * Math.max(0, Math.min(1, level.meter))
        color: level.bar.foreground
        Behavior on width { NumberAnimation { duration: Style.duration(70) } }
      }
    }
  }

  HoverHandler {
    onHoveredChanged: if (hovered) level.pointed()
  }
}
