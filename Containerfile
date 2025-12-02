FROM ghcr.io/ublue-os/bazzite-deck:testing AS bazzite

FROM ghcr.io/chucktripwell/core:main

RUN curl https://raw.githubusercontent.com/CachyOS/CachyOS-PKGBUILDS/master/cachyos-mirrorlist/cachyos-mirrorlist -o /etc/pacman.d/cachyos-mirrorlist

RUN pacman -Syy --needed --overwrite "*" --noconfirm cachyos-keyring cachyos-mirrorlist cachyos-v3-mirrorlist cachyos-v4-mirrorlist cachyos-hooks archlinux-keyring pacman-mirrorlist
RUN pacman -Syy --noconfirm

RUN bash -c 'BASE="https://build.cachyos.org/ISO/desktop"; \
DATE=$(date +%y%m%d); \
while ! curl --head --silent --fail "$BASE/$DATE/" >/dev/null 2>&1; do \
  DATE=$(date -d "$DATE - 1 day" +%y%m%d); \
done; \
pacman -Sy --noconfirm --overwrite "*" --ask=4 $(curl -s "$BASE/$DATE/cachyos-desktop-linux-$DATE.pkgs.txt" | awk "{print \$1}" | grep -v firefox )'

RUN pacman -S --noconfirm podman docker 



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
# service from bazzite to check for a successful boot
#
COPY --from="bazzite" /etc/sddm.conf.d/* /etc/sddm.conf.d/
COPY --from="bazzite" /usr/lib/systemd/system/bazzite-* /usr/lib/systemd/system/
COPY --from="bazzite" /usr/libexec/bazzite-* /usr/libexec/
RUN chmod +x /usr/libexec/bazzite-*
#_______________________________________________________________________________________________________________________________________


###########_____________________________________________________________________________________________________________________________
# bazzite stuff (I'm lazy)
#
#RUN pacman --noconfirm -S rsync
#RUN cd /tmp && git clone https://github.com/ublue-os/bazzite/ && \
#    rsync -r ./bazzite/system_files/desktop/shared/ / && \
#    rsync -r ./bazzite/system_files/desktop/kinoite/ / && \
#    rsync -r ./bazzite/system_files/deck/shared/ / && \
#    rsync -r ./bazzite/system_files/deck/kinoite/ / && \
#    rm -r ./bazzite
#_______________________________________________________________________________________________________________________________________




###########_____________________________________________________________________________________________________________________________
# enable services.
#
RUN systemctl enable sddm
RUN systemctl enable docker
RUN systemctl enable podman
#
RUN systemctl enable bazzite-grub-boot-success.timer
RUN systemctl enable bazzite-grub-boot-success.service
#RUN systemctl enable bazzite-autologin.service
#RUN systemctl enable bazzite-tdpfix.service
#RUN systemctl enable bazzite-flatpak-manager.service
#RUN systemctl enable bazzite-hardware-setup.service
#_______________________________________________________________________________________________________________________________________




########################################################################################################################################
# Do not touch anything after this line!
########################################################################################################################################
RUN printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf && \
      printf 'hostonly=no\nadd_dracutmodules+=" ostree bootc "' | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-modules.conf && \
      sh -c 'export KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" && \
      dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION"  "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"'

RUN rm -rf /home/build/.cache/* && \
    rm -rf \
        /tmp/* \
        /var/cache/pacman/pkg/*

# Necessary for general behavior expected by image-based systems
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    rm -rf /boot /home /root /usr/local /srv /var /usr/lib/sysimage/log /usr/lib/sysimage/cache/pacman/pkg && \
    mkdir -p /sysroot /boot /usr/lib/ostree /var && \
    ln -s sysroot/ostree /ostree && ln -s var/roothome /root && ln -s var/srv /srv && ln -s var/opt /opt && ln -s var/mnt /mnt && ln -s var/home /home && \
    echo "$(for dir in opt home srv mnt usrlocal ; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf "d /var/roothome 0700 root root -\nd /run/media 0755 root root -" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' | tee "/usr/lib/ostree/prepare-root.conf"

RUN bootc container lint
