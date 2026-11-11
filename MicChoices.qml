import QtQuick
import Quickshell.Io

// "Microphone by app": which mic each app records from. The choices live in
// ~/.config/omarchy/audio-mic-pins.json, kept by bin/audio-route, so they can
// be made while an app is not recording and outlast the shell. Each time a
// recording stream appears, open panel or not, the helper puts any app with a
// choice onto its mic.
Item {
  id: store

  property string helper: ""
  // Refresh the list while true (the panel is open).
  property bool watching: false
  // The recording streams right now; any change re-applies the choices.
  property var recordingNodes: []

  // [{ app, live, source, pin }]: source and pin are PipeWire source node
  // names or "". The panel arranges them (Audio.arrangeMicApps).
  property var apps: []

  onRecordingNodesChanged: applySoon.restart()
  onWatchingChanged: if (watching) refresh()

  function refresh() {
    if (!lister.running) lister.running = true
    else listAgain = true
  }

  // Choose a mic for an app ("" lets it follow the default input). The row
  // changes at once; the list is read back once the helper is done.
  function choose(app, sourceName) {
    if (!app || !helper) return
    apps = apps.map(r => r.app === app ? Object.assign({}, r, { pin: sourceName || "" }) : r)
    queue = queue.concat([sourceName ? [helper, "pin", String(app), String(sourceName)] : [helper, "unpin", String(app)]])
    runNext()
  }

  // Changes run one after another, in the order they were made.
  property var queue: []
  property bool listAgain: false
  property bool applyAgain: false

  function runNext() {
    if (changer.running || queue.length === 0) return
    changer.command = queue[0]
    queue = queue.slice(1)
    changer.running = true
  }

  Process {
    id: changer
    onExited: {
      // later: the process still reads as running while it reports its exit
      if (store.queue.length) Qt.callLater(store.runNext)
      else store.refresh()
    }
  }

  Process {
    id: lister
    command: [store.helper, "mics"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text))
          // A choice still being written would flicker back; keep the screen on it.
          if (Array.isArray(parsed) && !changer.running && store.queue.length === 0) store.apps = parsed
        } catch (e) {}
      }
    }
    onExited: if (store.listAgain) {
      store.listAgain = false
      Qt.callLater(store.refresh)
    }
  }

  Process {
    id: enforcer
    command: [store.helper, "enforce"]
    onExited: {
      if (store.applyAgain) {
        store.applyAgain = false
        applySoon.restart()
      }
      if (store.watching) store.refresh()
    }
  }

  // Streams arrive in bursts; apply once they settle.
  Timer {
    id: applySoon
    interval: 250
    onTriggered: {
      if (!store.helper) return
      if (enforcer.running) store.applyAgain = true
      else enforcer.running = true
    }
  }
}
