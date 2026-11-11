import QtQuick
import qs.Commons
import qs.Commons as Commons

// Text in the panel's voice. Always plain text: device and app names come
// from outside and must never be read as markup.
Text {
  property QtObject bar: null
  // "caption", "body", "title" or "display" (Style.font sizes)
  property string tier: "body"
  property bool dim: false

  readonly property color ink: bar ? bar.foreground : Commons.Color.foreground

  textFormat: Text.PlainText
  color: dim ? Qt.darker(ink, 1.4) : ink
  font.family: bar ? bar.fontFamily : Style.font.family
  font.pixelSize: Style.font[tier]
  elide: Text.ElideRight
}
