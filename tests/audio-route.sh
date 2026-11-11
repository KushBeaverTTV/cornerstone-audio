#!/usr/bin/env bash
# Checks audio-route's pins file handling against a scratch copy; never touches
# the real ~/.config/omarchy/audio-mic-pins.json. Apps named here do not exist,
# so no stream is moved.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
route=$here/bin/audio-route
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
export CORNERSTONE_AUDIO_PINS=$work/pins.json
export CORNERSTONE_AUDIO_WP_STATE=$work/none
export CORNERSTONE_AUDIO_RELEASED=$work/released
fail=0
check() { if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got '$2' want '$3'"; fail=1; fi; }

printf '{"Cornerstone":"mic.a"}' >"$CORNERSTONE_AUDIO_PINS"
"$route" pin "Test App One" mic.b
check "pin adds an entry" "$(jq -r '."Test App One"' "$CORNERSTONE_AUDIO_PINS")" "mic.b"
check "pin keeps the Cornerstone entry" "$(jq -r .Cornerstone "$CORNERSTONE_AUDIO_PINS")" "mic.a"

for n in 1 2 3 4 5 6; do "$route" pin "Test App $n" "mic.$n" & done; wait
check "parallel pins all land" "$(jq 'keys | length' "$CORNERSTONE_AUDIO_PINS")" "8"

"$route" unpin "Test App 3"
check "unpin removes only that app" "$(jq -r 'has("Test App 3"), has("Test App 4")' "$CORNERSTONE_AUDIO_PINS" | tr '\n' ' ')" "false true "

printf 'not json' >"$CORNERSTONE_AUDIO_PINS"
"$route" pin "Test App One" mic.b
check "a broken file is replaced, not appended to" "$(jq -c . "$CORNERSTONE_AUDIO_PINS")" '{"Test App One":"mic.b"}'

rm -f "$CORNERSTONE_AUDIO_PINS"
check "mics lists a pinned app with no file history" "$("$route" pin "Test App Two" mic.c; "$route" mics | jq -r '.[] | select(.app == "Test App Two") | .pin')" "mic.c"

: >"$CORNERSTONE_AUDIO_RELEASED"
"$route" unpin "Test App Two"
check "letting go of an app that is not recording remembers to clear it later" "$(cat "$CORNERSTONE_AUDIO_RELEASED")" "Test App Two"
"$route" pin "Test App Two" mic.d
check "choosing a mic again cancels that" "$(cat "$CORNERSTONE_AUDIO_RELEASED")" ""
"$route" unpin "Test App Two"; "$route" unpin "Test App Two"
check "an app is listed once however often it is let go" "$(grep -c . "$CORNERSTONE_AUDIO_RELEASED")" "1"

"$route" play 999999 nowhere 2>/dev/null; check "play on a missing stream fails quietly" "$?" "3"
"$route" bogus 2>/dev/null; check "unknown command exits 2" "$?" "2"
exit $fail
