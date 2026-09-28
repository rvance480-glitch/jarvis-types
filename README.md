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

## Security

`ProxyConfig.cfApiToken` holds a Cloudflare API token. Store it in the OS keychain or an encrypted settings file, never in source control.
