#!/usr/bin/env bash

install_dir="$HOME/.local/bin/"

cd "$(dirname "$0")"

mkdir -p "${install_dir}"

for i in home/.local/bin/*.sh; do
    if [ -f $i ]; then
        chmod +x $i
        ln -s "$PWD/$i" "${install_dir}"
    fi
done
