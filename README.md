# Test Runner

## Usage

It is recommended you run Test Runner using docker-compose.

You must provide agents.conf and a corresponding id_ecdsa/id_ecdsa.pub pair in /conf of the runner. This should be done through a volume in your docker-compose.yml.

To Run K4G testing, you must also pass a kube.conf file to `run.bash` with the `-k` argument

e.g.
```bash
./run.bash -k /path/to/file/kube.conf
```

or for automated deploy testing, please ensure that your agents.conf file contains a top level
`kubeconf` key, with the location of the file.

For local deployments:
```
version: "3"
services:
    test-runner:
        image: iofog/test-runner-develop:latest
        container_name: test-runner
        environment:
            - LOCAL=1
        network_mode: "bridge"
        external_links: 
            - iofog-controller
            - iofog-connector
            - iofog-agent
        volumes:
            - /path/to/host/conf:/conf
volumes:
  conf:
```

For remote deployments:
```
version: "3"
services:
    test-runner:
        image: iofog/test-runner-develop:latest
        container_name: test-runner
        network_mode: "bridge"
        volumes:
            - /path/to/host/conf:/conf
volumes:
  conf:
```

Once the docker-compose.yml is ready, run the following.

```
docker-compose pull test-runner

docker-compose up \
    --build \
    --abort-on-container-exit \
    --exit-code-from test-runner \
    --force-recreate \
    --renew-anon-volumes

docker-compose down -v
```