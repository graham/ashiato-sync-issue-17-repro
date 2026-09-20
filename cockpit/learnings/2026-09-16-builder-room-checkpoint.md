# Multiplayer builder room completion — 2026-09-16

Item 9 Step 6 is complete. The builder is a normal networked level with a parked craft,
host-authoritative seat assignment, per-seat station documents, host save, and late-join recovery.

## Final behavior

- The host creates one parked craft at its model origin. `seat_client_parked` assigns an exact
  builder seat without the ordinary pilot-seat launch transition.
- `host_entity` is the server's authority token. Each peer independently finds its replicated
  client entity handle for drawing and local station application; native worlds do not share
  entity handles.
- BOARD retries until the replicated occupant is in the requested seat. A duplicate request for
  the same occupant and seat is an idempotent success.
- One whole-layout proposal per seat may be in flight. Further releases replace the desired
  document and resend after the authoritative revision ACK. The ACK is compared with the exact
  proposal sent, so apply/serialize normalization cannot create a resend loop.
- The host validates entity token, kind, version, revision, seat occupancy, allowed devices,
  fitted channels, finite poses, station bounds, and operation schema. Forged other-seat and
  disallowed-part proposals are refused.
- A joining peer repeats READY until it receives the authoritative snapshot. Identical repeated
  LongTransfer sends retain selective-repeat ACK progress instead of replacing an in-flight
  document.
- SAVE is host-only and writes every seat under the chosen version. Test children pass
  `--builder-test-files=1`; `CraftPackage` reads both Godot argument lists and routes those files to
  `user://test_cockpit_packages`.
- Authored JSON is hashed after newline normalization, so LF manifests validate on CRLF checkouts.

## Proof

`builder_peers` passed in 16.4 seconds with three real Godot processes over ENet. Client A joined,
boarded seat 0, and made rapid desktop edits. Client B started only after revision 2 was authoritative,
received that revision in its first snapshot, boarded seat 1, and edited by the hand path. Host, A,
and B converged on both seats. The host refused A's forged other-seat proposal and B's disallowed
device, then saved and reloaded all four gunship stations. The saved Yoke moved 0.080 m and Trigger
0.400 m from their authored positions.

Focused affected suites passed: `lint`, `builder`, `builder_authority`, `builder_peers`,
`fleet_shapes`, `long_message`, `stations`, `levels`, `level_hello`, `lobby`, `lobby_peers`, and
`no_vr_flight`.

The windowed `builder_shot` passed with `--xr-mode off -- --desktop-only`. Its log contains no
OpenXR initialization, and both 1600×900 images were inspected:

- `screenshots/2026-09-16/item9-builder/builder_room.png` — parked craft and two generated stations.
- `screenshots/2026-09-16/item9-builder/builder_board.png` — readable craft, version, SAVE, and four
  seat BOARD actions.

## Broad harness result

The final broad run reached 76 passing suites before it was intentionally stopped while
`sky_peers` was active so the shared desktop guard could be merged. All Item 9 and adjacent network
suites passed in that run: `clipboard`, `builder`, `builder_authority`, `builder_peers`,
`craft_package`, every device-yard suite, `device_router`, `session`, `launch_order`, `two_peers`,
`desk_join`, `lobby`, `lobby_peers`, `crew_peers`, `levels`, `level_hello`, and `level_join`.

The non-Item-9 failures were preserved rather than retried:

- `editor:addon` could not resolve `AshiatoWorld` because that standalone project lacked its
  generated extension class cache.
- `smoke` failed existing model nose/tail and cockpit reach assertions.
- `names_shot` timed out under the old runner before the shared `--desktop-only` fix.
- `level_swap` ended without a RESULT line; `sky_peers` was the suite active when the run was
  stopped for the required runner update.

After merging that update, `PilotRig` was made to honor `--desktop-only` from both Godot argument
lists. A fresh runner-driven `no_vr_flight` passed in 12.3 seconds. A live process command-line
capture showed both `--xr-mode off` and `--desktop-only`; its log and a fresh passing windowed
`builder_shot` log contained no OpenXR initialization or runtime line.
