#!/usr/bin/env bash

. tests/functions.bash

@test "Help" {
  forIofogCTL "--help"
}

@test "connect Help" {
  forIofogCTL "connect --help"
}

@test "create Help" {
  forIofogCTL "create --help"
}

@test "delete Help" {
  forIofogCTL "delete --help"
}

@test "deploy Help" {
  forIofogCTL "deploy --help"
}

@test "describe Help" {
  forIofogCTL "describe --help"
}

@test "disconnect Help" {
  forIofogCTL "disconnect --help"
}

@test "legacy Help" {
  forIofogCTL "legacy --help"
}

@test "logs Help" {
  forIofogCTL "logs --help"
}

@test "get Help" {
  forIofogCTL "get --help"
}

@test "version" {
  forIofogCTL "version"
}

@test "Get All" {
  forIofogCTL "get all"
}

@test "Get Namespaces" {
  forIofogCTL "get namespaces"
}

@test "Get Controllers" {
  forIofogCTL "get controllers"
}

@test "Get Agents" {
  forIofogCTL "get agents"
}

@test "Get Microservices" {
  forIofogCTL "get microservices"
}

@test "create namespace" {
  forIofogCTL "create -n iofogctlTest"
}

@test "delete namespace" {
  forIofogCTL "delete -n iofogctlTest"
}

@test "deploy test yaml" {
  forIofogCTL "deploy ~/.iofog.yaml"
}