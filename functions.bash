#!/usr/bin/env bash

#
# Wait until we can connect to a url given in $1
#
function waitFor() {
    echo "Waiting for $1"
    until $(curl --output /dev/null --silent --head --connect-to --url ${1}); do
      sleep 2
    done
    echo "$1 is up"
}

#
# Read all agents from config file
#
function importAgents() {
    AGENTS=()
    while IFS= read -r HOST
    do
        AGENTS+=("$HOST")
    done < conf/agents.conf
}