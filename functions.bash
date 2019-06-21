#!/usr/bin/env bash
# shellcheck disable=SC1003

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

function yaml() {
    hashdot=$(gem list hash_dot);
    if ! [[ "$hashdot" != "" ]]; then sudo gem install "hash_dot" ; fi
    if [[ -f $1 ]];then
        cmd=" Hash.use_dot_syntax = true; hash = YAML.load(File.read('$1'));";
        if [[ "$2" != "" ]] ;then
            cmd="$cmd puts hash.$2;"
        else
            cmd="$cmd puts hash;"
        fi
        ruby  -r yaml -r hash_dot <<< $cmd;
    fi
}