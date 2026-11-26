# game_relay

Relays small messages between the browsers that have the games page (`jogos.htm`) open, so a second device can act as the other player's controller.

- Send `{"gm":{...}}` to `/json/state` or over the WebSocket; every WebSocket client receives `{"gm":{...}}` (the sender too).
- Messages longer than about 310 characters are dropped. The board does not read the content and stores nothing.
- `/json/info` reports `"gmr":1`.
- There is no authentication: as with the rest of the WLED API, anyone on the local network can send these messages.

Enable with `custom_usermods = game_relay` in the build environment. Needs WebSockets.
