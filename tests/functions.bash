#!/usr/bin/env bash

function forAgentsOutputContains(){
    local CMD="$1"
    local SUBSTR="$2"
    for AGENT in "${AGENTS[@]}"; do
        local USERNAME_HOST="${AGENT%:*}"
        local PORT="$(echo "${AGENT}" | cut -d':' -s -f2)"
        local PORT="${PORT:-22}"
        local RESULT=$(ssh -o StrictHostKeyChecking=no "${USERNAME_HOST}" -p "${PORT}" "sudo $CMD")
        [[ "$RESULT" == *"$SUBSTR"* ]]
    done
}

function forAgents(){
    local CMD="$1"
    for AGENT in "${AGENTS[@]}"; do
        local USERNAME_HOST="${AGENT%:*}"
        local PORT="$(echo "${AGENT}" | cut -d':' -s -f2)"
        local PORT="${PORT:-22}"
        ssh -o StrictHostKeyChecking=no "${USERNAME_HOST}" -p "${PORT}" "sudo $CMD"
        [[ $? == 0 ]]
    done
}

# Kubectl with status comparison
function forKubectl(){
    CMD="$1"
    result=$(kubectl ${CMD})
    [[ $? == 0 ]]
}

function forIofogCTL(){
    CMD="$1"
    result=$(iofogctl ${CMD})
    [[ $? == 0 ]]
}

function forIofogCTLNegative(){
    CMD="$1"
    result=$(iofogctl ${CMD})
    [[ $? > 0 ]]
}

function forIofogCTLCompare(){
    CMD="$1"
    SUBSTR="$2"
    result=$(iofogctl ${CMD})
    [[ ${result} == *"$SUBSTR"* ]]
}

# Kubectl with status comparison
function NegativeKubeCtl(){
    CMD="$1"
    result=$(kubectl ${CMD})
    [[ $? > 0 ]]
}

# Kubectl with output comparison
function forKubectlOutputContains(){
    CMD="$1"
    SUBSTR="$2"
    result=$(kubectl "$CMD")
    [[ ${result} == *"$SUBSTR"* ]]
}

# Import our config stuff, so we aren't hardcoding the variables we're testing for. Add to this if more tests are needed
function importConfig() {
    CONF=$(cat config.json)
    PORTS=$(echo "$CONF" | json select '.ports')
    ENV_VAR=$(echo "$CONFG" | json select '.environment')
    VOL_FILE=$(echo "$VOL_FILE" | json select '.volumeFile')
}
