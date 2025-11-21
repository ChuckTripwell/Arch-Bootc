FROM docker.io/cachyos/cachyos-v3:latest

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

RUN pacman -S --noconfirm plasma-meta fastfetch micro firewalld flatpak podman distrobox docker docker-compose







###########_____________________________________________________________________________________________________________________________
# fix user permissions.
RUN sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers
RUN systemctl enable polkit
#_______________________________________________________________________________________________________________________________________



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



########################################################################################################################################
# 
########################################################################################################################################


# Activate NTSync, wags my tail in your general direction
RUN echo -e 'ntsync' > /etc/modules-load.d/ntsync.conf

# CachyOS bbr3 Config Option
RUN echo -e 'net.core.default_qdisc=fq \n\
net.ipv4.tcp_congestion_control=bbr' > /etc/sysctl.d/99-bbr3.conf



# Add user to sudoers file for sudo, enable polkit
RUN echo -e "%wheel      ALL=(ALL:ALL) ALL" | tee -a /etc/sudoers
RUN systemctl enable polkit

# Set up zram, this will help users not run out of memory. Fox will fix!
RUN echo -e '[zram0]\nzram-size = min(ram, 8192)' >> /usr/lib/systemd/zram-generator.conf
RUN echo -e 'enable systemd-resolved.service' >> usr/lib/systemd/system-preset/91-resolved-default.preset
RUN echo -e 'L /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf' >> /usr/lib/tmpfiles.d/resolved-default.conf
RUN systemctl preset systemd-resolved.service



########################################################################################################################################
# 
########################################################################################################################################





###########_____________________________________________________________________________________________________________________________
# bazzite stuff (I'm lazy)
#
RUN pacman --noconfirm -S rsync
RUN cd /tmp && git clone https://github.com/ublue-os/bazzite/ && \
    rsync -r ./bazzite/system_files/desktop/shared/ / && \
    rsync -r ./bazzite/system_files/desktop/kinoite/ / && \
    #rsync -r ./bazzite/system_files/deck/shared/ / && \
    #rsync -r ./bazzite/system_files/deck/kinoite/ / && \
    rm -r ./bazzite
#_______________________________________________________________________________________________________________________________________


###########_____________________________________________________________________________________________________________________________
# bazzite scripts need grub2-editenv
#
RUN ln -s /usr/bin/grub-editenv /usr/bin/grub2-editenv
#_______________________________________________________________________________________________________________________________________


###########_____________________________________________________________________________________________________________________________
# create a /boot/grub to use bazzite scripts
#
RUN mkdir -p /usr/lib/systemd/system
RUN touch /usr/lib/systemd/system/fix-grub-link.service
RUN echo "[Unit]" > /usr/lib/systemd/system/fix-grub-link.service
RUN echo "Description=Create /boot/grub symlink if missing" >> /usr/lib/systemd/system/fix-grub-link.service
RUN echo "ConditionPathExists=!/boot/grub" >> /usr/lib/systemd/system/fix-grub-link.service
RUN echo "" >> /usr/lib/systemd/system/fix-grub-link.service
RUN echo "[Service]" >> /usr/lib/systemd/system/fix-grub-link.service
RUN echo "Type=oneshot" >> /usr/lib/systemd/system/fix-grub-link.service
RUN echo "ExecStart=/bin/ln -s /boot/grub2 /boot/grub" >> /usr/lib/systemd/system/fix-grub-link.service
RUN echo "" >> /usr/lib/systemd/system/fix-grub-link.service
RUN echo "[Install]" >> /usr/lib/systemd/system/fix-grub-link.service
RUN echo "WantedBy=multi-user.target" >> /usr/lib/systemd/system/fix-grub-link.service

RUN systemctl enable /usr/lib/systemd/system/fix-grub-link.service
#_______________________________________________________________________________________________________________________________________



###########_____________________________________________________________________________________________________________________________
# enable services.
#
RUN systemctl enable sddm
RUN systemctl enable podman
RUN systemctl enable firewalld
RUN systemctl enable docker

RUN systemctl enable bazzite-grub-boot-success.timer
RUN systemctl enable bazzite-grub-boot-success.service
RUN systemctl enable bazzite-autologin.service
RUN systemctl enable bazzite-tdpfix.service
RUN systemctl enable bazzite-flatpak-manager.service
RUN systemctl enable bazzite-hardware-setup.service
#_______________________________________________________________________________________________________________________________________



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
