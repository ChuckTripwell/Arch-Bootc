FROM docker.io/cachyos/cachyos-v3:latest

ENV DEV_DEPS="base-devel git rust"

ENV DRACUT_NO_XATTR=1

########################################################################################################################################
# 
########################################################################################################################################

# Initialize the database
RUN pacman -Syu --noconfirm

# Use the Arch mirrorlist that will be best at the moment for both the containerfile and user too! Fox will help!
RUN pacman -S --noconfirm reflector

# Base packages \ Linux Foundation \ Foss is love, foss is life! We split up packages by category for readability, debug ease, and less dependency trouble
RUN pacman -S --noconfirm base dracut linux-cachyos linux-firmware ostree systemd btrfs-progs e2fsprogs xfsprogs binutils dosfstools skopeo dbus dbus-glib glib2 shadow

# Media/Install utilities/Media drivers
RUN pacman -S --noconfirm librsvg libglvnd qt6-multimedia-ffmpeg plymouth acpid ddcutil dmidecode mesa-utils ntfs-3g \
      vulkan-tools wayland-utils playerctl

# Fonts
RUN pacman -S --noconfirm noto-fonts noto-fonts-cjk noto-fonts-emoji

# CLI Utilities
RUN pacman -S --noconfirm sudo bash bash-completion fastfetch btop jq less lsof nano openssh powertop man-db \
      tree usbutils vim wl-clipboard unzip ptyxis glibc-locales tar udev starship tuned-ppd tuned hyfetch docker podman curl

# Drivers \ "Business, business, business! Numbersss."
RUN pacman -S --noconfirm amd-ucode intel-ucode efibootmgr shim mesa lib32-mesa libva-intel-driver libva-mesa-driver \
      vpl-gpu-rt vulkan-icd-loader vulkan-intel vulkan-radeon apparmor xf86-video-amdgpu lib32-vulkan-radeon 

# Network / VPN / SMB / storage
RUN pacman -S --noconfirm libmtp networkmanager-openconnect networkmanager-openvpn nss-mdns samba smbclient networkmanager firewalld udiskie \
      udisks2 

# Accessibility
RUN pacman -S --noconfirm espeak-ng orca

# Pipewire
RUN pacman -S --noconfirm pipewire pipewire-pulse pipewire-zeroconf pipewire-ffado pipewire-libcamera sof-firmware wireplumber

# Printer
RUN pacman -S --noconfirm cups cups-browsed hplip

# Desktop Environment needs
RUN pacman -S --noconfirm greetd xwayland-satellite greetd-regreet xdg-desktop-portal-kde xdg-desktop-portal xdg-user-dirs xdg-desktop-portal-gnome \
      ffmpegthumbs kdegraphics-thumbnailers kdenetwork-filesharing kio-admin chezmoi matugen accountsservice quickshell dgop cliphist cava dolphin \ 
      qt6ct breeze brightnessctl wlsunset ddcutil xdg-utils kservice5 archlinux-xdg-menu shared-mime-info kio rofi glycin

# User frontend programs/apps
RUN pacman -S --noconfirm steam scx-scheds scx-manager gnome-disk-utility

# Add Maple Mono font, it's so cute! It's a pain to download! You'll love it.
RUN mkdir -p "/usr/share/fonts/Maple Mono" \
      && curl -fSsLo "/tmp/maple.zip" "$(curl "https://api.github.com/repos/subframe7536/maple-font/releases/latest" | jq '.assets[] | select(.name == "MapleMono-Variable.zip") | .browser_download_url' -rc)" \
      && unzip "/tmp/maple.zip" -d "/usr/share/fonts/Maple Mono"

RUN mkdir -p /etc/plymouth \
 && echo -e '[Daemon]\nTheme=spinner' | tee /etc/plymouth/plymouthd.conf

RUN pacman -S --clean

########################################################################################################################################
# 
########################################################################################################################################

RUN pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com

RUN pacman-key --init && pacman-key --lsign-key 3056513887B78AEB

RUN pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm

RUN pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm

RUN echo -e '[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf

RUN pacman -Sy --noconfirm

RUN pacman -S \
      chaotic-aur/input-remapper-git chaotic-aur/sc-controller chaotic-aur/flatpak-git \
      chaotic-aur/ttf-twemoji chaotic-aur/ttf-symbola chaotic-aur/opentabletdriver chaotic-aur/wget2 \
      --noconfirm

########################################################################################################################################
# 
########################################################################################################################################

###########_____________________________________________________________________________________________________________________________
# install usecase-specific packages.
#
# Remove conflicting mesa packages (if any)
RUN pacman -Rdd --noconfirm mesa || true
RUN pacman -Rdd --noconfirm lib32-mesa || true
RUN pacman -Rdd --noconfirm vulkan-mesa-device-select || true
RUN pacman -Rdd --noconfirm lib32-vulkan-mesa-device-select || true

RUN pacman -Sy --noconfirm
RUN pacman -S --noconfirm mesa-git lib32-mesa-git lib32-vulkan-intel
RUN pacman -S --noconfirm steam steam-powerbuttond-git steamos-manager jupiter-fan-control steamos-networking-tools

RUN pacman -S --noconfirm cachyos-handheld scx-scheds scx-manager
RUN pacman -S --noconfirm fastfetch flatpak cosign docker ptyxis waydroid topgrade
RUN pacman -S --noconfirm docker-compose just weston fish
#_______________________________________________________________________________________________________________________________________


# forces sddm to use Wayland.
#### create file
RUN mkdir -p /usr/lib/sddm/sddm.conf.d
RUN touch /usr/lib/sddm/sddm.conf.d/10-wayland.conf
#### populate file
RUN echo "[General]" > /usr/lib/sddm/sddm.conf.d/10-wayland.conf
RUN echo "DisplayServer=wayland" >> /usr/lib/sddm/sddm.conf.d/10-wayland.conf
RUN echo "GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell" >> /usr/lib/sddm/sddm.conf.d/10-wayland.conf
RUN echo "" >> /usr/lib/sddm/sddm.conf.d/10-wayland.conf
RUN echo "[Wayland]" >> /usr/lib/sddm/sddm.conf.d/10-wayland.conf
RUN echo "CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1" >> /usr/lib/sddm/sddm.conf.d/10-wayland.conf
#### enable sddm
RUN systemctl enable sddm


RUN systemctl enable sddm
RUN systemctl enable podman


RUN pacman -S --clean





########################################################################################################################################
# 
########################################################################################################################################



RUN mkdir -p /usr/share/flatpak/preinstall.d/

# Bazaar
RUN echo -e "[Flatpak Preinstall io.github.kolunmi.Bazaar]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/Bazaar.preinstall

# Elisa
RUN echo -e "[Flatpak Preinstall org.kde.elisa]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/Elisa.preinstall

# Pinta | Image editing! They set out a bit to match paint.net/paintdotnet
RUN echo -e "[Flatpak Preinstall com.github.PintaProject.Pinta]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/Pinta.preinstall

# Ark | For unzipping files and file compression! (Imagine a fox whose face you may squish...)
RUN echo -e "[Flatpak Preinstall org.kde.ark]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/Ark.preinstall

# Faugus Launcher | This is fantastic for using windows software on linux, exes and whatnot
RUN echo -e "[Flatpak Preinstall io.github.faugus.faugus-launcher]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/FaugusLauncher.preinstall

# ProtonUp-Qt | For installing different versions of proton! Emulation for windows games via Steam/Valve's work
RUN echo -e "[Flatpak Preinstall net.davidotek.pupgui2]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/ProtonUp-Qt.preinstall

# Kate | Writing documents~ Also can act as an IDE/development environment interestingly!
RUN echo -e "[Flatpak Preinstall org.kde.kate]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/Kate.preinstall

# Warehouse | Manage your flatpak apps, delete whatever you don"t need/use/want! It's YOUR computer.
RUN echo -e "[Flatpak Preinstall io.github.flattool.Warehouse]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/Warehouse.preinstall

# Fedora Media Writer | Burn ISOs to usb sticks! Install linux on ALL the things. (This won"t work for Windows ISOs, cuz Microsoft is dumb) >:c
RUN echo -e "[Flatpak Preinstall org.fedoraproject.MediaWriter]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/FedoraMediaWriter.preinstall

# Gear Lever | Manage appimages!
RUN echo -e "[Flatpak Preinstall it.mijorus.gearlever]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/GearLever.preinstall

# Haruna | Watch video files! I actually personally like this better than VLC Media Player, nicer look/featureset
RUN echo -e "[Flatpak Preinstall org.kde.haruna]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/Haruna.preinstall

# Gwenview | View images!
RUN echo -e "[Flatpak Preinstall org.kde.gwenview]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/Gwenview.preinstall

# Filelight | Check what's taking up space on your drives~
RUN echo -e "[Flatpak Preinstall org.kde.filelight]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/Filelight.preinstall

# Rclone Shuttle | Files storage and transfer, at your service, my quing!
RUN echo -e "[Flatpak Preinstall io.github.pieterdd.RcloneShuttle]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/RcloneShuttle.preinstall

# Systemd flatpak preinstall service, thanks Aurora
RUN echo -e '[Unit]\n\
Description=Preinstall Flatpaks\n\
After=network-online.target\n\
Wants=network-online.target\n\
ConditionPathExists=/usr/bin/flatpak\n\
Documentation=man:flatpak-preinstall(1)\n\
\n\
[Service]\n\
Type=oneshot\n\
ExecStart=/usr/bin/flatpak preinstall -y\n\
RemainAfterExit=true\n\
Restart=on-failure\n\
RestartSec=30\n\
\n\
StartLimitIntervalSec=600\n\
StartLimitBurst=3\n\
\n\
[Install]\n\
WantedBy=multi-user.target' > /usr/lib/systemd/system/flatpak-preinstall.service

RUN systemctl enable flatpak-preinstall.service

########################################################################################################################################
# 
########################################################################################################################################

# Add user to sudoers file for sudo, enable polkit
RUN echo -e "%wheel      ALL=(ALL:ALL) ALL" | tee -a /etc/sudoers
RUN systemctl enable polkit

# Set up zram, this will help users not run out of memory. Fox will fix!
RUN echo -e '[zram0]\nzram-size = min(ram, 8192)' >> /usr/lib/systemd/zram-generator.conf
RUN echo -e 'enable systemd-resolved.service' >> usr/lib/systemd/system-preset/91-resolved-default.preset
RUN echo -e 'L /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf' >> /usr/lib/tmpfiles.d/resolved-default.conf
RUN systemctl preset systemd-resolved.service

# Enable wifi, firewall, power profiles. Fox will protect!
RUN systemctl enable NetworkManager firewalld

# OS Release and Update
RUN echo -e 'NAME="XeniaOS"\n\
PRETTY_NAME="XeniaOS"\n\
ID=arch\n\
BUILD_ID=rolling\n\
ANSI_COLOR="38;2;23;147;209"\n\
HOME_URL="https://github.com/XeniaMeraki/XeniaOS"\n\
LOGO=archlinux-logo\n\
DEFAULT_HOSTNAME="XeniaOS"' > /etc/os-release

# Automounter Systemd Service for flash drives and CDs
RUN echo -e '[Unit] \n\
Description=Udiskie automount \n\
PartOf=graphical-session.target \n\
After=graphical-session.target \n\
 \n\
[Service] \n\
ExecStart=udiskie \n\
Restart=on-failure \n\
RestartSec=1 \n\
\n\
[Install] \n\
WantedBy=graphical-session.target' > /usr/lib/systemd/user/udiskie.service

# Clip history / Cliphist systemd service / Clipboard history for copy and pasting to work properly in Niri~
RUN echo -e '[Unit]\n\
Description=Clipboard History service\n\
PartOf=graphical-session.target\n\
After=graphical-session.target\n\
\n\
[Service]\n\
ExecStart=wl-paste --watch cliphist store\n\
Restart=on-failure\n\
RestartSec=1\n\
\n\
[Install]\n\
WantedBy=graphical-session.target' > /usr/lib/systemd/user/cliphist.service

# Symlink Vi to Vim / Make it to where a user can use vi in terminal command to use vim automatically | Thanks Tulip
RUN ln -s ./vim /usr/bin/vi

# Symlink GTK to Libadwaita
RUN mkdir -p /usr/share/gtk-4.0

RUN ln -sf /usr/share/themes/Colloid-Orange-Dark-Catppuccin/gtk-4.0/{assets,gtk.css,gtk-dark.css} \
       /usr/share/gtk-4.0/

# System-wide default application associations for filetype calls
RUN mkdir -p /etc/xdg/

RUN echo -e '[Default Applications]\n\
text/plain=org.kde.kate.desktop\n\
application/json=org.kde.kate.desktop\n\
\n\
text/html=floorp.desktop\n\
\n\
video/mp4=haruna.desktop\n\
video/x-matroska=haruna.desktop\n\
video/webm=haruna.desktop\n\
video/quicktime=haruna.desktop\n\
\n\
audio/mpeg=org.kde.elisa.desktop\n\
audio/flac=org.kde.elisa.desktop\n\
audio/ogg=org.kde.elisa.desktop\n\
audio/wav=org.kde.elisa.desktop\n\
\n\
image/png=pinta.desktop\n\
image/jpeg=pinta.desktop\n\
image/gif=org.kde.gwenview.desktop\n\
\n\
application/zip=org.kde.ark.desktop\n\
application/x-rar=org.kde.ark.desktop\n\
application/x-tar=org.kde.ark.desktop\n\
\n\
[Added Associations]' > /etc/xdg/mimeapps.list

# ENV default exports, QT theming 
# Load shared objects immediately for better first time latency
# Apply OBS_VK to all vulkan instances for better OBS game capture, some other windows may come along for the ride
ENV QT_QPA_PLATFORMTHEME=qt6ct
ENV LD_BIND_NOW=1
ENV OBS_VKCAPTURE=1

# Set vm.max_map_count for stability/improved gaming performance
# https://wiki.archlinux.org/title/Gaming#Increase_vm.max_map_count
RUN echo -e "vm.max_map_count = 2147483642" > /etc/sysctl.d/80-gamecompatibility.conf

# Autoclean pacman package cache after each update, install, and uninstall
RUN mkdir -p /etc/pacman.d/hooks/

RUN echo -e '[Trigger]\n\
Operation = Upgrade\n\
Operation = Install\n\
Operation = Remove\n\
Type = Package\n\
Target = *\n\
[Action]\n\
Description = Cleaning pacman cache...\n\
When = PostTransaction\n\
Exec = /usr/bin/paccache -r' > /etc/pacman.d/hooks/clean_package_cache.hook

# Automount removable disks to /media/ using udisks2
# https://wiki.archlinux.org/title/Udisks
# FIXME
RUN echo -e 'ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"' > /etc/udev/rules.d/99-udisks2.rules

RUN echo -e 'D /media 0755 root root 0 -' > /etc/tmpfiles.d/media.conf

########################################################################################################################################
# Section 6 - CachyOS settings | Since we have the CachyOS kernel, we gotta put it to good use ≽^•⩊•^≼ ################################
########################################################################################################################################

# Activate NTSync.
RUN echo -e 'ntsync' > /etc/modules-load.d/ntsync.conf

# CachyOS bbr3 Config Option
RUN echo -e 'net.core.default_qdisc=fq \n\
net.ipv4.tcp_congestion_control=bbr' > /etc/sysctl.d/99-bbr3.conf

########################################################################################################################################
# 
########################################################################################################################################

# Regression with newer dracut broke this
RUN mkdir -p /etc/dracut.conf.d && \
    echo -e "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system" | tee /etc/dracut.conf.d/fix-bootc.conf

RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    pacman -S --noconfirm base-devel git rust && \
    git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc && \
    make -C /tmp/bootc bin install-all && \
    sh -c 'export KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION"  "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"' && \
    pacman -S --clean --noconfirm

# This fixes a user/groups error with Arch Bootc setup.
# FIXME Do NOT remove until fixed upstream. Script created by Tulip.

RUN mkdir -p /usr/lib/systemd/system-preset /usr/lib/systemd/system

RUN echo -e '#!/bin/sh\ncat /usr/lib/sysusers.d/*.conf | grep -e "^g" | grep -v -e "^#" | awk "NF" | awk '\''{print $2}'\'' | grep -v -e "wheel" -e "root" -e "sudo" | xargs -I{} sed -i "/{}/d" $1' > /usr/libexec/xeniaos-group-fix
RUN chmod +x /usr/libexec/xeniaos-group-fix
RUN echo -e '[Unit]\n\
Description=Fix groups\n\
Wants=local-fs.target\n\
After=local-fs.target\n\
[Service]\n\
Type=oneshot\n\
ExecStart=/usr/libexec/xeniaos-group-fix /etc/group\n\
ExecStart=/usr/libexec/xeniaos-group-fix /etc/gshadow\n\
ExecStart=systemd-sysusers\n\
[Install]\n\
WantedBy=default.target multi-user.target' > /usr/lib/systemd/system/xeniaos-group-fix.service

RUN echo -e "enable xeniaos-group-fix.service" > /usr/lib/systemd/system-preset/01-xeniaos-group-fix.preset
RUN systemctl enable xeniaos-group-fix.service

# Necessary for general behavior expected by image-based systems
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    rm -rf /boot /home /root /usr/local /srv && \
    mkdir -p /var /sysroot /boot /usr/lib/ostree && \
    ln -s var/opt /opt && \
    ln -s var/roothome /root && \
    ln -s var/home /home && \
    ln -s sysroot/ostree /ostree && \
    echo -e "$(for dir in opt usrlocal home srv mnt ; do echo -e "d /var/$dir 0755 root root -" ; done)" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo -e "d /var/roothome 0700 root root -" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo -e "d /run/media 0755 root root -" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo -e "[composefs]\nenabled = yes\n[sysroot]\nreadonly = true" | tee "/usr/lib/ostree/prepare-root.conf"

RUN bootc container lint
