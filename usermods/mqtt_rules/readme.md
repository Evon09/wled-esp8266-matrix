# MQTT Rules

Usermod that makes the board react to MQTT messages and publish events, using rules kept in a
file on the board (`/mqttrules.jsonl`). Nothing is compiled into the firmware per rule, and
almost no RAM is used while idle.

The rules are normally written with the **Regras MQTT** web tool (`ferramentas/mqtt/`), but the file
is plain JSON Lines and can be edited by hand.

## Enable

In `platformio_override.ini`:

```ini
custom_usermods = mqtt_rules
```

MQTT must be enabled (do not build with `WLED_DISABLE_MQTT`) and configured in *Config → Sync interfaces*.
Without MQTT the usermod compiles to nothing.

## Rule format

One JSON object per line, up to 760 characters.

Message rule (runs when a message arrives):

```json
{"k":"m","n":"name","e":1,"t":"%dev%/texto","o":"=","v":"on","a":"{...JSON API...}","d":10,"r":"{\"ps\":210}","b":1,"w":1,"pt":"%dev%/ack","pp":"done {p}"}
```

Event rule (runs when the board changes state):

```json
{"k":"e","n":"name","e":1,"ev":"ps","o":"*","pt":"%dev%/evento","pp":"preset {n}"}
```

| Key | Meaning |
|---|---|
| `k` | `m` message rule, `e` event rule |
| `e` | `0` disables the rule |
| `t` | topic filter (`+` and `#` wildcards, `%dev%` = device topic) |
| `o`, `v` | payload condition: `*` any, `=` equals, `c` contains, `>` greater, `<` smaller, `r` range `a,b` |
| `a` | JSON API command to run; `{p}` = payload (JSON-escaped), `{n}` = payload as integer |
| `d`, `r` | after `d` seconds run the JSON API command `r` (for example go back to a preset) |
| `b` | `1` = go back to the preset/playlist that was running before the action; `r` is the fallback |
| `w` | `1` = wait until the Scrolling Text effect finishes one pass; `d` is then only the time shown for text that fits the matrix |
| `pt`, `pp` | publish `pp` on topic `pt` after the rule ran (`{p}`, `{n}` available) |
| `ev` | event source: `ps` preset applied, `pw` power on/off, `br` brightness |

Limits: 10 subscribed topics, 4 queued messages, 6 log lines.

## JSON API

Send to `/json/state`:

```json
{"mqttr":{"reload":1}}
{"mqttr":{"test":{"t":"wled/board/texto","p":"HELLO"}}}
```

`reload` re-reads the rules file and re-subscribes. `test` simulates an incoming message and works
without a broker. Status appears in `/json/info` as `mqttr`: `n` rules, `hits`, `con` (broker
connected), `subs`, `log` (newest first).

## Notes

- Public brokers are readable and writable by anyone who knows the topic. Use a unique topic and turn MQTT off when done.
- The ESP8266 cannot use TLS and cannot resolve host names reliably: use the broker IP address.
- Parts of this code were written with AI assistance (marked in the source).
