# Arsenal Report

## System Facts
- host: archlinux
- os: Arch Linux (arch)
- kernel: 6.16.1-arch1-1
- architecture: x86_64
- captured_utc: 2026-03-24T14:46:01Z

## Counts By Source
| source | count |
|---|---:|
| pacman explicit | 198 |
| AUR/foreign | 9 |
| pipx | 7 |
| flatpak apps | 9 |
| blackarch subset | 58 |
| unmanaged/manual | 17 |

## Install-Ready (Automatic)
- pkglist.pacman.txt
- pkglist.aur.txt
- pkglist.pipx.txt
- pkglist.flatpak.txt
- pkglist.blackarch.txt (validation/report only)

## BlackArch Tools
- `blackarch-keyring`
- `blackarch-officials`
- `bladerf`
- `bless`
- `bloodhound`
- `bloodyad`
- `commix`
- `dirb`
- `enum4linux`
- `evil-winrm`
- `exiv2`
- `ffuf`
- `flask-unsign`
- `gconf`
- `gtk2`
- `gtk-sharp-2`
- `hashid`
- `kerbrute`
- `neo4j-community`
- `ngrok`
- `polenum`
- `python2`
- `python2-certifi`
- `python2-chardet`
- `python2-click`
- `python2-flask`
- `python2-idna`
- `python2-itsdangerous`
- `python2-jinja`
- `python2-markupsafe`
- `python2-requests`
- `python2-urllib3`
- `python2-werkzeug`
- `python2-yaml`
- `python-argparse`
- `python-asyauth`
- `python-asysocks`
- `python-bs4`
- `python-click-plugins`
- `python-dsinternals`
- `python-flask-socketio`
- `python-future`
- `python-minikerberos`
- `python-msldap`
- `python-neo4j-driver`
- `python-ptrace`
- `python-selenium`
- `python-unicrypto`
- `python-winacl`
- `python-yara`
- `responder`
- `rtkit`
- `sbc`
- `smbmap`
- `ssrfmap`
- `sstimap`
- `steghide`
- `tplmap`

## pipx Tools
- `arjun`
- `bloodyad`
- `impacket`
- `netexec`
- `penelope`
- `pwncat-vl`
- `sploitscan`

## Flatpak Apps
- `com.rafaelmardojai.Blanket`
- `com.visualstudio.code`
- `io.github.fastrizwaan.WineZGUI`
- `io.github.flattool.Warehouse`
- `io.podman_desktop.PodmanDesktop`
- `org.audacityteam.Audacity`
- `org.remmina.Remmina`
- `org.telegram.desktop`
- `org.winehq.Wine`

## Unmanaged/Manual Tools
- `/home/kali/.local/bin/cmark`
- `/home/kali/.local/bin/fsdump`
- `/home/kali/.local/bin/fsoids`
- `/home/kali/.local/bin/fsrefs`
- `/home/kali/.local/bin/fstail`
- `/home/kali/.local/bin/killport`
- `/home/kali/.local/bin/repozo`
- `/home/kali/.local/bin/runzeo`
- `/home/kali/.local/bin/zconfig`
- `/home/kali/.local/bin/zconfig_schema2html`
- `/home/kali/.local/bin/zdaemon`
- `/home/kali/.local/bin/zeo-nagios`
- `/home/kali/.local/bin/zeoctl`
- `/home/kali/.local/bin/zeopack`
- `/usr/local/bin/docker-compose`
- `/usr/local/bin/gost`
- `/usr/local/bin/wireguird`

## Top Manual Tools By Risk
- [high] `/usr/local/bin/docker-compose`
- [high] `/usr/local/bin/gost`
- [high] `/usr/local/bin/wireguird`
- [low] `/home/kali/.local/bin/cmark`
- [low] `/home/kali/.local/bin/fsdump`
- [low] `/home/kali/.local/bin/fsoids`
- [low] `/home/kali/.local/bin/fsrefs`
- [low] `/home/kali/.local/bin/fstail`
- [low] `/home/kali/.local/bin/killport`
- [low] `/home/kali/.local/bin/repozo`
- [low] `/home/kali/.local/bin/runzeo`
- [low] `/home/kali/.local/bin/zconfig`
- [low] `/home/kali/.local/bin/zconfig_schema2html`
- [low] `/home/kali/.local/bin/zdaemon`
- [low] `/home/kali/.local/bin/zeoctl`

## Install Gaps
- Automatic install covers package-manager manifests above.
- Manual follow-up required for 17 unmanaged/manual tool(s) listed in `arsenal.manual.csv`.
