#!/usr/bin/env bash

# force sddm to work in Wayland

mkdir -p /usr/lib/sddm/sddm.conf.d
touch /usr/lib/sddm/sddm.conf.d/10-wayland.conf

echo "[General]" > /usr/lib/sddm/sddm.conf.d/10-wayland.conf
echo "DisplayServer=wayland" >> /usr/lib/sddm/sddm.conf.d/10-wayland.conf
echo "GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell" >> /usr/lib/sddm/sddm.conf.d/10-wayland.conf
echo "" >> /usr/lib/sddm/sddm.conf.d/10-wayland.conf
echo "[Wayland]" >> /usr/lib/sddm/sddm.conf.d/10-wayland.conf
echo "CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1" >> /usr/lib/sddm/sddm.conf.d/10-wayland.conf

#systemctl enable sddm
