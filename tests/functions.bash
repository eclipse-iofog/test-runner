#!/usr/bin/env bash

. ../functions.bash

function forAgentsOutputContains(){
    CMD="$1"
    SUBSTR="$2"
    for AGENT in "${AGENTS[@]}"; do
        RESULT=$(ssh -i conf/id_ecdsa -o StrictHostKeyChecking=no "$AGENT" "sudo $CMD")
        [[ "$RESULT" == *"$SUBSTR"* ]]
    done
}

function forAgents(){
    CMD="$1"
    for AGENT in "${AGENTS[@]}"; do
        ssh -i conf/id_ecdsa -o StrictHostKeyChecking=no "$AGENT" "sudo $CMD"
    done
}

function forKubectl(){
    CMD="$1"
    result=$(kubectl "$CMD" --kubeconfig ../conf/kube.conf)
    [[ $? > 0 ]]
}

function forKubectlOutputContains(){
    CMD="$1"
    SUBSTR="$2"
    result=$(kubectl "$CMD" --kubeconfig ../conf/kube.conf)
    [[ ${result} == *"$SUBSTR"* ]]
}

# Import our config stuff, so we aren't hardcoding the variables we're testing for. Add to this if more tests are needed
function importConfig() {
    CONF=$(cat config.json)
    PORTS=$(echo "$CONF" | json select '.ports')
    ENV_VAR=$(echo "$CONFG" | json select '.environment')
    VOL_FILE=$(echo "$VOL_FILE" | json select '.volumeFile')
}