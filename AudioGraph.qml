import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import "Audio.js" as Audio

// What the panel knows about PipeWire: the devices, the apps playing, the
// apps recording, and the volume of each. The bar icon needs the output volume
// at all times; everything else is only worked out while `watching` (the
// panel is open).
Item {
  id: graph

  property bool watching: false
  // Path of bin/audio-route, which moves an app between outputs.
  property string routeHelper: ""

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var defaultOutput: Pipewire.defaultAudioSink
  readonly property var defaultInput: Pipewire.defaultAudioSource

  // ------------------------------------------------------------ lookups

  // Nodes a platform's audio processing adds are neither devices nor apps;
  // its platform package names them (most machines have none).
  readonly property var nodeNames: nodes.filter(n => !!n && !!n.name).map(n => String(n.name))
  function platformHides(node) { return AudioNodes.platformHides(node.name, nodeNames) }

  readonly property var byRowKey: {
    var map = {}
    for (var i = 0; i < nodes.length; i++) {
      var r = Audio.row(nodes[i])
      if (r) map[Audio.rowKey(r)] = nodes[i]
    }
    return map
  }

  // The live node a row was taken from, or null once it is gone.
  function resolve(row) { return row ? (byRowKey[Audio.rowKey(row)] || null) : null }

  function deviceNamed(name) {
    if (!name) return null
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && !n.isStream && String(n.name || "") === name) return n
    }
    return null
  }

  // ------------------------------------------------------------ devices and apps

  // Outputs whose port is unplugged are left out; inputs PulseAudio lists
  // also identify virtual sources Quickshell cannot type (see Audio.js).
  property var outputPlugged: ({})
  property bool outputPluggedKnown: false
  property var listedInputs: ({})

  readonly property var outputNodes: {
    var list = nodes.filter(n => !!n && n.isSink && !n.isStream && !graph.platformHides(n))
    return list
  }

  readonly property var inputNodes: nodes.filter(n => Audio.isCaptureDevice(n, graph.listedInputs)
    && String(n.name || "") !== "quickshell" && !graph.platformHides(n))

  readonly property var playbackNodes: nodes.filter(n => Audio.isAppPlayback(n) && !!n.audio
    // a speaker tuning's own output is the processing, not an app
    && String(n.name || "").indexOf("omarchy_speaker_tuning") !== 0
    && !graph.platformHides(n))

  readonly property var recordingNodes: nodes.filter(n => Audio.isRecordingApp(n))

  readonly property var outputs: {
    var list = outputNodes.filter(n => !graph.outputPluggedKnown || graph.outputPlugged[String(n.name)] !== false)
    if (defaultOutput && list.indexOf(defaultOutput) < 0) list.unshift(defaultOutput)
    return list
  }

  readonly property var inputs: {
    var list = inputNodes.slice()
    if (defaultInput && list.indexOf(defaultInput) < 0) list.unshift(defaultInput)
    return list
  }

  // Keep the nodes bound so their names, properties and volumes stay current.
  PwObjectTracker { objects: graph.outputNodes }
  PwObjectTracker { objects: graph.inputNodes }
  PwObjectTracker { objects: graph.playbackNodes }

  // The rows the panel's lists are built from (see Audio.row for why rows).
  // PipeWire changes come in bursts, so they settle for a moment first. While a
  // graph rebuilds, a device list can briefly come up empty; the old rows are
  // kept through that, then dropped if the list is still empty a second later.
  property var outputRows: []
  property var inputRows: []
  property var appRows: []

  function snapshot(final) {
    if (!watching) return
    var outs = Audio.rows(outputs)
    var ins = Audio.rows(inputs)
    var keptOld = false
    if (outs.length || final || !outputRows.length) outputRows = outs; else keptOld = true
    if (ins.length || final || !inputRows.length) inputRows = ins; else keptOld = true
    appRows = Audio.rows(playbackNodes)
    if (keptOld) emptyGrace.restart()
  }

  function clearRows() {
    settle.stop()
    emptyGrace.stop()
    outputRows = []
    inputRows = []
    appRows = []
  }

  onWatchingChanged: watching ? snapshot(false) : clearRows()
  onOutputsChanged: if (watching) settle.restart()
  onInputsChanged: if (watching) settle.restart()
  onPlaybackNodesChanged: if (watching) settle.restart()

  Timer { id: settle; interval: 75; onTriggered: graph.snapshot(false) }
  Timer { id: emptyGrace; interval: 1000; onTriggered: graph.snapshot(true) }

  // Which output each app is playing on, by stream id, as a row. A stream that
  // is not playing has no link and so no entry.
  readonly property var linkGroups: Pipewire.linkGroups ? Pipewire.linkGroups.values : []
  readonly property var appOutput: {
    var map = {}
    if (!watching) return map
    for (var i = 0; i < linkGroups.length; i++) {
      var g = linkGroups[i]
      if (!g || !g.source || !g.target || !g.target.isSink || g.target.isStream) continue
      if (map[g.source.id] === undefined) map[g.source.id] = Audio.row(g.target)
    }
    return map
  }

  // ------------------------------------------------------------ output volume

  // Selecting a processing sink (a speaker tuning, EasyEffects) does not move
  // where loudness lives: its volume only changes how hard the processing is
  // driven, so a slider on it would move while the speakers stayed put.
  // omarchy-audio-output-sink names the physical output behind the current
  // default, as the volume keys use it; that is the node the slider drives.
  property string volumeNodeName: ""
  readonly property var volumeNode: {
    var out = defaultOutput
    if (!out || volumeNodeName === "" || volumeNodeName === String(out.name)) return out
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isSink && !n.isStream && n.audio && String(n.name) === volumeNodeName) return n
    }
    return out
  }

  // Each lookup takes a ticket; an answer for an older ticket is dropped, so a
  // slow lookup cannot overwrite a newer result.
  property int volumeTicket: 0
  property bool lookUpAgain: false

  function lookUpVolumeNode() {
    volumeTicket++
    var out = defaultOutput
    // A hardware output is its own volume node; no need to ask.
    if (out && String(out.name).indexOf("alsa_output.") === 0) {
      volumeNodeName = String(out.name)
      return
    }
    if (volumeLookup.running) {
      lookUpAgain = true
      return
    }
    volumeLookup.ticket = volumeTicket
    volumeLookup.running = true
  }

  Process {
    id: volumeLookup
    property int ticket: -1
    command: ["omarchy-audio-output-sink"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (volumeLookup.ticket === graph.volumeTicket) graph.volumeNodeName = String(text).trim()
    }
    onExited: if (graph.lookUpAgain) {
      graph.lookUpAgain = false
      // later: the process still reads as running while it reports its exit
      Qt.callLater(graph.lookUpVolumeNode)
    }
  }

  // A tuning appearing, a processing sink rerouted, or a stream starting all
  // show up as graph changes; a burst of them is looked up once.
  Timer { id: volumeRecheck; interval: 500; onTriggered: graph.lookUpVolumeNode() }
  onDefaultOutputChanged: lookUpVolumeNode()
  onNodesChanged: volumeRecheck.restart()
  onLinkGroupsChanged: volumeRecheck.restart()
  Component.onCompleted: lookUpVolumeNode()

  // An idle EasyEffects reroutes by its config file, without touching the graph.
  FileView {
    path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/easyeffects/db/easyeffectsrc"
    watchChanges: true
    printErrors: false
    onFileChanged: volumeRecheck.restart()
  }

  readonly property bool hasOutput: !!(volumeNode && volumeNode.audio)
  readonly property real outputVolume: hasOutput ? volumeNode.audio.volume : 0
  readonly property bool outputMuted: hasOutput ? volumeNode.audio.muted : false

  function setOutputVolume(value) {
    if (!hasOutput) return outputVolume
    var v = Math.max(0, Math.min(1, value))
    volumeNode.audio.volume = v
    return v
  }

  function setOutputMuted(muted) { if (hasOutput) volumeNode.audio.muted = muted }

  // ------------------------------------------------------------ input volume

  // A virtual default input has no Quickshell volume; the shell's UntypedInput
  // drives it through wpctl instead, and no level meter is possible for it.
  readonly property bool inputViaWpctl: UntypedInput.active
  readonly property bool hasInput: inputViaWpctl ? UntypedInput.known : !!(defaultInput && defaultInput.audio)
  readonly property bool inputLevelKnown: !inputViaWpctl || UntypedInput.known
  readonly property real inputVolume: inputViaWpctl ? UntypedInput.volume : (hasInput ? defaultInput.audio.volume : 0)
  readonly property bool inputMuted: inputViaWpctl ? UntypedInput.muted : (hasInput ? defaultInput.audio.muted : false)
  readonly property var meterNode: inputViaWpctl ? null : defaultInput

  function setInputVolume(value) {
    var v = Math.max(0, Math.min(1, value))
    if (inputViaWpctl) UntypedInput.setVolume(v)
    else if (hasInput) defaultInput.audio.volume = v
  }

  function setInputMuted(muted) {
    if (inputViaWpctl) UntypedInput.setMuted(muted)
    else if (hasInput) defaultInput.audio.muted = muted
  }

  // Something can still be heard or picked up. Only channels that exist get a
  // say: with no input at all, "input unmuted" would otherwise hold forever.
  readonly property bool anythingLive: (hasOutput && !outputMuted) || (hasInput && !inputMuted)

  function setEverythingMuted(muted) {
    setOutputMuted(muted)
    setInputMuted(muted)
  }

  // ------------------------------------------------------------ choosing devices

  function makeDefaultOutput(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSink = node
    // The command also moves playing apps and remembers the choice the Omarchy way.
    if (node.id !== undefined && node.name)
      Quickshell.execDetached(["omarchy-audio-output-set-default", String(node.id), String(node.name)])
  }

  function makeDefaultInput(node) {
    if (!node) return
    // Quickshell refuses an untyped node; the command still selects it.
    if (node.audio) Pipewire.preferredDefaultAudioSource = node
    if (node.id !== undefined && node.name)
      Quickshell.execDetached(["omarchy-audio-input-set-default", String(node.id), String(node.name)])
  }

  // Send one app's sound to an output. Argument lists, never a shell string:
  // device names come from outside.
  function sendApp(stream, output) {
    if (!stream || !output || stream.id === undefined || !output.name || !routeHelper) return
    Quickshell.execDetached([routeHelper, "play", String(stream.id), String(output.name)])
  }

  // ------------------------------------------------------------ availability

  Process {
    id: outputCheck
    command: ["omarchy-audio-sink-availability"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        graph.outputPlugged = Audio.parseAvailability(text)
        graph.outputPluggedKnown = true
      }
    }
  }

  Process {
    id: inputCheck
    command: ["omarchy-audio-sink-availability", "sources"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: graph.listedInputs = Audio.parseAvailability(text)
    }
  }

  // Plugging a jack in does not change the graph, so it is polled while open.
  Timer {
    interval: 5000
    running: graph.watching
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!outputCheck.running) outputCheck.running = true
      if (!inputCheck.running) inputCheck.running = true
    }
  }
}
