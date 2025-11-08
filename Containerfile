FROM docker.io/cachyos/cachyos:latest AS builder

ENV DEV_DEPS="base-devel git rust"

ENV DRACUT_NO_XATTR=1

RUN pacman -Syyuu --noconfirm \
#Base packages
      base dracut linux linux-firmware ostree systemd btrfs-progs e2fsprogs xfsprogs binutils dosfstools skopeo dbus dbus-glib glib2 shadow \
\
#Media/Install utilities
       librsvg libglvnd qt6-multimedia-ffmpeg plymouth flatpak acpid aha clinfo ddcutil dmidecode mesa-utils ntfs-3g nvme-cli vulkan-tools wayland-utils \
\
#Fonts
      noto-fonts noto-fonts-cjk noto-fonts-emoji \
\
#CLI Utilities
      bash-completion bat busybox duf hyfetch fd gping grml-zsh-config htop jq less lsof mcfly nano nvtop openssh powertop \
      procs ripgrep tldr trash-cli tree usbutils vim wget wl-clipboard ydotool zsh zsh-completions yay \
\
#Drivers
      amd-ucode intel-ucode edk2-shell efibootmgr shim mesa libva-intel-driver libva-mesa-driver \
      vpl-gpu-rt vulkan-icd-loader vulkan-intel vulkan-radeon apparmor \
\
#Network / VPN / SMB
      dnsmasq freerdp2 iproute2 iwd libmtp networkmanager-l2tp networkmanager-openconnect networkmanager-openvpn networkmanager-pptp \
      networkmanager-strongswan networkmanager-vpnc nfs-utils nss-mdns samba smbclient ufw \
\
#Accessibility
      espeak-ng orca \
\  
#Pipewire
      pipewire pipewire-pulse pipewire-zeroconf pipewire-ffado pipewire-libcamera sof-firmware wireplumber pipewire-jack \
\
#Printer
      cups cups-browsed gutenprint ipp-usb hplip splix system-config-printer \
\
      ${DEV_DEPS} && \
  pacman -S --clean --noconfirm && \
  rm -rf /var/cache/pacman/pkg/*

# START ##########################################################################################################################################

RUN printf "[archlinuxcn]\nServer=https://repo.archlinuxcn.org/\$arch\n" >> /etc/pacman.conf && \
        rm -fr /etc/pacman.d/gnupg && pacman-key --init && pacman-key --populate archlinux && \
        pacman -Syyu --noconfirm archlinuxcn-keyring && \
        pacman -S --noconfirm yay
    
RUN useradd builder && \
        printf "123\n123\n" | passwd builder && \
        mkdir -p /home/builder && \
        chown builder /home/builder && \
        chgrp builder /home/builder && \
        echo "builder ALL=(ALL) NOPASSWD: /usr/bin/pacman" >> /etc/sudoers
    
    
RUN pacman -S --noconfirm base-devel && \
        su -l builder -c "yay -S --noconfirm noctalia-shell-git" && \
        pacman -S --noconfirm builder

USER root
WORKDIR /

# Cleanup
RUN sed -i 's@#en_US.UTF-8@en_US.UTF-8@g' /etc/locale.gen && \
    userdel -r build && \
    rm -drf /home/build && \
    sed -i '/build ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
    sed -i '/root ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
    rm -rf /tmp/*

# END ############################################################################################################################################

# Workaround due to dracut version bump, please remove eventually
# FIXME: remove
RUN echo -e "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /etc/dracut.conf.d/fix-bootc.conf

RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    pacman -S --noconfirm base-devel git rust && \
    git clone https://github.com/bootc-dev/bootc.git /tmp/bootc && \
    make -C /tmp/bootc bin install-all install-initramfs-dracut && \
    sh -c 'export KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION"  "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"' && \
    pacman -S --clean --noconfirm

# Setup a temporary root passwd (changeme) for dev purposes
# RUN pacman -S 
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root
RUN rm -rf /boot /home /root /usr/local /srv && \
    mkdir -p /var/{home,roothome,srv} /sysroot /boot && \
    ln -s sysroot/ostree /ostree

# Update useradd default to /var/home instead of /home for User Creation
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd"

# Necessary for `bootc install`
RUN mkdir -p /usr/lib/ostree && \
    printf  "[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n" | \
    tee "/usr/lib/ostree/prepare-root.conf"

RUN bootc container lint
