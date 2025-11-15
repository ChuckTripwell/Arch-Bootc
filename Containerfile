FROM scratch AS ctx

COPY build_scripts /build
COPY system_files /files

FROM docker.io/cachyos/cachyos-v3:latest

ENV DEV_DEPS="base-devel git rust"

ENV DRACUT_NO_XATTR=1

# Section 0 - Pre-setup
# Section 1 - Package Installs
# Section 2 - Set up bootc dracut
# Section 3 - Chaotic AUR
# Section 4 - Linux OS Stuffs
# Section 5 - CachyOS Settings
# Section 6 - Niri/Chezmoi/DMS
# Section 7 - Final Bootc Setup

########################################################################################################################################
# Section 0 - Pre-setup | We do some system maintenance tasks + Set up some things for the rest of the containerfile to go smooothly! ##
########################################################################################################################################

# Set it up such that pacman will automatically clean package cache after each install
# So that we don't run out of memory in image generation and don't need to append --clean after everything
# ALSO DO NOT APPEND --CLEAN TO ANYTHING :D
RUN echo -e "[Trigger]\n\
Operation = Install\n\
Operation = Upgrade\n\
Type = Package\n\
Target = *\n\
\n\
[Action]\n\
Description = Cleaning up package cache...\n\
Depends = coreutils\n\
When = PostTransaction\n\
Exec = /usr/bin/rm -rf /var/cache/pacman/pkg" | tee /usr/share/libalpm/hooks/package-cleanup.hook

# Set up Arch official repos as a backup in case a package isn't in Cachy repos.
RUN pacman-key --init 

RUN pacman-key --populate archlinux

# Refresh the package database.
RUN pacman -Syu --noconfirm


########################################################################################################################################
# Section 1 - Package Installs | We grab every package we can from official arch repo/set up all non-flatpak apps for user ^^ ##########
########################################################################################################################################

# Base packages \ Linux Foundation \ Foss is love, foss is life! We split up packages by category for readability, debug ease, and less dependency trouble
#RUN pacman -S --noconfirm base base-devel git rust dracut linux-cachyos linux-firmware ostree systemd btrfs-progs e2fsprogs xfsprogs dosfstools skopeo dbus dbus-glib glib2 shadow

# Media/Install utilities/Media drivers
#RUN pacman -S --noconfirm librsvg libglvnd qt6-multimedia-ffmpeg plymouth acpid aha clinfo ddcutil dmidecode mesa-utils ntfs-3g nvme-cli \
#      vulkan-tools wayland-utils playerctl

# CLI Utilities
#RUN pacman -S --noconfirm sudo bash bash-completion bat busybox duf fastfetch gping jq lsof mcfly powertop \
#      procs ripgrep trash-cli tree usbutils wget wl-clipboard ydotool unzip glibc-locales tar udev \
#      starship

# Drivers
#RUN pacman -S --noconfirm amd-ucode intel-ucode edk2-shell efibootmgr shim mesa libva-intel-driver libva-mesa-driver \
#      vpl-gpu-rt vulkan-icd-loader vulkan-intel vulkan-radeon apparmor

# Network / VPN / SMB
#RUN pacman -S --noconfirm dnsmasq freerdp2 iproute2 iwd libmtp networkmanager-l2tp networkmanager-openconnect networkmanager-openvpn networkmanager-pptp \
#      networkmanager-strongswan networkmanager-vpnc nfs-utils nss-mdns networkmanager

# Pipewire
#RUN pacman -S --noconfirm pipewire pipewire-pulse pipewire-zeroconf pipewire-ffado pipewire-libcamera sof-firmware wireplumber

# Desktop Environment needs
#RUN pacman -S --noconfirm udiskie polkit-kde-agent xwayland-satellite xdg-desktop-portal-kde xdg-desktop-portal xdg-user-dirs \
#      filelight kdegraphics-thumbnailers kdenetwork-filesharing kio-admin kompare purpose matugen \
#      accountsservice dgop cliphist cava qt6ct brightnessctl wlsunset ddcutil xdg-utils

#RUN pacman -S --noconfirm sddm

RUN pacman -S --noconfirm $(curl https://codeberg.org/Dwdeath/parent-lock_for_cachyos-handheld/raw/branch/main/Package_list.txt) grub

RUN pacman -S --noconfirm plasma-desktop plasma-pa plasma-nm micro fastfetch breeze kate ark scx-scheds scx-manager flatpak dolphin firewalld docker podman ptyxis

# Add Maple Mono font.
#RUN mkdir -p "/usr/share/fonts/Maple Mono" \
#      && curl -fSsLo "/tmp/maple.zip" "$(curl "https://api.github.com/repos/subframe7536/maple-font/releases/latest" | jq '.assets[] | select(.name == "MapleMono-Variable.zip") | .browser_download_url' -rc)" \
#      && unzip "/tmp/maple.zip" -d "/usr/share/fonts/Maple Mono"

########################################################################################################################################
# Section 2 - Set up bootc dracut | I think it sets up the bootc initial image / Compiles Bootc Package :D #############################
########################################################################################################################################

# Workaround due to dracut version bump, please remove eventually
# FIXME: remove
RUN printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /etc/dracut.conf.d/fix-bootc.conf

RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    pacman -S --noconfirm base-devel git rust && \
    git clone https://github.com/bootc-dev/bootc.git /tmp/bootc && \
    make -C /tmp/bootc bin install-all install-initramfs-dracut && \
    sh -c 'export KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --add ostree --kver "$KERNEL_VERSION"  "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"'

########################################################################################################################################
# Section 3 - Chaotic AUR # We grab some precompiled packages from the Chaotic AUR for things not on Arch repos/better updated - #######
########################################################################################################################################

# Flatpak repo add.
RUN mkdir -p /etc/flatpak/remotes.d/ && \
      curl --retry 3 -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo

RUN mkdir -p /usr/share/flatpak/preinstall.d/

# Bazaar
RUN echo -ne '[Flatpak Preinstall io.github.kolunmi.Bazaar]\nBranch=stable\nIsRuntime=false' >> /usr/share/flatpak/preinstall.d/Bazaar.preinstall



########################################################################################################################################
# Section 4 - Linux OS stuffs | We set some nice defaults for a regular user + set up a couple XeniaOS details #########################
########################################################################################################################################
# fix user permissions
#RUN echo "%wheel      ALL=(ALL:ALL) ALL" | tee -a /etc/sudoers

# fix user permissions
RUN sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers
RUN systemctl enable polkit

# Set up zram, this will help users not run out of memory.
RUN echo -ne '[zram0]\nzram-size = min(ram, 8192)' >> /usr/lib/systemd/zram-generator.conf
RUN echo -ne 'enable systemd-resolved.service' >> usr/lib/systemd/system-preset/91-resolved-default.preset
RUN echo -ne 'L /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf' >> /usr/lib/tmpfiles.d/resolved-default.conf
RUN systemctl preset systemd-resolved.service

# Enable wifi, firewall, power profiles.
RUN systemctl enable NetworkManager firewalld

# Place XeniaOS logo at plymouth folder location to appear on boot.
#RUN wget -O /usr/share/plymouth/themes/spinner/watermark.png https://raw.githubusercontent.com/XeniaMeraki/XeniaOS-G-Euphoria/refs/heads/main/xeniaos_text_logo_whitever_delphic_melody.png


# OS Release and Update
RUN echo -ne 'NAME="XeniaOS"\n\
PRETTY_NAME="XeniaOS"\n\
DEFAULT_HOSTNAME="XeniaOS"\n\
HOME_URL="https://github.com/XeniaMeraki/XeniaOS\n"' > /etc/os-release

# Automounter Systemd Service for flash drives and CDs
RUN echo -ne '[Unit] \n\
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
WantedBy=graphical-session.target\n' > /usr/lib/systemd/user/udiskie.service

# Secondary HDD/SSD automounter, supports ext4/btrfs, mounts to /media/media-automount by default. Made by @Zeglius
# Feel free to use your own fstab/mount things your own way if you understand how to do so
# Disable with "sudo ln -s /dev/null /etc/media-automount.d/_all.conf"
RUN git clone --depth=1 https://github.com/Zeglius/media-automount-generator /tmp/media-automount-generator && \
      cd /tmp/media-automount-generator && \
      DESTDIR=/usr/local ./install.sh

########################################################################################################################################
# Section 5 - CachyOS settings | Since we have the CachyOS kernel, we gotta put it to good use ≽^•⩊•^≼ ################################
########################################################################################################################################

# Activate NTSync, wags my tail in your general direction
RUN echo 'ntsync' > /etc/modules-load.d/ntsync.conf

# CachyOS bbr3 Config Option
RUN echo -ne 'net.core.default_qdisc=fq \n\
net.ipv4.tcp_congestion_control=bbr\n' > /etc/sysctl.d/99-bbr3.conf

########################################################################################################################################
# Section 7 - Final Bootc Setup. The horrors are endless. but we stay silly :3c -junoinfernal -maia arson crimew #######################
########################################################################################################################################

#This fixes a user/groups error with Arch Bootc setup. We are suffering for not using the rechunker, but we persist.
#Do NOT remove until fixed upstream. Script created by Tulip.

RUN mkdir -p /usr/lib/systemd/system-preset /usr/lib/systemd/system

RUN echo -ne '#!/bin/sh\ncat /usr/lib/sysusers.d/*.conf | grep -e "^g" | grep -v -e "^#" | grep -v -e "wheel" | awk "NF" | awk '\''{print $2}'\'' | xargs -I{} sed -i "/{}/d" $1' > /usr/libexec/xeniaos-group-fix
RUN chmod +x /usr/libexec/xeniaos-group-fix
RUN echo -ne '[Unit]\n\
Description=Fix groups\n\
Wants=local-fs.target\n\
After=local-fs.target\n\
[Service]\n\
Type=oneshot\n\
ExecStart=/usr/libexec/xeniaos-group-fix /etc/group\n\
ExecStart=/usr/libexec/xeniaos-group-fix /etc/gshadow\n\
ExecStart=systemd-sysusers\n\
[Install]\n\
WantedBy=default.target multi-user.target\n' > /usr/lib/systemd/system/xeniaos-group-fix.service

RUN echo "enable xeniaos-group-fix.service" > /usr/lib/systemd/system-preset/01-xeniaos-group-fix.preset
RUN systemctl enable xeniaos-group-fix.service

# Necessary for general behavior expected by image-based systems
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    rm -rf /boot /home /root /usr/local /srv && \
    mkdir -p /var /sysroot /boot /usr/lib/ostree && \
    ln -s var/opt /opt && \
    ln -s var/roothome /root && \
    ln -s var/home /home && \
    ln -s sysroot/ostree /ostree && \
    echo "$(for dir in opt usrlocal home srv mnt ; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo "d /var/roothome 0700 root root -" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo "d /run/media 0755 root root -" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    printf "[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n" | tee "/usr/lib/ostree/prepare-root.conf"






RUN bootc container lint
