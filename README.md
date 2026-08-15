# Airpad (Phase 1)

Phone-as-wireless-trackpad for **Windows** and **macOS**. Linux is out of scope.
This repo contains **only the phone client** — the desktop host ships in Prompt 2.

## What it does

Turn an iOS or Android phone into a precision wireless trackpad over a local
Wi-Fi network. Latency target ~12 ms end-to-end. The phone renders a raw
`Listener` touch surface, classifies gestures (tap / drag / two-finger scroll /
two-finger right-click) locally, and streams normalized pointer events to the
host over a length-prefixed binary TCP stream.

## Project layout

```
lib/
  main.dart                       entry point
  app.dart                        MaterialApp + GoRouter wiring
  core/
    protocol/
      messages.dart               MessageType enum + payload encoders
      codec.dart                  4-byte LE length-prefix frame writer
    transport/
      transport.dart              abstract Transport interface
      tcp_transport.dart          dart:io Socket + TCP_NODELAY
    time/
      clock.dart                  monotonic microsecond Stopwatch
  features/
    trackpad/
      pages/trackpad_page.dart    trackpad screen + debug overlay
      widgets/trackpad_surface.dart raw Listener touch surface
      controllers/
        gesture_recognizer.dart   custom tap/drag/scroll recognizer
        touch_sender.dart         120 Hz throttled coalescing sender
    connection/
      pages/connection_page.dart  IP + port form, connect button
      controllers/
        connection_controller.dart  connect / disconnect state (MobX)
    settings/
      pages/settings_page.dart    sensitivity + scroll speed + debug toggle
```

## Wire protocol

- TCP stream. 4-byte little-endian length prefix + payload.
- One connection = one stream. No JSON.
- All multi-byte fields are little-endian.
- Coordinates are normalized `0.0..1.0` from the phone surface.

| Type ID | Name        | Payload                                                                 |
|---------|-------------|-------------------------------------------------------------------------|
| 0x1     | HELLO       | utf8 name, u16 screen_w, u16 screen_h                                   |
| 0x2     | PING        | u64 timestamp_us                                                        |
| 0x3     | TOUCH_DOWN  | u16 finger_id, f32 x, f32 y, f32 pressure, u64 t_us                     |
| 0x4     | TOUCH_MOVE  | same as TOUCH_DOWN                                                       |
| 0x5     | TOUCH_UP    | u16 finger_id                                                            |
| 0x6     | SCROLL      | f32 dx, f32 dy                                                           |
| 0x7     | BUTTON      | u8 btn (0=left, 1=right), u8 state (0=up, 1=down)                       |
| 0x8     | GESTURE     | u16 kind (1 = tap)                                                       |

## How to run

```bash
cd airpad
flutter pub get
flutter run            # on a real device or simulator
```

The phone starts on the **Connection** screen. Enter the IP and port shown by
the host app (default port **9876**) and tap **Connect**. The Trackpad screen
appears with a full-surface touch area.

### Settings

- **Sensitivity** — multiplier applied to drag deltas before the host scales
  them onto the desktop cursor.
- **Scroll speed** — multiplier applied to two-finger scroll deltas.
- **Debug overlay** (debug builds only) — small panel on the trackpad showing
  active finger count and ms since the last sent event.

Both sliders persist via `shared_preferences`.

## Phase 1 boundaries

What's intentionally NOT in this app:

- Desktop host (Tauri/Rust). Prompt 2.
- BLE transport. Prompt 2.
- QR-code pairing. Host will hand the user the IP + port in Phase 1.
- Right-click via two-finger hold, three-finger gestures, acceleration curve.
  Phase 2.
- Pairing tokens / auth. Local network only.
- Linux.

## What's stubbed vs. real

- Real: the gesture recognizer, the 120 Hz throttled sender, the length-prefixed
  binary framing, TCP_NODELAY, the settings persistence, the connection state
  machine, the debug overlay.
- Stubbed (no host yet): the wire protocol is fully implemented but the phone
  has nothing to talk to until the desktop app lands. You can still verify the
  app builds, launches, and accepts a connection attempt.

## Dependencies

`mobx`, `flutter_mobx`, `mobx_codegen`, `build_runner`, `qr_code_scanner_plus`,
`mobile_scanner`, `go_router`, `shared_preferences`. Networking uses only
`dart:io` — no third-party socket libraries.

`mobx_codegen` and `build_runner` are present so Phase 2 stores can be added
with `part 'foo.g.dart'`; the Phase 1 connection controller is hand-written
with `Observable` to avoid spinning up codegen for two fields.

## Verification

```bash
flutter analyze          # clean
flutter build apk --debug
flutter build ios --debug --no-codesign
```

## Next (Prompt 2)

- Tauri host app: TCP listener on 9876, OS-level pointer synthesis, settings UI
  for the host's own configuration, multi-device pairing.
- Airpad discovery over local network (mDNS / broadcast) so the phone doesn't
  have to type the IP.
- QR-code pairing path using the deps already in `pubspec.yaml`.
