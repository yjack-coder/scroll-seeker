# Development environment and engine installation

Inspected on 2026-10-02, without changing the selected Xcode toolchain.

| Item | Observed |
| --- | --- |
| Mac | MacBook Pro, Apple M5, 10 CPU cores, ARM64 |
| Memory | 24 GB |
| macOS | 27.0, build 26A428 |
| Initial available disk | Approximately 63 GiB on the system/APFS volume (`df -h /`) |
| Active developer tools | `/Applications/Xcode-beta.app/Contents/Developer`, Xcode 27.0 |
| Other existing Xcode versions | Xcode.app reports 26.5; Xcode_27.1.app reports 27.1 |
| Existing tools | Git 2.54.0, Homebrew, GitHub CLI, Visual Studio Code, Android Studio |
| Unity initially | No editor or Hub installed |
| Installed Hub | 3.21.3, native Apple Silicon, official download installed through Homebrew |
| Selected editor | Unity 6.3 LTS, 6000.3.25f1, revision e1dba0a9aba4, native ARM64 |

The official Unity release service returned the selected editor as LTS, released 2026-09-24. Its installer is 5,186,642,467 bytes; stated installed editor size is 9,562,625,000 bytes. Allow additional room for package cache, project Library and builds. The supplied desktop target uses bundled macOS Mono support. Android, Web, Windows, iOS and IL2CPP support are not required for this Mac slice and were not selected. The Hub's automatically recommended Unity 6.6 download was canceled to avoid duplicate editors. Account login, license eligibility and terms acceptance were handled by the user.

The official installer checksum and Apple-trusted Unity installer signature were verified before extraction. The installed editor occupies approximately 9.2 GiB. After building the project and removing the downloaded installer cache, `df -h /` reported approximately **52 GiB available**. The supplied Mac development player occupies approximately 294 MiB. No existing application or Xcode installation was removed.

Editor source: [Unity release archive](https://unity.com/releases/editor/archive), [Unity 6 LTS support](https://unity.com/releases/unity-6). The installer and expected checksum were obtained from Unity's official release API and download domain. No unofficial engine mirror is used.

## Unreal assessment

Unreal Engine was assessed, not installed. No Epic Launcher, additional IDE or large optional SDK was added.

The current [Epic macOS requirements for UE 5.8](https://dev.epicgames.com/documentation/en-us/unreal-engine/macos-development-requirements-for-unreal-engine) list Apple Silicon, 16 GB minimum memory and 32 GB recommended memory, Sonoma 14.5 minimum, Xcode 26.0 minimum and 26.1.1 recommended. This Mac exceeds the CPU and minimum memory requirements, but its 24 GB falls below the recommended memory. The installed newer macOS/Xcode combinations have not been verified against Unreal here; the official matrix does not establish their compatibility. Xcode was not switched or replaced for this work.

Epic requires the [Epic Games Launcher and an Epic account](https://www.unrealengine.com/download) for the ordinary binary install. Engine options determine the actual installation size. We did not log into Epic or obtain a version-specific Launcher size quote, so there is no measured exact additional size to claim.

For planning, reserve **100 GiB of free working space** for a separate Unreal editor, download staging, a small project and derived shader/cache data; 60–80 GiB is a rough editor-only allowance, not a vendor-guaranteed size. Against the post-Unity reading of 52 GiB available, reaching that 100 GiB budget requires freeing or adding **approximately 48 GiB more**. Optional source, symbols, templates, platform SDKs and an additional Xcode can materially increase this. Check the Launcher's Options size after login before installing. An external development SSD is a reasonable destination if disk capacity is expanded later.
