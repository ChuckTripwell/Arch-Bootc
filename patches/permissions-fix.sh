# fix user permissions
RUN sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers
