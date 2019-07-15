# Test Runner

The ioFog Test Runner provides a convenient way to run multiple smoke test suites on a deployed Edge Compute Network (ECN).

The suite by default does not run any non-smoke tests, i.e. tests that would invalidate or potentially break the ECN, therefore it can be used on staging a productions ECNs to verify correct deployment.  

The following test suites are available:
* Controller REST API smoke tests
* Agent CLI smoke tests
* Basic microservice deployment integration tests

Note that some of additional test suites are automatically skipped as of this release of Test Runner.

## Usage

| Test suite | Description | Required configuration |
| --- | --- | --- |
| Controller REST API smoke tests | Basic REST API tests on Controller instance | <ul><li>CONTROLLER</li><li>CONTROLLER_EMAIL</li><li>CONTROLLER_PASSWORD</li></ul> |
| Agent CLI smoke tests | Runs Agent tests by SSHing into the Agent nodes and interacting using Agent CLI | <ul><li>AGENTS</li></ul> |
| Basic microservice deployment integration tests | Sets up users and catalog entries, deploys and destroys microservices on each Agent | <ul><li>CONTROLLER</li><li>CONTROLLER_EMAIL</li><li>CONTROLLER_PASSWORD</li><li>AGENTS</li></ul> |


The format of the environment variables is the following:

* _CONTROLLER_ - IP:PORT format (e.g. "1.2.3.4:51121")
* _CONTROLLER_EMAIL_ - existing user identifier in Controller to use for testing (e.g. "user@domain.com")
* _CONTROLLER_PASSWORD_ - login password for the user (e.g. "#Bugs4Fun")
* _AGENTS_ - comma separated URI with user and optional port (e.g. root@1.2.3.4:6451,user@6.7.8.9)

Note that whenever _AGENTS_ is specified, you need to mount appropriate ssh keys to /root/.ssh of the test-runner containers. The keys can be in any default SSH position: ~/.ssh/id_dsa, ~/.ssh/id_ecdsa, ~/.ssh/id_ed25519 and ~/.ssh/id_rsa.

Example usage of the test runner with full configuration:

```bash
docker run --name test-runner \
        -v ~/.ssh/my_iofog_ssh_key:/root/.ssh/id_rsa \
        -e CONTROLLER="1.2.3.4:51121" \
        -e CONTROLLER_EMAIL="user@domain.com" \
        -e CONTROLLER_PASSWORD="#Bugs4Fun" \
        -e AGENTS="root@1.2.3.4:6451,user@6.7.8.9" \
        iofog/test-runner:latest
```

## Test Results

The output of this test-suite currently is a single XML File that is Junit-XML compliant.
This can be used in development pipelines on most DevOps infrastructure to display test results
in easy to consume factor.

This is used in Azure Pipelines to display each builds pass/fail for both entire test suites
as well as for specific tests we may see multiple failures in, to help identify issues that may not be consistent.

The output is currently denoted as TEST-RESULTS.xml