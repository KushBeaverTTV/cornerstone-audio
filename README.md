# Audio (cornerstone.audio)

A clone of Omarchy's built-in sound panel (`omarchy.audio`, cloned 9 Nov 2026) with one addition: each app in the
list has a line naming the device it plays on. Click the line for the list of devices and click one to send the app
there; or put the keyboard cursor on the app and press `o` to send it to the next device. The system remembers the
choice per app.

- `Panel.qml` — the panel. The additions are marked "added in this clone" and "Keyboard parity for the device picker".
  It is also allowed to grow to 900 px (stock: 560) so the apps are not below the fold.
- `move-stream` — the helper that moves an app's sound (`move-stream <stream node id> <sink node name>`).
- `Panel.qml.stock` — the untouched file as cloned, to compare against a newer Omarchy version.

Changes to these files only take effect after `omarchy restart shell`.
To go back to the built-in panel: change `cornerstone.audio` to `omarchy.audio` in `~/.config/omarchy/shell.json`.
Being a clone, it does not pick up Omarchy's own later improvements to the sound panel.

## Microphone by app (10 Nov 2026)

The bottom section lists every app that records or has recorded before, each with the mic chosen for it. Click the
mic line, then a mic, to always feed that app from it; "Follow default input" lets go. A choice can be made while the
app is not recording: it is kept in `~/.config/omarchy/audio-mic-pins.json` and the panel applies it the moment the
app opens the microphone.

- `mic-apps` — the helper behind it (`mic-apps list | pin <app> <source> | unpin <app> | enforce`).
- Cornerstone dictation is not listed: it takes its mic from its own config (`mic_target`).
