#
# Test Runner is an image built to execute a set of unit and integration tests for
# the 'demo' project.
#
FROM python:3

# Install our deps
RUN apt-get update -qq && apt-get install -y \
    sudo \
    python-pycurl \
    vim \
    jq \
    rubygems

# Set the Kubernetes version as found in the UCP Dashboard or API
RUN k8sversion=v1.11.5 && curl -LO https://storage.googleapis.com/kubernetes-release/release/$k8sversion/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl

RUN git clone https://github.com/sstephenson/bats.git && cd bats && ./install.sh /usr/local

# Install the pyresttest and deps (the basis of all our smoke tests)
RUN pip install pyresttest jsonschema future shyaml

# Copy over all the files we need
COPY functions.bash /
COPY run.bash /
COPY tests /tests/

# Run our tests
CMD /run.bash