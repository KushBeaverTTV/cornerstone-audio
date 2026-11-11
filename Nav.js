// Cornerstone Audio: the keyboard cursor.
//
// The panel reads top to bottom as one list of stops: the on/off switch, the
// output slider, each output, the input slider, each input, each app (and the
// outputs under it while its picker is open), each app's microphone line (and
// its choices while open), then the "more apps" button. Up and down walk that
// list; the mouse moves the same cursor by pointing at a stop, so there is only
// ever one highlight.
//
// A stop is known by a key built from what it shows (a node id, an app name),
// not by its position, so when a list refreshes underneath, the cursor stays
// on the same thing even if it moved.

// state: {
//   outputs: [row], inputs: [row], inputSlider: bool,
//   apps: [row], openApp: rowKey or "",
//   mics: [{ app }], openMic: app or "", moreMics: bool
// }
function buildStops(state) {
  var s = state || {}
  var outputs = s.outputs || []
  var inputs = s.inputs || []
  var stops = [{ key: "master", kind: "master" }, { key: "out", kind: "outSlider" }]

  outputs.forEach(function(r) { stops.push({ key: "out:" + r.id, kind: "output", row: r }) })
  if (s.inputSlider) stops.push({ key: "in", kind: "inSlider" })
  inputs.forEach(function(r) { stops.push({ key: "in:" + r.id, kind: "input", row: r }) })

  ;(s.apps || []).forEach(function(r) {
    var appKey = "app:" + r.id
    stops.push({ key: appKey, kind: "app", row: r })
    if (s.openApp && s.openApp === r.id + "\n" + r.name)
      outputs.forEach(function(o) {
        stops.push({ key: appKey + ">" + o.id, kind: "appChoice", row: r, choice: o })
      })
  })

  ;(s.mics || []).forEach(function(m) {
    var micKey = "mic:" + m.app
    stops.push({ key: micKey, kind: "mic", app: m.app })
    if (s.openMic && s.openMic === m.app) {
      stops.push({ key: micKey + ">", kind: "micChoice", app: m.app, source: "" })
      inputs.forEach(function(i) {
        stops.push({ key: micKey + ">" + i.name, kind: "micChoice", app: m.app, source: i.name })
      })
    }
  })

  if (s.moreMics) stops.push({ key: "more", kind: "more" })
  return stops
}

function indexOfKey(stops, key) {
  for (var i = 0; i < stops.length; i++) if (stops[i].key === key) return i
  return -1
}

// The stop `delta` places away from `key`. When `key` has gone (its row went
// away), the walk starts from where it last was, `lastIndex`. Ends do not wrap.
function step(stops, key, lastIndex, delta) {
  if (!stops.length) return null
  var at = indexOfKey(stops, key)
  if (at < 0) {
    var from = Math.max(0, Math.min(stops.length - 1, lastIndex || 0))
    // The stop that took the lost one's place is already one step on.
    at = delta > 0 ? from - 1 : from
  }
  var next = Math.max(0, Math.min(stops.length - 1, at + delta))
  return stops[next]
}

if (typeof module !== "undefined") {
  module.exports = { buildStops: buildStops, indexOfKey: indexOfKey, step: step }
}
