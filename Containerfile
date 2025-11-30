############################################### BUILDER STAGE ##############################################
FROM cachyos/cachyos-v3:latest AS builder

# Update and install dependencies
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm git archiso squashfs-tools xorriso grub rsync

# Clone the deckify branch
RUN git clone https://github.com/CachyOS/CachyOS-Live-ISO.git /cachyos-iso
WORKDIR /cachyos-iso

# Build default profile rootfs dynamically
RUN chmod +x buildiso.sh && \
    ./buildiso.sh -v

############################################## FINAL IMAGE ##############################################
FROM ghcr.io/chucktripwell/core:main

# Copy the rootfs from the builder stage dynamically
COPY --from=builder /cachyos-iso/work/handheld/airootfs/ /   # adjust profile if necessary



# Add 3rd party bootc package repo via Hecknt FIXME Eventually remove this with Arch/Chaotic AUR proper host | https://github.com/hecknt/arch-bootc-pkgs
RUN pacman-key --recv-key 5DE6BF3EBC86402E7A5C5D241FA48C960F9604CB --keyserver keyserver.ubuntu.com
RUN pacman-key --lsign-key 5DE6BF3EBC86402E7A5C5D241FA48C960F9604CB
RUN echo -e '[bootc]\nSigLevel = Required\nServer=https://github.com/hecknt/arch-bootc-pkgs/releases/download/$repo' >> /etc/pacman.conf

# Groups fix | Truncated down by Hecknt
RUN echo -e "[Install]\nWantedBy=sysinit.target" | tee -a /usr/lib/systemd/system/systemd-sysusers.service && \
      systemctl enable systemd-sysusers.service

RUN pacman -Sy --noconfirm

RUN pacman -S --noconfirm bootc/bootc bootc/bootupd bootc/bcvk

RUN printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf && \
      printf 'hostonly=no\nadd_dracutmodules+=" ostree bootc "' | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-modules.conf && \
      sh -c 'export KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" && \
      dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION"  "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"'

RUN pacman -S --clean --noconfirm

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
