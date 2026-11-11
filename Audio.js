// Cornerstone Audio: the plain logic behind the panel. Nothing in here touches
// Qt, so `node tests/run.js` checks it without a running shell. Functions take
// PwNode-shaped objects ({ id, name, description, nickname, isSink, isStream,
// audio, type, ready, properties }) or plain values.

// ---------------------------------------------------------------- glyphs

// Nerd Font code points, named so the code says what it draws.
var GLYPH = {
  headphones: "\u{F02CB}",
  speaker: "\u{F04C3}",
  bluetooth: "\u{F00AF}",
  display: "\u{F0379}",
  camera: "\u{F0100}",
  mic: "\u{F036C}",
  micOff: "\u{F036D}",
  appOn: "\u{F057E}",
  appMuted: "\u{F075F}",
  followDefault: "\u{F0453}",
  check: "\u{F012C}",
  closed: "\u{F0142}",
  open: "\u{F0140}",
  // The bar's level glyphs come from the Font Awesome range on purpose: the
  // Material speaker icons render visibly smaller in JetBrainsMono Nerd Font.
  levelOff: "\u{EEE8}",
  levelLow: "\u{F026}",
  levelMid: "\u{F027}",
  levelHigh: "\u{F028}"
}

// ---------------------------------------------------------------- node kinds

function props(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

function mediaClass(node) {
  return String(node && node.type !== undefined && node.type !== null ? node.type : "")
}

// An app's playback stream. Quickshell spells `type` differently from version
// to version, but a playback stream always takes audio in, so it reports
// isSink; the class text is only the fallback. Node properties are not read
// here on purpose: they are invalid until the node is bound, and reading them
// while capture streams come and go has destabilised Quickshell before.
function isAppPlayback(node) {
  if (!node || !node.isStream) return false
  if (node.isSink === true) return true
  return /Output|AudioOutStream/.test(mediaClass(node))
}

// A device that records (a microphone, a line in, a virtual source). Quickshell
// only types exact media classes, so a virtual source (Audio/Source/Virtual,
// such as EasyEffects') has no `audio`; PulseAudio still lists it as a source,
// so a name in `listedSources` (from omarchy-audio-sink-availability sources)
// counts too.
function isCaptureDevice(node, listedSources) {
  if (!node || node.isSink || node.isStream) return false
  if (node.audio) return true
  if (/Source/.test(mediaClass(node))) return true
  var name = String(node.name || "")
  return name !== "" && !!listedSources && Object.prototype.hasOwnProperty.call(listedSources, name)
}

// Level meters, monitors and the shell itself open capture streams too; they
// are not apps using a microphone.
var NOT_A_RECORDING_APP = /peak|monitor|meter|quickshell|omarchy/i

function isRecordingApp(node) {
  if (!node || !node.isStream || isAppPlayback(node) || !node.audio) return false
  return !NOT_A_RECORDING_APP.test(String(node.name || ""))
}

// ---------------------------------------------------------------- rows

// Lists handed to a Repeater carry plain rows, never PwNodes: a row holding a
// PwNode is a QObject Qt dereferences without a null check while it builds the
// delegate, and PipeWire deletes nodes outright, so a graph teardown would take
// the shell down. The name rides along because PipeWire reuses ids; a node's
// name never changes while it lives, so id + name finds that node and no other.
function row(node) {
  if (!node || node.id === undefined || node.id === null) return null
  return { id: node.id, name: String(node.name || "") }
}

function rows(list) {
  var out = []
  var values = list && list.length ? list : []
  for (var i = 0; i < values.length; i++) {
    var r = row(values[i])
    if (r) out.push(r)
  }
  return out
}

function rowKey(r) {
  return r ? r.id + "\n" + r.name : ""
}

function sameRow(a, b) {
  return !!a && !!b && a.id === b.id && a.name === b.name
}

// "name<TAB>0|1" lines from omarchy-audio-sink-availability: false means the
// port is unplugged (a headphone jack with nothing in it, say).
function parseAvailability(text) {
  var out = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var cols = lines[i].trim().split("\t")
    if (cols.length >= 2 && cols[0] !== "") out[cols[0]] = cols[1] !== "0"
  }
  return out
}

// ---------------------------------------------------------------- device names

function tidyDeviceName(text) {
  var bare = String(text || "")
    // the profile part of a description: "Analog Stereo", "Digital Stereo (HDMI)", "Mono"
    .replace(/\s+(analog|digital|pro)\s+(stereo|mono|surround\s+[\d.]+)(\s*\([^)]*\))?/i, "")
    .replace(/\s+(mono|stereo|mono-fallback)$/i, "")
    .replace(/\s+(output|input)$/i, "")
    .replace(/\bMicrophones\b/g, "Microphone")
    .replace(/\s{2,}/g, " ")
    .trim()
  // A generic maker prefix goes too, unless it is all the name there is.
  var short = bare.replace(/^(sof-soundwire|built-?in audio)\s+/i, "")
  return short || bare
}

// ALSA cuts a nickname at 31 characters ("Corsair HS80 RGB USB Gaming Hea");
// the description then has it whole.
function nicknameIsCut(nick, description) {
  return nick !== "" && description.length > nick.length
    && description.indexOf(nick) === 0 && /\w/.test(description.charAt(nick.length))
}

function deviceName(node) {
  if (!node) return "Unknown device"
  var p = props(node)
  var description = String(node.description || p["node.description"] || "").trim()
  var nick = String(node.nickname || node.nick || p["node.nick"] || "").trim()
  // A cut nickname means the description is the real name. Otherwise the
  // profile's description ("Speaker", "Headphones" on laptops) comes before
  // the long card description.
  var name = nicknameIsCut(nick, description)
    ? description
    : nick || String(p["device.profile.description"] || "").trim() || description || String(node.name || "")
  return tidyDeviceName(name) || "Unknown device"
}

// What sort of device this is, for its glyph: headphones, bluetooth, display,
// camera, or the plain speaker / mic.
function deviceKind(node, recording) {
  if (!node) return recording ? "mic" : "speaker"
  var p = props(node)
  var formFactor = String(p["device.form-factor"] || "").toLowerCase()
  var text = [
    node.name, node.description, node.nickname,
    p["device.icon-name"], p["device.product.name"], p["node.description"], p["node.nick"]
  ].join(" ").toLowerCase()
  if (/head(phone|set)|earbud|hands-?free/.test(formFactor)
      || /head(phone|set)|earbud|earphone|airpod|\bbuds?\b/.test(text)) return "headphones"
  if (recording && (formFactor === "webcam" || /webcam|camera/.test(text))) return "camera"
  if (/bluez|bluetooth/.test(text)) return "bluetooth"
  if (!recording && /hdmi|displayport|\bdp\b/.test(text)) return "display"
  return recording ? "mic" : "speaker"
}

function deviceGlyph(node, recording) {
  return GLYPH[deviceKind(node, recording)]
}

// The bar icon and the panel's big icon: headphones say so; speakers show
// how loud.
function outputLevelGlyph(node, volume, muted) {
  if (!node) return GLYPH.levelOff
  if (deviceKind(node, false) === "headphones") return GLYPH.headphones
  if (muted || volume <= 0) return GLYPH.levelOff
  if (volume >= 0.67) return GLYPH.levelHigh
  if (volume >= 0.34) return GLYPH.levelMid
  return GLYPH.levelLow
}

function percent(volume) {
  return Math.round(Math.max(0, Number(volume) || 0) * 100) + "%"
}

// ---------------------------------------------------------------- app names

var ALIASES = {
  "spotify": "Spotify",
  // Discord's voice engine names its microphone stream after the library, not the app.
  "webrtc voiceengine": "Discord"
}

function alias(name) {
  var text = String(name || "").trim()
  return ALIASES[text.toLowerCase()] || text
}

function overlap(a, b) {
  a = String(a || "").toLowerCase()
  b = String(b || "").toLowerCase()
  return a !== "" && b !== "" && (a.indexOf(b) !== -1 || b.indexOf(a) !== -1)
}

function streamRawName(node) {
  if (!node) return ""
  var p = props(node)
  return String(p["application.name"] || node.description || p["media.name"] || p["node.name"] || node.name || "").trim()
}

// Chromium-based players (Spotify among them) call their stream just this.
function isAnonymousStream(raw) {
  return String(raw || "").trim().toLowerCase() === "audio-src"
}

function playerName(player) {
  return player ? alias(player.identity || player.desktopEntry || "") : ""
}

// playerctld re-publishes whichever player is current; it only counts when no
// real player fits.
function isPlayerProxy(player) {
  var bus = String(player && player.dbusName || "").toLowerCase()
  var entry = String(player && player.desktopEntry || "").toLowerCase()
  return bus.indexOf("playerctld") !== -1 || entry === "playerctld"
}

// The one media player that fits, by name, or "" when none or several do.
// A player that is playing wins over ones that are only paused.
function pickPlayer(players, fits) {
  var real = {}
  var proxy = {}
  var list = Array.isArray(players) ? players : []
  for (var i = 0; i < list.length; i++) {
    var player = list[i]
    if (!player || !(player.isPlaying || player.canPlay)) continue
    var name = playerName(player)
    if (!name || !fits(name)) continue
    var into = isPlayerProxy(player) ? proxy : real
    var key = name.toLowerCase()
    if (!into[key]) into[key] = { name: name, playing: false }
    if (player.isPlaying) into[key].playing = true
  }
  var found = Object.keys(real).length ? real : proxy
  var all = Object.keys(found).map(function(k) { return found[k] })
  var playing = all.filter(function(c) { return c.playing })
  if (playing.length === 1) return playing[0].name
  if (playing.length === 0 && all.length === 1) return all[0].name
  return ""
}

// The name an app's playback stream is shown under. A named stream takes the
// matching player's nicer spelling ("spotify" -> "Spotify"); a nameless one
// belongs to the one player no named stream already accounts for.
function appName(node, players, streams) {
  if (!node) return "App"
  var raw = streamRawName(node)
  var picked
  if (isAnonymousStream(raw)) {
    var others = Array.isArray(streams) ? streams : []
    picked = pickPlayer(players, function(name) {
      for (var i = 0; i < others.length; i++) {
        var otherRaw = streamRawName(others[i])
        if (!isAnonymousStream(otherRaw) && overlap(alias(otherRaw), name)) return false
      }
      return true
    })
  } else {
    picked = pickPlayer(players, function(name) { return overlap(alias(raw), name) })
  }
  return alias(picked || raw) || "App"
}

// Whether this stream is the media player the rest of the shell treats as
// current, so its row can stand out.
function isCurrentPlayer(node, player, players, streams) {
  var name = playerName(player)
  return !!node && name !== "" && overlap(appName(node, players, streams), name)
}

// ---------------------------------------------------------------- microphone by app

function micAppName(app) {
  var text = String(app || "")
  if (text === "Cornerstone") return "Cornerstone Dictation"
  return alias(text).replace(/\s+input$/i, "").replace(/\.exe$/i, "") || text
}

// Apps recording now come first, then apps with a chosen mic, then the rest.
// Only the first group or two are shown until asked: the rest are apps that
// once opened a mic and are usually not of interest. `minimum` rows are always
// shown, and a single leftover is shown rather than hidden behind a button.
function arrangeMicApps(list, expanded, minimum) {
  var rank = function(r) { return r.live ? 0 : (r.pin ? 1 : 2) }
  var sorted = (Array.isArray(list) ? list : []).filter(function(r) { return r && r.app })
  sorted.sort(function(a, b) {
    return rank(a) - rank(b) || micAppName(a.app).toLowerCase().localeCompare(micAppName(b.app).toLowerCase())
  })
  var wanted = 0
  while (wanted < sorted.length && rank(sorted[wanted]) < 2) wanted++
  var keep = Math.max(wanted, minimum || 0)
  if (expanded || sorted.length <= keep + 1) return { shown: sorted, hidden: 0 }
  return { shown: sorted.slice(0, keep), hidden: sorted.length - keep }
}

if (typeof module !== "undefined") {
  module.exports = {
    GLYPH: GLYPH,
    props: props,
    isAppPlayback: isAppPlayback,
    isCaptureDevice: isCaptureDevice,
    isRecordingApp: isRecordingApp,
    row: row,
    rows: rows,
    rowKey: rowKey,
    sameRow: sameRow,
    parseAvailability: parseAvailability,
    tidyDeviceName: tidyDeviceName,
    deviceName: deviceName,
    deviceKind: deviceKind,
    deviceGlyph: deviceGlyph,
    outputLevelGlyph: outputLevelGlyph,
    percent: percent,
    alias: alias,
    streamRawName: streamRawName,
    pickPlayer: pickPlayer,
    appName: appName,
    isCurrentPlayer: isCurrentPlayer,
    micAppName: micAppName,
    arrangeMicApps: arrangeMicApps
  }
}
