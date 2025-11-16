#!/usr/bin/env bash

pacman -S --noconfirm plasma-desktop sddm plasma-pa plasma-nm micro fastfetch breeze kate ark scx-scheds scx-manager flatpak dolphin firewalld docker podman ptyxis

pacman -S $( curl https://codeberg.org/Dwdeath/parent-lock_for_cachyos-handheld/raw/branch/main/Package_list.txt ) 
