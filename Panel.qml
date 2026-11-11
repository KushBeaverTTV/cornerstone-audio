import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Audio.js" as Audio
import "Nav.js" as Nav
import "ui" as Parts

// Cornerstone Audio: the bar's sound icon and its panel.
//
//   bar icon      click opens the panel, right-click mutes output and mic,
//                 scroll changes the volume (with the on-screen display)
//   panel         output and input volume and devices; every app that is
//                 playing, with its own volume and the output it plays on;
//                 every app that uses a microphone, with the mic it records from
//
// The data comes from AudioGraph.qml (PipeWire) and MicChoices.qml (the saved
// mic choices); the rows are drawn by ui/; Nav.js is the keyboard cursor.
Panel {
  id: root
  moduleName: "cornerstone.audio"
  ipcTarget: "cornerstone.audio"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string routeHelper: decodeURIComponent(String(Qt.resolvedUrl("bin/audio-route")).replace(/^file:\/\//, ""))

  AudioGraph {
    id: graph
    watching: root.opened
    routeHelper: root.routeHelper
  }

  MicChoices {
    id: mics
    helper: root.routeHelper
    watching: root.opened
    recordingNodes: graph.recordingNodes
  }

  PwNodePeakMonitor {
    id: inputPeak
    node: graph.meterNode
    enabled: root.opened && !!graph.meterNode
  }

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var currentPlayer: mediaService ? mediaService.activePlayer : null

  // ---------------------------------------------------------------- the bar icon

  function levelGlyph(volume) {
    return Audio.outputLevelGlyph(graph.hasOutput ? graph.defaultOutput : null, volume, graph.outputMuted)
  }

  function toggleEverything() {
    graph.setEverythingMuted(graph.anythingLive)
  }

  // Touchpads send fractions of a wheel notch; they add up here.
  property real wheelCarry: 0

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.levelGlyph(graph.outputVolume)

    onPressed: function(which) {
      if (which === Qt.RightButton) root.toggleEverything()
      else root.toggle()
    }

    onWheelMoved: function(delta) {
      if (!graph.hasOutput) return
      var wheel = Util.wheelSteps(root.wheelCarry, delta)
      root.wheelCarry = wheel.remainder
      if (wheel.steps === 0) return
      var volume = graph.setOutputVolume(graph.outputVolume + wheel.steps * 0.05)
      if (root.bar && root.bar.shell)
        root.bar.shell.summon("omarchy.osd", JSON.stringify({ icon: root.levelGlyph(volume), value: Math.round(volume * 100) }))
    }
  }

  // ---------------------------------------------------------------- what the rows say

  function appRoute(row) {
    var output = graph.resolve(graph.appOutput[row.id])
    return output
      ? { glyph: Audio.deviceGlyph(output, false), label: Audio.deviceName(output) }
      : { glyph: Audio.GLYPH.speaker, label: "Default output" }
  }

  function appChoices(row) {
    var current = graph.appOutput[row.id]
    return present(graph.outputRows).map(function(o) {
      var node = graph.resolve(o)
      return {
        key: "app:" + row.id + ">" + o.id, output: o,
        glyph: Audio.deviceGlyph(node, false), label: Audio.deviceName(node),
        current: Audio.sameRow(current, o)
      }
    })
  }

  function micRoute(entry) {
    if (entry.pin) {
      var chosen = graph.deviceNamed(entry.pin)
      return chosen
        ? { glyph: Audio.deviceGlyph(chosen, true), label: Audio.deviceName(chosen) }
        : { glyph: Audio.GLYPH.micOff, label: "Chosen mic is unplugged" }
    }
    var input = graph.defaultInput
    // Recording now from some other mic: the app picked it itself.
    if (entry.live && entry.source && (!input || entry.source !== String(input.name))) {
      var own = graph.deviceNamed(entry.source)
      if (own) return { glyph: Audio.deviceGlyph(own, true), label: Audio.deviceName(own) + ", set in the app" }
    }
    return { glyph: Audio.GLYPH.followDefault, label: "Default input" + (input ? " (" + Audio.deviceName(input) + ")" : "") }
  }

  function micChoiceList(entry) {
    var list = [{
      key: "mic:" + entry.app + ">", source: "",
      glyph: Audio.GLYPH.followDefault, label: "Follow default input", current: !entry.pin
    }]
    present(graph.inputRows).forEach(function(i) {
      var node = graph.resolve(i)
      list.push({
        key: "mic:" + entry.app + ">" + i.name, source: i.name,
        glyph: Audio.deviceGlyph(node, true), label: Audio.deviceName(node), current: entry.pin === i.name
      })
    })
    return list
  }

  // Apps recording or with a mic chosen show; the rest fold behind a button.
  property bool showAllMics: false
  readonly property var micLayout: Audio.arrangeMicApps(mics.apps, showAllMics, 3)
  readonly property int foldableMics: Audio.arrangeMicApps(mics.apps, false, 3).hidden

  // ---------------------------------------------------------------- open pickers

  // At most one list is open: an app's outputs (by row key) or an app's mics.
  property string openApp: ""
  property string openMic: ""

  function toggleAppPicker(row) {
    var key = Audio.rowKey(row)
    openMic = ""
    openApp = openApp === key ? "" : key
  }

  function toggleMicPicker(app) {
    openApp = ""
    openMic = openMic === app ? "" : app
  }

  // Where each app was last sent from here, so a second quick "o" carries on
  // from there instead of waiting for PipeWire to report the first move.
  property var lastSent: ({})

  function sendApp(row, output) {
    graph.sendApp(graph.resolve(row), graph.resolve(output))
    var next = Object.assign({}, lastSent)
    next[row.id] = { output: output, at: Date.now() }
    lastSent = next
  }

  function playingOn(row) {
    var sent = lastSent[row.id]
    if (sent && Date.now() - sent.at < 3000) return sent.output
    return graph.appOutput[row.id]
  }

  function sendAppTo(row, output) {
    sendApp(row, output)
    openApp = ""
    point("app:" + row.id)
  }

  function chooseMic(app, source) {
    mics.choose(app, source)
    openMic = ""
    point("mic:" + app)
  }

  // ---------------------------------------------------------------- the cursor

  // Rows whose node is gone are hidden (see the delegates), so not stops either.
  function present(rows) { return rows.filter(r => !!graph.resolve(r)) }

  readonly property var stops: Nav.buildStops({
    outputs: present(graph.outputRows),
    inputs: present(graph.inputRows),
    inputSlider: !!graph.defaultInput,
    apps: present(graph.appRows),
    openApp: openApp,
    mics: micLayout.shown,
    openMic: openMic,
    moreMics: foldableMics > 0
  })

  property bool cursorShown: false
  property string cursorKey: "out"
  property int cursorIndex: 1
  readonly property var cursorStop: cursorShown ? (stops[Nav.indexOfKey(stops, cursorKey)] || null) : null

  function at(key) { return cursorShown && cursorKey === key }

  function point(key) {
    cursorShown = true
    cursorKey = key
    var i = Nav.indexOfKey(stops, key)
    if (i >= 0) cursorIndex = i
  }

  // A row going away under the cursor hands it to whatever took its place.
  onStopsChanged: {
    var i = Nav.indexOfKey(stops, cursorKey)
    if (i >= 0) cursorIndex = i
    else if (stops.length) cursorKey = stops[Math.max(0, Math.min(stops.length - 1, cursorIndex))].key
  }

  function moveCursor(delta) {
    var next = Nav.step(stops, cursorKey, cursorIndex, delta)
    if (next) point(next.key)
  }

  // Left / right (h / l).
  function nudge(direction) {
    var stop = cursorStop
    if (!stop) return
    var step = direction * 0.05
    if (stop.kind === "outSlider") graph.setOutputVolume(graph.outputVolume + step)
    else if (stop.kind === "inSlider") graph.setInputVolume(graph.inputVolume + step)
    else if (stop.kind === "app") {
      var stream = graph.resolve(stop.row)
      if (stream && stream.audio) stream.audio.volume = Math.max(0, Math.min(1.5, stream.audio.volume + step))
    }
    // In an open list, left goes back up to its app.
    else if (stop.kind === "appChoice" && direction < 0) { openApp = ""; point("app:" + stop.row.id) }
    else if (stop.kind === "micChoice" && direction < 0) { openMic = ""; point("mic:" + stop.app) }
    else if (stop.kind === "mic") {
      if ((direction > 0) !== (openMic === stop.app)) toggleMicPicker(stop.app)
    }
  }

  // Enter / Space.
  function activate() {
    var stop = cursorStop
    if (!stop) return
    switch (stop.kind) {
    case "master": toggleEverything(); break
    case "outSlider": graph.setOutputMuted(!graph.outputMuted); break
    case "output": graph.makeDefaultOutput(graph.resolve(stop.row)); break
    case "inSlider": graph.setInputMuted(!graph.inputMuted); break
    case "input": graph.makeDefaultInput(graph.resolve(stop.row)); break
    case "app": toggleAppPicker(stop.row); break
    case "appChoice": sendAppTo(stop.row, stop.choice); break
    case "mic": toggleMicPicker(stop.app); break
    case "micChoice": chooseMic(stop.app, stop.source); break
    case "more": showAllMics = !showAllMics; break
    }
  }

  // m: mute whatever the cursor is about.
  function muteAtCursor() {
    var stop = cursorStop
    if (!stop) return
    if (stop.kind === "master") {
      toggleEverything()
    } else if (stop.kind === "app" || stop.kind === "appChoice") {
      var stream = graph.resolve(stop.row)
      if (stream && stream.audio) stream.audio.muted = !stream.audio.muted
    } else if (["inSlider", "input", "mic", "micChoice"].indexOf(stop.kind) !== -1) {
      graph.setInputMuted(!graph.inputMuted)
    } else {
      graph.setOutputMuted(!graph.outputMuted)
    }
  }

  // o: send the app under the cursor to the next output.
  function cycleAppOutput() {
    var stop = cursorStop
    if (!stop || (stop.kind !== "app" && stop.kind !== "appChoice")) return
    var outs = present(graph.outputRows)
    if (outs.length < 2) return
    var current = playingOn(stop.row)
    var now = -1
    for (var i = 0; i < outs.length; i++) if (Audio.sameRow(outs[i], current)) now = i
    sendApp(stop.row, outs[(now + 1) % outs.length])
  }

  // x / Delete on a mic line: back to following the default input.
  function forgetMic() {
    var stop = cursorStop
    if (stop && (stop.kind === "mic" || stop.kind === "micChoice")) chooseMic(stop.app, "")
  }

  // ---------------------------------------------------------------- scrolling

  readonly property var scroller: panel.loadedContent ? panel.loadedContent.scroller : null

  function scrollToTop() {
    var flick = scroller ? scroller.contentItem : null
    if (flick && flick.contentY !== undefined) flick.contentY = 0
  }

  // Keep the stop under the keyboard cursor in view.
  function reveal(item) {
    var flick = scroller ? scroller.contentItem : null
    if (!item || !flick || flick.contentY === undefined) return
    var room = Math.max(0, (flick.contentHeight || 0) - flick.height)
    if (room <= Style.space(24) || cursorKey === "master" || cursorKey === "out") {
      flick.contentY = 0
      return
    }
    var margin = Style.space(6)
    var top = item.mapToItem(flick.contentItem || flick, 0, 0).y
    var bottom = top + (item.height || 0)
    if (top < flick.contentY + margin) flick.contentY = Math.max(0, Math.min(room, top - margin))
    else if (bottom > flick.contentY + flick.height - margin)
      flick.contentY = Math.max(0, Math.min(room, bottom + margin - flick.height))
  }

  onOpenedChanged: if (opened) {
    cursorShown = false
    cursorKey = "out"
    cursorIndex = 1
    openApp = ""
    openMic = ""
    showAllMics = false
    Qt.callLater(scrollToTop)
  }

  // ---------------------------------------------------------------- the panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    // Tall enough that the apps are not below the fold on a 1080p screen.
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(900))

    content: PanelKeyCatcher {
      property alias scroller: scroller
      implicitHeight: page.implicitHeight
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        // The first key only shows where the cursor is.
        if (!root.cursorShown) { root.cursorShown = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.nudge(dx)
      }
      onActivateRequested: if (root.cursorShown) root.activate()
      onDeleteRequested: if (root.cursorShown) root.forgetMic()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(key) {
        if (!root.cursorShown) return
        if (key === "m" || key === "M") root.muteAtCursor()
        else if (key === "o" || key === "O") root.cycleAppOutput()
      }

      ScrollView {
        id: scroller
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: page.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Binding {
          target: scroller.contentItem
          property: "interactive"
          value: page.implicitHeight > scroller.height
        }

        Column {
          id: page
          width: scroller.availableWidth
          spacing: Style.space(14)

          // ---- top: what is playing where, and the off switch
          Item {
            width: parent.width
            implicitHeight: Math.max(bigGlyph.implicitHeight, heading.implicitHeight, masterSwitch.implicitHeight)

            Parts.PlainLabel {
              id: bigGlyph
              bar: root.bar
              tier: "display"
              elide: Text.ElideNone
              text: root.levelGlyph(outputLevel.shownValue)
              opacity: graph.outputMuted ? 0.5 : 1
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heading
              anchors.left: bigGlyph.right
              anchors.leftMargin: Style.space(14)
              anchors.right: masterSwitch.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Parts.PlainLabel {
                width: parent.width
                bar: root.bar
                tier: "title"
                font.bold: true
                text: "Audio"
              }

              // Where sound goes and where it comes from, at a glance.
              Parts.PlainLabel {
                width: parent.width
                bar: root.bar
                tier: "caption"
                dim: true
                font.bold: true
                text: {
                  var out = graph.defaultOutput ? Audio.deviceName(graph.defaultOutput) : "No output"
                  var inp = graph.defaultInput ? Audio.deviceName(graph.defaultInput) : "No mic"
                  return (graph.outputMuted ? "Muted" : out) + "  ·  " + (graph.inputMuted ? "Mic muted" : inp)
                }
              }
            }

            ToggleSwitch {
              id: masterSwitch
              checked: graph.anythingLive
              hasCursor: root.at("master")
              foreground: root.bar.foreground
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              onHovered: function(on) { if (on) root.point("master") }
              onToggled: root.toggleEverything()

              PanelToolTip {
                visible: masterSwitch.containsMouse
                text: graph.anythingLive ? "Mute output and mic" : "Unmute output and mic"
                fontFamily: root.bar.fontFamily
              }
            }
          }

          // ---- output
          PanelSeparator { foreground: root.bar.foreground }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Parts.SectionTitle {
              width: parent.width
              bar: root.bar
              text: "OUTPUT"
              reading: Audio.percent(outputLevel.shownValue)
              readingFaded: graph.outputMuted
            }

            Parts.LevelSlider {
              id: outputLevel
              width: parent.width
              bar: root.bar
              value: graph.outputVolume
              muted: graph.outputMuted
              enabled: graph.hasOutput
              hasCursor: root.at("out")
              onHasCursorChanged: if (hasCursor) root.reveal(this)
              onMoved: function(v) { graph.setOutputVolume(v) }
              onMuteToggled: graph.setOutputMuted(!graph.outputMuted)
              onPointed: root.point("out")
            }

            Repeater {
              model: graph.outputRows

              Parts.DeviceRow {
                required property var modelData
                readonly property var node: graph.resolve(modelData)
                // gone since the list was taken: hidden until the list catches up
                visible: !!node
                readonly property string stop: "out:" + modelData.id
                width: page.width
                bar: root.bar
                glyph: Audio.deviceGlyph(node, false)
                label: Audio.deviceName(node)
                active: !!node && !!graph.defaultOutput && graph.defaultOutput.id === node.id
                hasCursor: root.at(stop)
                onHasCursorChanged: if (hasCursor) root.reveal(this)
                onPointed: root.point(stop)
                onChosen: graph.makeDefaultOutput(node)
              }
            }
          }

          // ---- input
          PanelSeparator {
            visible: inputSection.visible
            foreground: root.bar.foreground
          }

          Column {
            id: inputSection
            width: parent.width
            spacing: Style.space(6)
            visible: graph.inputRows.length > 0 || !!graph.defaultInput

            Parts.SectionTitle {
              width: parent.width
              bar: root.bar
              text: "INPUT"
              reading: graph.inputLevelKnown && graph.defaultInput ? Audio.percent(inputLevel.shownValue) : ""
              readingFaded: graph.inputMuted
            }

            Parts.LevelSlider {
              id: inputLevel
              visible: !!graph.defaultInput
              width: parent.width
              bar: root.bar
              value: graph.inputVolume
              muted: graph.inputMuted
              enabled: !!graph.defaultInput
              meterShown: !!graph.meterNode
              meter: inputPeak.peak
              hasCursor: root.at("in")
              onHasCursorChanged: if (hasCursor) root.reveal(this)
              onMoved: function(v) { graph.setInputVolume(v) }
              onMuteToggled: graph.setInputMuted(!graph.inputMuted)
              onPointed: root.point("in")
            }

            Repeater {
              model: graph.inputRows

              Parts.DeviceRow {
                required property var modelData
                readonly property var node: graph.resolve(modelData)
                // gone since the list was taken: hidden until the list catches up
                visible: !!node
                readonly property string stop: "in:" + modelData.id
                width: page.width
                bar: root.bar
                glyph: Audio.deviceGlyph(node, true)
                label: Audio.deviceName(node)
                active: !!node && !!graph.defaultInput && graph.defaultInput.id === node.id
                hasCursor: root.at(stop)
                onHasCursorChanged: if (hasCursor) root.reveal(this)
                onPointed: root.point(stop)
                onChosen: graph.makeDefaultInput(node)
              }
            }
          }

          // ---- apps playing
          PanelSeparator {
            visible: graph.appRows.length > 0
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(10)
            visible: graph.appRows.length > 0

            Parts.SectionTitle {
              width: parent.width
              bar: root.bar
              text: "APPS"
            }

            Repeater {
              model: graph.appRows

              Parts.AppRow {
                required property var modelData
                readonly property var node: graph.resolve(modelData)
                // gone since the list was taken: hidden until the list catches up
                visible: !!node
                readonly property string stop: "app:" + modelData.id
                readonly property var route: root.appRoute(modelData)
                width: page.width
                bar: root.bar
                name: Audio.appName(node, root.players, graph.playbackNodes)
                volume: node && node.audio ? node.audio.volume : 0
                muted: node && node.audio ? node.audio.muted : false
                featured: Audio.isCurrentPlayer(node, root.currentPlayer, root.players, graph.playbackNodes)
                routeGlyph: route.glyph
                routeLabel: route.label
                open: root.openApp === Audio.rowKey(modelData)
                choices: open ? root.appChoices(modelData) : []
                cursorKey: root.cursorShown ? root.cursorKey : ""
                hasCursor: root.at(stop)
                onHasCursorChanged: if (hasCursor) root.reveal(this)
                onPointed: root.point(stop)
                onVolumeMoved: function(v) { if (node && node.audio) node.audio.volume = v }
                onMuteToggled: if (node && node.audio) node.audio.muted = !node.audio.muted
                onRouteToggled: root.toggleAppPicker(modelData)
                onChoicePointed: function(choice) { root.point(choice.key) }
                onChoiceChosen: function(choice) { root.sendAppTo(modelData, choice.output) }
                onChoiceRevealed: function(item) { root.reveal(item) }
              }
            }
          }

          // ---- microphone by app
          PanelSeparator { foreground: root.bar.foreground }

          Column {
            width: parent.width
            spacing: Style.space(2)

            Parts.SectionTitle {
              width: parent.width
              bar: root.bar
              text: "MICROPHONE BY APP"
            }

            // Always shown, so the feature can be found before any app records.
            Parts.PlainLabel {
              visible: mics.apps.length === 0
              width: parent.width
              bar: root.bar
              tier: "caption"
              wrapMode: Text.WordWrap
              opacity: 0.6
              leftPadding: Style.space(6)
              topPadding: Style.space(4)
              bottomPadding: Style.space(6)
              text: "No app has used a microphone yet. Once one does, it stays listed here so you can choose its mic any time."
            }

            Repeater {
              model: root.micLayout.shown

              Parts.MicRow {
                required property var modelData
                readonly property string stop: "mic:" + modelData.app
                readonly property var route: root.micRoute(modelData)
                width: page.width
                bar: root.bar
                name: Audio.micAppName(modelData.app)
                live: !!modelData.live
                routeGlyph: route.glyph
                routeLabel: route.label
                open: root.openMic === modelData.app
                choices: open ? root.micChoiceList(modelData) : []
                cursorKey: root.cursorShown ? root.cursorKey : ""
                hasCursor: root.at(stop)
                onHasCursorChanged: if (hasCursor) root.reveal(this)
                onPointed: root.point(stop)
                onRouteToggled: root.toggleMicPicker(modelData.app)
                onChoicePointed: function(choice) { root.point(choice.key) }
                onChoiceChosen: function(choice) { root.chooseMic(modelData.app, choice.source) }
                onChoiceRevealed: function(item) { root.reveal(item) }
              }
            }

            Parts.TextButton {
              visible: root.foldableMics > 0
              width: parent.width
              bar: root.bar
              text: root.showAllMics ? "Show fewer"
                : "Show " + root.micLayout.hidden + " more app" + (root.micLayout.hidden === 1 ? "" : "s")
              hasCursor: root.at("more")
              onHasCursorChanged: if (hasCursor) root.reveal(this)
              onPointed: root.point("more")
              onClicked: root.showAllMics = !root.showAllMics
            }
          }
        }
      }
    }
  }
}
