// node tests/run.js: checks Audio.js and Nav.js, the parts of the panel that do
// not need a running shell. Node shapes mirror what pw-dump shows on a real
// desktop (Corsair HS80, Elgato Wave 3, moto buds+, HDMI monitor, Spotify).
const assert = require("assert")
const Audio = require("../Audio.js")
const Nav = require("../Nav.js")

let failed = 0
function test(name, fn) {
  try { fn(); console.log("ok   " + name) }
  catch (e) { failed++; console.log("FAIL " + name + "\n     " + e.message) }
}

const node = (o) => Object.assign({ ready: true, properties: {} }, o)
const hs80 = node({ id: 58, name: "alsa_output.usb-Corsair_Corsair_HS80_RGB_USB_Gaming_Headset-00.analog-stereo",
  isSink: true, audio: {}, description: "Corsair HS80 RGB USB Gaming Headset Analog Stereo",
  properties: { "node.nick": "Corsair HS80 RGB USB Gaming Hea", "device.form-factor": "headset", "device.icon-name": "audio-card-analog",
    "device.profile.description": "Analog Stereo" } })
const wave = node({ id: 46, name: "alsa_output.usb-Elgato_Systems_Elgato_Wave_3-00.analog-stereo", isSink: true, audio: {},
  description: "Elgato Wave 3 Analog Stereo", properties: { "node.nick": "Elgato Wave 3" } })
const waveMic = node({ id: 45, name: "alsa_input.usb-Elgato_Systems_Elgato_Wave_3-00.mono-fallback", audio: {},
  description: "Elgato Wave 3 Mono", properties: { "node.nick": "Elgato Wave 3" } })
const buds = node({ id: 117, name: "bluez_output.54_2F_04_11_D5_E8.1", isSink: true, audio: {}, description: "moto buds+" })
const hdmi = node({ id: 34, name: "alsa_output.pci-0000_0c_00.1.hdmi-stereo", isSink: true, audio: {},
  description: "Navi 31 HDMI/DP Audio Digital Stereo (HDMI) [KG251Q Z]", properties: { "node.nick": "KG251Q Z" } })
const onboard = node({ id: 44, name: "alsa_output.pci-0000_0e_00.4.analog-stereo", isSink: true, audio: {},
  description: "Starship/Matisse HD Audio Controller Analog Stereo", properties: { "node.nick": "ALC1220 Analog" } })
const spotifyStream = node({ id: 98, name: "spotify", isStream: true, isSink: true, audio: {},
  properties: { "application.name": "spotify", "media.name": "Spotify" } })
const chromeAnon = node({ id: 120, name: "Chromium", isStream: true, isSink: true, audio: {},
  properties: { "application.name": "audio-src" } })
const player = (identity, playing, extra) => Object.assign({ identity, isPlaying: playing, canPlay: true, dbusName: "org.mpris.MediaPlayer2." + identity }, extra || {})

test("a cut ALSA nickname gives way to the full description", () => {
  assert.strictEqual(Audio.deviceName(hs80), "Corsair HS80 RGB USB Gaming Headset")
})
test("a laptop profile name beats the card description", () => {
  assert.strictEqual(Audio.deviceName(node({ id: 3, name: "alsa_output.pci.HiFi__Speaker__sink",
    description: "Tiger Lake-LP Smart Sound Technology Audio Controller Speaker",
    properties: { "device.profile.description": "Speaker" } })), "Speaker")
})
test("a whole nickname is kept", () => {
  assert.strictEqual(Audio.deviceName(wave), "Elgato Wave 3")
  assert.strictEqual(Audio.deviceName(waveMic), "Elgato Wave 3")
  assert.strictEqual(Audio.deviceName(hdmi), "KG251Q Z")
})
test("profile words come off a description", () => {
  assert.strictEqual(Audio.tidyDeviceName("Elgato Wave 3 Mono"), "Elgato Wave 3")
  assert.strictEqual(Audio.tidyDeviceName("Navi 31 HDMI/DP Audio Digital Stereo (HDMI)"), "Navi 31 HDMI/DP Audio")
  assert.strictEqual(Audio.tidyDeviceName("Built-in Audio Analog Stereo"), "Built-in Audio")
  assert.strictEqual(Audio.tidyDeviceName("Built-in Audio Headphones"), "Headphones")
  assert.strictEqual(Audio.deviceName(node({ id: 1, name: "x" })), "x")
  assert.strictEqual(Audio.deviceName(null), "Unknown device")
})
test("device kinds", () => {
  assert.strictEqual(Audio.deviceKind(hs80, false), "headphones")
  assert.strictEqual(Audio.deviceKind(buds, false), "headphones")
  assert.strictEqual(Audio.deviceKind(hdmi, false), "display")
  assert.strictEqual(Audio.deviceKind(wave, false), "speaker")
  assert.strictEqual(Audio.deviceKind(waveMic, true), "mic")
  assert.strictEqual(Audio.deviceKind(node({ id: 2, name: "bluez_output.AA.1", description: "JBL Flip 5" }), false), "bluetooth")
})
test("level glyph follows volume on speakers, says headphones on headphones", () => {
  const G = Audio.GLYPH
  assert.strictEqual(Audio.outputLevelGlyph(wave, 0.8, false), G.levelHigh)
  assert.strictEqual(Audio.outputLevelGlyph(wave, 0.5, false), G.levelMid)
  assert.strictEqual(Audio.outputLevelGlyph(wave, 0.1, false), G.levelLow)
  assert.strictEqual(Audio.outputLevelGlyph(wave, 0.8, true), G.levelOff)
  assert.strictEqual(Audio.outputLevelGlyph(wave, 0, false), G.levelOff)
  assert.strictEqual(Audio.outputLevelGlyph(hs80, 0.8, false), G.headphones)
  assert.strictEqual(Audio.outputLevelGlyph(null, 0.8, false), G.levelOff)
})
test("classification", () => {
  assert.ok(Audio.isAppPlayback(spotifyStream))
  assert.ok(!Audio.isAppPlayback(hs80))
  assert.ok(Audio.isAppPlayback({ isStream: true, isSink: false, type: "Stream/Output/Audio" }))
  assert.ok(Audio.isCaptureDevice(waveMic))
  assert.ok(!Audio.isCaptureDevice(hs80))
  assert.ok(Audio.isCaptureDevice({ name: "easyeffects_source" }, { easyeffects_source: true }))
  assert.ok(!Audio.isCaptureDevice({ name: "Midi-Bridge", type: "Midi/Bridge" }, {}))
  assert.ok(Audio.isRecordingApp({ name: "Discord", isStream: true, isSink: false, audio: {} }))
  assert.ok(!Audio.isRecordingApp({ name: "quickshell-peak", isStream: true, isSink: false, audio: {} }))
})
test("rows hold primitives only", () => {
  assert.deepStrictEqual(Audio.rows([wave, null, { name: "no id" }]), [{ id: 46, name: wave.name }])
  assert.ok(Audio.sameRow(Audio.row(wave), { id: 46, name: wave.name }))
  assert.ok(!Audio.sameRow(Audio.row(wave), { id: 46, name: "something else" }))
})
test("availability lines", () => {
  assert.deepStrictEqual(Audio.parseAvailability("a\t1\nb\t0\n\nbad\n"), { a: true, b: false })
})
test("a named stream takes the matching player's spelling", () => {
  assert.strictEqual(Audio.appName(spotifyStream, [player("Spotify", true)], [spotifyStream]), "Spotify")
  assert.strictEqual(Audio.appName(spotifyStream, [], [spotifyStream]), "Spotify")  // alias
})
test("a nameless stream belongs to the one unclaimed player", () => {
  const players = [player("Spotify", true), player("Brave", false)]
  assert.strictEqual(Audio.appName(chromeAnon, players, [spotifyStream, chromeAnon]), "Brave")
  assert.strictEqual(Audio.appName(chromeAnon, [player("A", true), player("B", true)], [chromeAnon]), "audio-src")
})
test("playerctld counts only when no real player fits", () => {
  const proxy = player("Brave", true, { dbusName: "org.mpris.MediaPlayer2.playerctld", desktopEntry: "playerctld" })
  assert.strictEqual(Audio.pickPlayer([proxy, player("Brave", false)], () => true), "Brave")
  assert.strictEqual(Audio.pickPlayer([proxy], () => true), "Brave")
})
test("a playing player wins over paused ones", () => {
  assert.strictEqual(Audio.pickPlayer([player("A", false), player("B", true)], () => true), "B")
  assert.strictEqual(Audio.pickPlayer([player("A", false), player("B", false)], () => true), "")
})
test("current player", () => {
  assert.ok(Audio.isCurrentPlayer(spotifyStream, player("Spotify", true), [player("Spotify", true)], [spotifyStream]))
  assert.ok(!Audio.isCurrentPlayer(spotifyStream, null, [], []))
})
test("mic app names", () => {
  assert.strictEqual(Audio.micAppName("Cornerstone"), "Cornerstone Dictation")
  assert.strictEqual(Audio.micAppName("Brave input"), "Brave")
  assert.strictEqual(Audio.micAppName("NBA2K27.exe"), "NBA2K27")
  assert.strictEqual(Audio.micAppName("WEBRTC VoiceEngine"), "Discord")
})
test("app icon candidates", () => {
  const c = Audio.appIconCandidates("Cornerstone Dictation", null)
  assert.ok(c.indexOf("cornerstone-hq") !== -1)
  const g = Audio.appIconCandidates("Google Chrome", node({ properties: { "application.icon-name": "google-chrome" } }))
  assert.strictEqual(g[0], "google-chrome")
})
test("mic apps: recording, then chosen, then the rest folded away", () => {
  const list = [
    { app: "Zed", live: false, pin: "" }, { app: "Brave input", live: true, pin: "" },
    { app: "Claude", live: false, pin: "m" }, { app: "Cornerstone", live: false, pin: "m" },
    { app: "Alpha", live: false, pin: "" }, { app: "Beta", live: false, pin: "" }
  ]
  const folded = Audio.arrangeMicApps(list, false, 3)
  assert.deepStrictEqual(folded.shown.map(r => r.app), ["Brave input", "Claude", "Cornerstone"])
  assert.strictEqual(folded.hidden, 3)
  assert.strictEqual(Audio.arrangeMicApps(list, true, 3).shown.length, 6)
  // one leftover is shown, not hidden behind a button
  assert.strictEqual(Audio.arrangeMicApps(list.slice(0, 4), false, 3).hidden, 0)
  // nothing chosen or recording: the minimum still shows
  assert.strictEqual(Audio.arrangeMicApps([{ app: "a" }, { app: "b" }, { app: "c" }, { app: "d" }, { app: "e" }], false, 3).shown.length, 3)
})
test("percent", () => {
  assert.strictEqual(Audio.percent(0.456), "46%")
  assert.strictEqual(Audio.percent(undefined), "0%")
})

const outs = [{ id: 1, name: "o1" }, { id: 2, name: "o2" }]
const ins = [{ id: 5, name: "i1" }]
const apps = [{ id: 9, name: "spotify" }]
test("stops read top to bottom", () => {
  const stops = Nav.buildStops({ outputs: outs, inputs: ins, inputSlider: true, apps, mics: [{ app: "Claude" }], moreMics: true })
  assert.deepStrictEqual(stops.map(s => s.key), ["master", "out", "out:1", "out:2", "in", "in:5", "app:9", "mic:Claude", "more"])
})
test("an open picker adds its choices under its row", () => {
  const stops = Nav.buildStops({ outputs: outs, inputs: ins, inputSlider: true, apps, openApp: "9\nspotify", mics: [{ app: "Claude" }], openMic: "Claude" })
  assert.deepStrictEqual(stops.map(s => s.key).slice(6),
    ["app:9", "app:9>1", "app:9>2", "mic:Claude", "mic:Claude>", "mic:Claude>i1"])
  assert.strictEqual(stops[7].choice.name, "o1")
})
test("no default input: no input slider stop", () => {
  const stops = Nav.buildStops({ outputs: outs, inputs: ins, inputSlider: false })
  assert.strictEqual(Nav.indexOfKey(stops, "in"), -1)
})
test("stepping clamps at both ends and survives a vanished stop", () => {
  const stops = Nav.buildStops({ outputs: outs, inputs: ins, inputSlider: true, apps })
  assert.strictEqual(Nav.step(stops, "master", 0, -1).key, "master")
  assert.strictEqual(Nav.step(stops, "app:9", 6, 1).key, "app:9")
  assert.strictEqual(Nav.step(stops, "out:1", 2, 1).key, "out:2")
  // out:7 was at index 3 and is gone: down lands on what took its place, up on the one before
  assert.strictEqual(Nav.step(stops, "out:7", 3, 1).key, "out:2")
  assert.strictEqual(Nav.step(stops, "out:7", 3, -1).key, "out:1")
  assert.strictEqual(Nav.step([], "x", 0, 1), null)
})

if (failed) { console.log(failed + " failed"); process.exit(1) }
console.log("all passed")
