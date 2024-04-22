#!/usr/bin/env bash

install_dir="/etc/srv"

cd "$(dirname "$0")"

mkdir -p "${install_dir}"

for i in etc/srv/*.conf; do
    if [ -f $i ]; then
        ln -s "$PWD/$i" "${install_dir}"
    fi
done
