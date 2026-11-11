# Cornerstone Audio

The sound icon in the Omarchy bar, and the panel it opens.

- **Bar icon**: click to open the panel, right-click to mute (or unmute) output and microphone together, scroll to
  change the volume. Super+Ctrl+A opens the panel from the keyboard.
- **Output and input**: volume sliders (right-click a slider to mute that channel), a live level meter for the mic,
  and the list of devices; click one to make it the default.
- **Apps**: every app playing sound, with its own volume (up to 150%) and the output it plays on. Click that line to
  send the app to a different output; PipeWire remembers the choice for next time.
- **Microphone by app**: every app that records, or has recorded before, with the mic it records from. Choose a mic
  for an app any time, even while it is closed; the choice is applied the moment it starts listening. Apps that are
  listening now or have a chosen mic are listed first; the rest fold behind "Show more". "Follow default input" also
  makes PipeWire forget the mic it remembered for that app, so the app really does follow the default next time.

The top of the panel shows where sound is going and which mic is in use, with one switch to mute both.

## Keyboard

Up / Down (or j / k) move through the panel, one stop at a time. The first press only shows where you are.

| Key | On a slider | On a device | On an app | On a microphone line |
| --- | --- | --- | --- | --- |
| Left / Right (h / l) | volume down / up | | volume down / up | close / open its list |
| Enter or Space | mute | make default | open its list of outputs | open its list of mics |
| m | mute | mute that channel | mute the app | mute the mic |
| o | | | send to the next output | |
| x or Delete | | | | follow the default input |

On the switch at the top, Enter, Space or m mutes output and mic together. Inside an open list, Enter picks and Left
goes back. Esc closes the panel, Tab moves to the next bar panel.

## Files

| File | What it is |
| --- | --- |
| `Panel.qml` | The bar icon, the panel layout and the keyboard cursor. |
| `AudioGraph.qml` | Everything read from PipeWire: devices, apps playing and recording, volumes. |
| `MicChoices.qml` | The saved microphone choices, kept by the helper below. |
| `Audio.js` | Naming, sorting and glyph rules, with no Qt in it. |
| `Nav.js` | The order of cursor stops and how the cursor moves between them. |
| `ui/` | The pieces the panel is drawn from (rows, sliders, the pick lists). |
| `bin/audio-route` | Moves an app to another output, and keeps the microphone choices. |
| `tests/` | `node tests/run.js` checks `Audio.js` and `Nav.js`; `tests/audio-route.sh` checks the helper on a scratch file. |

Microphone choices are kept in `~/.config/omarchy/audio-mic-pins.json`, one entry per app:
`{"<app name>": "<PipeWire source name>"}`. Cornerstone dictation reads its own entry (`"Cornerstone"`) from there,
so it records from whichever mic is chosen for it in this panel.

## Install

The folder goes in `~/.config/omarchy/plugins/cornerstone.audio`; the shell loads it on its own and reloads it when
a file changes. The manifest marks it as taking the place of Omarchy's built-in audio panel (`omarchy.audio`), which
is what makes Super+Ctrl+A and other calls for the audio panel open this one. To go back to the built-in panel,
change `cornerstone.audio` to `omarchy.audio` in `~/.config/omarchy/shell.json`.

Needs `jq`, `pactl`, `wpctl` and `pw-metadata` (all part of a normal Omarchy install).

## Credits

Omarchy's built-in audio panel (MIT, see `LICENSE`) was the starting point and remains the reference for how the
shell's panels behave. This version is written separately: its own data layer, cursor, naming rules, helpers and
layout, plus per-app outputs and microphone choices, which the built-in panel does not have.
