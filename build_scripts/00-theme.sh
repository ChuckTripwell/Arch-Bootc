#!/usr/bin/env bash

set -xeuo pipefail

cp -avf "/ctx/files"/. /

systemctl enable sddm

