#!/bin/bash
# Compiles every source except the app entry point with the tests and runs them.
set -eu
cd "$(dirname "$0")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc -swift-version 5 -module-cache-path "$tmp/modules" \
    $(ls Sources/*.swift | grep -v '/main.swift$') Tests/*.swift -o "$tmp/tests"
# The strings sit next to the binary; English and a US locale keep the expected texts stable.
cp -R Resources/*.lproj "$tmp/"
"$tmp/tests" -AppleLanguages '(en)' -AppleLocale en_US
