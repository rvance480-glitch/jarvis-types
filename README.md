# jarvis-types

TypeScript type definitions for Jarvis installation and lifecycle management.

## What's included

| Type | Purpose |
|---|---|
| `InstallMode` | How Jarvis is installed: `native`, `docker`, or `wsl2` |
| `InstallProfile` | User-chosen install settings (mode, port, repo, data dir, container, WSL distro, sidecar) |
| `SystemSummary` | Detected host facts: OS, arch, Docker/Bun availability, WSL distros |
| `InstallProgress`, `InstallResult` | Install progress events and final result |
| `LifecycleAction`, `LifecycleResult`, `InstallState` | Start / stop / restart / status / logs, and current state |
| `ProxyConfig`, `ProxyResult` | Exposing Jarvis on a custom domain through Cloudflare and a VPS |
| `JarvisReleaseNotice`, `UpdateResult` | Jarvis release checks and updates |
| `InstallerUpdateState` | The installer's own self-update status |

## Usage

```ts
import type { InstallProfile } from 'jarvis-types';

const profile: InstallProfile = {
  mode: 'docker',
  port: 3000,
  jarvisRepo: 'https://github.com/<owner>/<jarvis-repo>',
  installSidecar: false,
};
```

`SystemSummary.platform` uses `NodeJS.Platform`, so consumers need `@types/node`.

## Build

```sh
npm install
npm run build   # emits dist/index.d.ts
```

## Install Jarvis on Windows (one click)

The `windows/` folder has a setup script for [vierisid/jarvis](https://github.com/vierisid/jarvis).

1. Download this repository (green **Code** button, then **Download ZIP**) and unzip it.
2. Open the `windows` folder and double-click **Install Jarvis.cmd**.

The script:

1. Checks for Docker Desktop and offers to install it with `winget` if it is missing.
2. Starts Docker Desktop and waits until it is ready.
3. Runs the Jarvis brain in Docker on `http://localhost:3142` (restarts automatically with Docker).
4. Creates a connection token for your PC, copies it to the clipboard, and saves a copy to your desktop.
5. Downloads the official `jarvis-setup.exe` from the newest `sidecar-v*` release, checks it is signed by `Usejarvis Inc.`, and opens it.

When the Jarvis desktop app asks for a token, press `Ctrl+V` and click **Connect**. After the in-app setup, run `docker restart jarvis` once. Delete `Jarvis connection token.txt` from your desktop after connecting.

The script is safe to run again. Options (run from PowerShell):

```powershell
.\install-jarvis.ps1 -DeviceName "Office PC"   # name shown in Jarvis
.\install-jarvis.ps1 -SkipDesktopApp          # brain and token only
```

## Security

`ProxyConfig.cfApiToken` holds a Cloudflare API token. Store it in the OS keychain or an encrypted settings file, never in source control.
