# Hangar

A macOS menu bar app and CLI for the machines you develop against: UTM virtual machines and
Docker containers, side by side, started and stopped together.

- **VMs** — start, suspend, shut down (asks the guest OS; force stop is in the right-click
  menu), copy the guest's IP. Works while UTM is closed: VMs are listed from the last time
  UTM was seen, and starting one launches UTM hidden in the background.
- **Containers** — grouped by compose project, start / stop / restart, published ports open
  in the browser. Talks to the Docker socket directly (Docker Desktop, OrbStack, Colima or
  `DOCKER_HOST`).
- **Profiles** — a named set of VMs and containers, e.g. a VM plus the databases it needs.
  Press **+** to save what is running now; right-click any row to add or remove it.

## CLI

The app binary is also the CLI: run it with a command and it does that and exits.

```sh
ln -s /Applications/Hangar.app/Contents/MacOS/Hangar ~/.local/bin/hangar

hangar status
hangar up work            # start a profile
hangar down work
hangar vm start berqNET
hangar ps
hangar logs -f hermes-postgres
hangar sql hermes-postgres "select * from users limit 5"
hangar help
```

Profiles can be managed entirely from the CLI — handy for scripts, or for letting Claude
set them up:

```sh
hangar profile create work
hangar profile add work berqNET hermes-postgres     # VMs by name/UUID, containers by name/id
hangar profile add work container:db                 # prefix when a name means both
hangar profile remove work hermes-postgres
hangar profile rename work "work 2"
hangar profile show "work 2" --json
```

Every listing and profile command takes `--json` for machine-readable output.

The app and the CLI share their state as JSON in `~/Library/Application Support/Hangar/`
(`profiles.json` is meant to be hand-editable), so a change from either side shows up in
the other.

## Build

Requires Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen), swift-format and SwiftLint.

```sh
make build     # generate the project and build
make test      # unit tests (Swift Testing)
make format    # swift-format
make lint      # swift-format lint + SwiftLint
make run       # build and (re)launch the app
```

Hangar is not sandboxed — it needs the Docker socket and Apple Events to UTM — so it is
distributed outside the Mac App Store. macOS asks once for permission to control UTM.
