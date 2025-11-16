# fix user permissions
sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers
