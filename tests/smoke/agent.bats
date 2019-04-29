#!/usr/bin/env bats

. tests/functions.bash

importAgents

@test "Checking SSH Connection" {
  forAgents "echo Connected"
}

@test "Checking Agents Statuses" {
  forAgents "iofog-agent status"
}

@test "Checking Agents Network Interface Config" {
  forAgentsOutputContains "cat /etc/iofog-agent/config.xml | grep '<network_interface>'" "eth0"
}

@test "iofog-agent version" {
  forAgentsOutputContains "iofog-agent version" "1.0"
}

@test "iofog-agent info" {
  forAgentsOutputContains "iofog-agent info" "Iofog UUID"
}

@test "iofog-agent provision BAD" {
  forAgentsOutputContains "iofog-agent provision asd" "Invalid Provisioning Key"
}

@test "iofog-agent config INVALID RAM" {
  forAgentsOutputContains "iofog-agent config -m 50" "Memory limit range"
}

@test "iofog-agent config RAM string" {
  forAgentsOutputContains "iofog-agent config -m test" "invalid value"
}

@test "iofog-agent config VALID RAM" {
  forAgentsOutputContains "iofog-agent config -m 1024" "New Value"
}
