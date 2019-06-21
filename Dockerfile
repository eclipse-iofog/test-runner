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
    jq

RUN brew tap eclipse-iofog/iofogctl && brew install iofogctl

RUN git clone https://github.com/sstephenson/bats.git && cd bats && ./install.sh /usr/local

# Install the pyresttest and deps (the basis of all our smoke tests)
RUN pip install pyresttest jsonschema future shyaml

# Copy over all the files we need
COPY functions.bash /
COPY run.bash /
COPY tests /tests/

# Run our tests
CMD [ "/run.bash" ]