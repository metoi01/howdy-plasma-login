# howdy-plasma-login

Face unlock at the **KDE Plasma Login Manager** login screen, using
[Howdy](https://github.com/boltgolt/howdy), on **Bazzite**, **Fedora KDE** and
other **Fedora Atomic** (Kinoite) systems.

[Türkçe README](README.tr.md)

## The problem

You install Howdy, enroll your face, and it works on the lock screen and with
`sudo`. Then you reboot and the login screen just asks for your password.

This happens for two reasons:

1. **The login screen uses a different PAM file.** The KDE lock screen reads
   `/etc/pam.d/kde`, but Plasma Login Manager reads `plasmalogin`. On
   image-based systems such as Bazzite, that file lives in `/usr/lib/pam.d/`,
   which is read-only, so most guides miss it.
2. **SELinux blocks the camera.** The login screen runs as `xdm_t`, and
   Fedora's policy doesn't let it memory-map the camera:

   ```
   avc: denied { map } for comm="python3" path="/dev/video3"
   scontext=system_u:system_r:xdm_t tcontext=system_u:object_r:v4l_device_t
   ```

   The lock screen runs as your user, so it isn't affected. That's why face
   unlock works there but not at boot.

This repository fixes both problems with one script, and the uninstall script
undoes all of it.

## Requirements

- KDE Plasma with Plasma Login Manager. SDDM is used as a fallback.
- Howdy installed, with your face enrolled (`sudo howdy add`).
- Face unlock working with `sudo`. Test it with `sudo -k; sudo true`.

## Install

```bash
git clone https://github.com/metoi01/howdy-plasma-login.git
cd howdy-plasma-login
sudo ./install.sh --dry-run   # preview the changes
sudo ./install.sh
```

Reboot. At the login screen, **pick your user, leave the password empty and
press Enter**. Plasma Login Manager doesn't start authentication until you
press Enter, so one key press is the minimum.

### What `install.sh` does

| Step | Change |
|---|---|
| PAM | Copies `/usr/lib/pam.d/plasmalogin` to `/etc/pam.d/plasmalogin` if needed, adds Howdy as the first `auth` line, and keeps a backup as `*.howdy-bak`. |
| SELinux | Installs the one-rule module [`selinux/howdy-login.cil`](selinux/howdy-login.cil): `allow xdm_t v4l_device_t (chr_file (map))`. |

The Howdy line is copied from your existing `sudo` or `kde` PAM file, so it
works with both Howdy 3 (`pam_howdy.so`) and Howdy 2 (`pam_python.so`).

## Optional: require your face to open an app

You can make an app such as a messaging client ask for your face before it
opens from the menu.

```bash
sudo ./install.sh --with-polkit        # lets KDE's auth prompt accept your face
./app-lock/lock-app.sh io.github.example.App   # no sudo; use the app's id
```

Find an app's id with `flatpak list --app`. To undo:

```bash
./app-lock/lock-app.sh --remove io.github.example.App
./app-lock/lock-app.sh --list
```

> **This is a deterrent, not real security.** It stops someone using your
> unlocked desktop from opening the app from the menu. Anyone in your session
> can still start the app another way. `--with-polkit` also means admin
> prompts (for example installing software in Discover) accept your face, just
> as `sudo` already does.

## Uninstall

```bash
sudo ./uninstall.sh
```

This removes only the lines this tool added and the SELinux module. If an
`/etc/pam.d` file becomes identical to the system copy, the script deletes it
so the file follows OS updates again.

## Troubleshooting

**Locked out of the login screen?** Press `Ctrl+Alt+F3`, log in with your
password (text consoles don't use the modified file), then run
`sudo ./uninstall.sh`.

**IR lights don't turn on at the login screen.** Look for other SELinux
denials:

```bash
sudo ausearch -m avc -ts boot | grep xdm_t
```

If you see denials that aren't `map` on `v4l_device_t`, please open an issue
with the output.

**KWallet asks for a password after face login.** This is expected. KWallet is
encrypted with your login password, and face login doesn't provide one. You can
give the wallet an empty password in KWalletManager, but that leaves saved
passwords unencrypted, so only do it if your disk is encrypted (LUKS).

**Does it scan automatically without pressing Enter?** Not at the Plasma Login
Manager screen. The greeter only starts authentication when you submit.

## Tested on

- Bazzite (KDE), Plasma Login Manager, Howdy 3, SELinux enforcing

Reports from other distros are welcome.

## Credits

All face recognition is done by [Howdy](https://github.com/boltgolt/howdy).
This project only connects it to the Plasma login screen.

## License

[MIT](LICENSE)
