# NOTE [Thomas, 20241226] Pin the version of Alpine to 3.20.
# Newer versions of Alpine use CMake 3.31 or higher, which adds a deprecation warning
# when CMake versions below 3.10 are used. This will fail the uamqp installation,
# because azure-uamqp-c has CMake version 3.5 specified in its CMakeLists.txt.
# See https://github.com/Azure/azure-uamqp-c/blob/96d7179f60e558b2c350194ea0061c725377f7e0/CMakeLists.txt#L4
FROM python:3.11-alpine3.20

ARG VERSION="git"
ARG PACKAGES="bash libffi openssh-client openssl rsync tini gcc libffi-dev linux-headers make musl-dev openssl-dev rust cargo"

LABEL name="algo" \
      version="${VERSION}" \
      description="Set up a personal IPsec VPN in the cloud" \
      maintainer="Trail of Bits <http://github.com/trailofbits/algo>"

RUN apk --no-cache add ${PACKAGES}
RUN adduser -D -H -u 19857 algo
RUN mkdir -p /algo && mkdir -p /algo/configs

WORKDIR /algo
COPY requirements.txt .
RUN python3 -m pip --no-cache-dir install -U pip && \
    python3 -m pip --no-cache-dir install virtualenv && \
    python3 -m virtualenv .env && \
    source .env/bin/activate && \
    python3 -m pip --no-cache-dir install -r requirements.txt
COPY . .
RUN chmod 0755 /algo/algo-docker.sh

# NOTE [Thomas, 20241226] Install uamqp from source, necessary for the Azure requirements from Ansible
# See also https://forum.ansible.com/t/not-able-to-install-azcollection-requirements-azure-txt/5138/5
RUN apk --no-cache add python3 py-pip python3-dev cmake gcc g++ openssl-dev build-base
RUN pip3 install uamqp --no-binary :all:

# Because of the bind mounting of `configs/`, we need to run as the `root` user
# This may break in cases where user namespacing is enabled, so hopefully Docker
# sorts out a way to set permissions on bind-mounted volumes (`docker run -v`)
# before userns becomes default
# Note that not running as root will break if we don't have a matching userid
# in the container. The filesystem has also been set up to assume root.
USER root
CMD [ "/algo/algo-docker.sh" ]
ENTRYPOINT [ "/sbin/tini", "--" ]
