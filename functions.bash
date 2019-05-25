#!/usr/bin/env bash

#
# Wait until we can connect to a url given in $1
#
function waitFor() {
    URL="$1"
    TIMEOUT="$2"
    ITER=0
    until $(curl --output /dev/null --silent --head --connect-to --url "$URL"); do
      sleep 1
      echo -ne "."
      ITER=$((ITER+1))
      if [[ "$ITER" -gt "$TIMEOUT" ]] ; then
        echo "Timed out waiting for $URL"
        exit 1
      fi
    done
}

#
# Read all Agents from config file
#
function importAgents() {
    AGENTS=()
    while IFS= read -r HOST
    do
        AGENTS+=("$HOST")
    done < conf/agents.conf
}