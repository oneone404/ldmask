# LDMask

Personal Kitsune-derived root manager for LDPlayer. This is not an official
Magisk/Kitsune release.

- [Download APK and both modules](https://github.com/oneone404/ldmask/releases/latest)
- [Fork, provenance, build and installation notes](LDMask.md)
- [Tests](tests/README.md)

App: **LDMask** (`io.github.oneone404.ldmask`). Tools lets users select server-published
**LDLogin / LDMenu** from the latest stable release, verify/install the selection,
then remove temporary ZIPs. After successful installation, modules outside the
complete server-published list are marked for removal at reboot. Unchecked but
allowed modules are retained. No automatic reboot or added resident service.

- [Native LDLogin configuration](docs/module-ui.md)
- [Server publication controls](docs/module-publication.md) — public visibility,
  not access control; do not publish binaries that must remain private.
The package/native manager identity differs from the original baseline, so
reinstall the root environment for LDMask rather than replacing only its APK.

Experimental build; release-mode binaries, local Android debug signing key.
Preserve upstream licenses and credits. The bundled LDMenu payload is user-supplied
binary material, not source audited by this project.

---

## Original upstream project information (retained for attribution)

![](docs/images/logo.png#gh-dark-mode-only)
![](docs/images/logo_dark.png#gh-light-mode-only)

[![Downloads](https://img.shields.io/badge/dynamic/json?color=green&label=Downloads&query=totalString&url=https%3A%2F%2Fraw.githubusercontent.com%2Ftopjohnwu%2Fmagisk-files%2Fcount%2Fcount.json&cacheSeconds=1800)](https://raw.githubusercontent.com/topjohnwu/magisk-files/count/count.json)

#### This is not an officially supported Google product

## Introduction

Magisk is a suite of open source software for customizing Android, supporting devices higher than Android 6.0.<br>
Some highlight features:

- **MagiskSU**: Provide root access for applications
- **Magisk Modules**: Modify read-only partitions by installing modules
- **MagiskBoot**: The most complete tool for unpacking and repacking Android boot images
- **Zygisk**: Run code in every Android applications' processes

## Downloads

[Github](https://github.com/topjohnwu/Magisk/) is the only source where you can get official Magisk information and downloads.

[![](https://img.shields.io/badge/Magisk-v26.4-blue)](https://github.com/topjohnwu/Magisk/releases/tag/v26.4)
[![](https://img.shields.io/badge/Magisk%20Beta-v27.0-blue)](https://github.com/topjohnwu/Magisk/releases/tag/v27.0)
[![](https://img.shields.io/badge/Magisk-Canary-red)](https://raw.githubusercontent.com/topjohnwu/magisk-files/canary/app-release.apk)
[![](https://img.shields.io/badge/Magisk-Debug-red)](https://raw.githubusercontent.com/topjohnwu/magisk-files/canary/app-debug.apk)

## Useful Links

- [Installation Instruction](https://topjohnwu.github.io/Magisk/install.html)
- [Building and Development](https://topjohnwu.github.io/Magisk/build.html)
- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)

## Bug Reports

**Only bug reports from Debug builds will be accepted.**

For installation issues, upload both boot image and install logs.<br>
For Magisk issues, upload boot logcat or dmesg.<br>
For Magisk app crashes, record and upload the logcat when the crash occurs.

## Translation Contributions

Default string resources for the Magisk app and its stub APK are located here:

- `app/src/main/res/values/strings.xml`
- `stub/src/main/res/values/strings.xml`

Translate each and place them in the respective locations (`[module]/src/main/res/values-[lang]/strings.xml`).

## License

    Magisk, including all git submodules are free software:
    you can redistribute it and/or modify it under the terms of the
    GNU General Public License as published by the Free Software Foundation,
    either version 3 of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
