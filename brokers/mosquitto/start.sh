#!/bin/sh

directory="${0%/*}";
cd "$directory"

if [[ $(uname -m) == 'arm64' ]]; then
    /opt/homebrew/sbin/mosquitto -c mosquitto.conf &
else
    mosquitto -c mosquitto.conf &
fi
