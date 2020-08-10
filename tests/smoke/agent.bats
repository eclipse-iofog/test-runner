#!/usr/bin/env bats

. tests/functions.bash

#importAgents

@test "Checking Agents Statuses" {
  forAgents "status"
}

# TODO: (Serge) Interface names changes based on deployment, rewrite this test
#@test "Checking Agents Network Interface Config" {
#  forAgentsOutputContains "cat /etc/iofog-agent/config.xml | grep '<network_interface>'" "eth0"
#}

@test "iofog-agent version" {
  forAgentsOutputContains "version" "ioFog"
}

@test "iofog-agent info" {
  forAgentsOutputContains "info" "Iofog UUID"
}

@test "iofog-agent provision BAD" {
  forAgentsOutputContains "provision asd" "Invalid Provisioning Key"
}

@test "iofog-agent config INVALID RAM" {
  forAgentsOutputContains "config -m 50" "Memory limit range"
}

@test "iofog-agent config RAM string" {
  forAgentsOutputContains "config -m test" "invalid value"
}

@test "iofog-agent config VALID RAM" {
  forAgentsOutputContains "config -m 1024" "New Value"
}

# Test that the SSH connection to Agents is Valid
@test "Integration Test UUID is Available" {
  forAgentsOutputContains "info | grep UUID" "UUID"
}

# Test that the SSH connection to Agents is Valid
@test "Integration Test Connection to Controller" {
  forAgentsOutputContains "status | grep 'Connection to Controller'" "ok"
}
