#!/usr/bin/env bash

. tests/functions.bash

ioFog Unified Command Line Interface

Usage:
  iofogctl [command]

Available Commands:
  create      Create an ioFog resource
  delete      Delete existing ioFog resources
  deploy      Deploy ioFog stack on existing infrastructure
  describe    Get detailed information of existing resources
  get         Get information of existing resources
  help        Help about any command
  legacy      Execute commands using legacy CLI
  logs        Get log contents of deployed resource

Flags:
      --config string      CLI configuration file (default is ~/.iofog.yaml)
  -h, --help               help for iofogctl
  -n, --namespace string   Namespace to execute respective command within (default "default")

Use "iofogctl [command] --help" for more information about a command.

@test "Test CLI Commands" {
  forKubectl "get pods"
}