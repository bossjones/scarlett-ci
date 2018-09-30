ARG BASE_IMAGE="ubuntu:bionic"

FROM $BASE_IMAGE

LABEL Maintainer "Jarvis <jarvis@theblacktonystark.com>"


ENV NON_ROOT_USER=developer \
    container=docker \
    TERM=xterm-256color

ARG HOST_USER_ID=1000
ENV HOST_USER_ID ${HOST_USER_ID}
ARG HOST_GROUP_ID=1000
ENV HOST_GROUP_ID ${HOST_GROUP_ID}

# Install packages for building ruby
RUN apt-get update && \
    apt-get install -y build-essential curl git && \
    apt-get install -y zlib1g-dev libssl-dev libreadline-dev libyaml-dev libxml2-dev libxslt-dev bash-completion vim tree sudo python2.7-dev && \
    apt-get clean

RUN set -xe \
    && useradd -U -d /home/${NON_ROOT_USER} -m -r -G adm,tty,audio ${NON_ROOT_USER} \
    && usermod -a -G ${NON_ROOT_USER} -s /bin/bash -u ${HOST_USER_ID} ${NON_ROOT_USER} \
    && groupmod -g ${HOST_GROUP_ID} ${NON_ROOT_USER} \
    && ( mkdir /home/${NON_ROOT_USER}/.ssh \
    && chmod og-rwx /home/${NON_ROOT_USER}/.ssh \
    && echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" > /home/${NON_ROOT_USER}/.ssh/authorized_keys \
    ) \
    && echo "${NON_ROOT_USER}     ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && echo "%${NON_ROOT_USER}     ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && cat /etc/sudoers \
    && echo "${NON_ROOT_USER}:${NON_ROOT_USER}" | chpasswd && \
    mkdir /var/run/dbus && \
    mkdir -p /home/${NON_ROOT_USER}/.local/bin && \
    chown ${NON_ROOT_USER}:${NON_ROOT_USER} -Rv /home/${NON_ROOT_USER}

# SOURCE:
# rbenv and ruby-build
RUN curl -fsSL "https://github.com/rbenv/rbenv/archive/v1.1.1.tar.gz" -o /opt/rbenv.tar.gz \
    && \
    mkdir /opt/rbenv && \
    tar -C /opt/rbenv -xzf /opt/rbenv.tar.gz --strip-components 1 \
    && rm /opt/rbenv.tar.gz \
    && \
    curl -fsSL "https://github.com/rbenv/ruby-build/archive/v20180822.tar.gz" -o /opt/ruby-build.tar.gz && \
    mkdir -p /opt/rbenv/plugins/ruby-build && \
    tar -C /opt/rbenv/plugins/ruby-build -xzf /opt/ruby-build.tar.gz --strip-components 1 \
    && rm /opt/ruby-build.tar.gz && \

    curl -fsSL "https://github.com/znz/rbenv-plug/archive/master.tar.gz" -o /opt/rbenv-plug.tar.gz && \
    mkdir -p /opt/rbenv/plugins/rbenv-plug && \
    tar -C /opt/rbenv/plugins/rbenv-plug -xzf /opt/rbenv-plug.tar.gz --strip-components 1 \
    && rm /opt/rbenv-plug.tar.gz \
    && \
    echo 'export RBENV_ROOT=/opt/rbenv' >> /etc/profile.d/rbenv.sh && \
    echo 'export PATH="$RBENV_ROOT/bin:$PATH"' >> /etc/profile.d/rbenv.sh && \
    echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh \
    && \
    bash -c 'set -euo pipefail; \
    . /etc/profile.d/rbenv.sh; \
    rbenv plug each; \
    export CONFIGURE_OPTS="--disable-install-rdoc --disable-install-doc"; \
    for v in \
    2.4.2 \
    ; do \
    echo install $v; \
    rbenv install $v; \
    rbenv global $v; \
    gem install --no-rdoc --no-ri bundler fpm; \
    done \
    ' \
    && \
    echo 'export PATH="~/.local/bin:${PATH}"' >> /etc/profile.d/${NON_ROOT_USER}.sh && \
    echo 'export PATH="/home/${NON_ROOT_USER}/.local/bin:${PATH}"' >> /etc/profile.d/${NON_ROOT_USER}.sh && \
    chown ${NON_ROOT_USER}:${NON_ROOT_USER} -Rv /opt/rbenv /etc/profile.d/rbenv.sh /etc/profile.d/${NON_ROOT_USER}.sh

USER ${NON_ROOT_USER}
WORKDIR /home/${NON_ROOT_USER}

ENV LANG C.UTF-8
ENV CI true

# --------------------------------------------------
# SOURCE: https://github.com/awslabs/amazon-sagemaker-examples/issues/319
# SOURCE: https://github.com/rycus86/webhook-proxy/blob/master/Dockerfile#L18
# Setting PYTHONUNBUFFERED=TRUE or PYTHONUNBUFFERED=1 (they are equivalent) allows for log messages to be immediately dumped to the stream instead of being buffered. This is useful for receiving timely log messages and avoiding situations where the application crashes without emitting a relevant message due to the message being "stuck" in a buffer.

# As for performance, there can be some (minor) loss that comes with using unbuffered I/O. To mitigate this, I would recommend limiting the number of log messages. If it is a significant concern, one can always leave buffered I/O on and manually flush the buffer when necessary.
# --------------------------------------------------
ENV PYTHONUNBUFFERED=1

ENV PYENV_ROOT /home/${NON_ROOT_USER}/.pyenv
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${PATH}"
ENV PYTHON_CONFIGURE_OPTS="--enable-shared"

RUN curl -L https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | bash && \
    git clone https://github.com/jawshooah/pyenv-default-packages ${PYENV_ROOT}/plugins/pyenv-default-packages && \
    find ${PYENV_ROOT} -name "*.tmp" -exec rm {} \; && \
    find ${PYENV_ROOT} -type d -name ".git" -prune -exec rm -rf {} \;

RUN PYTHONDONTWRITEBYTECODE=true pyenv install 3.6.5 && pyenv shell 3.6.5; pip3 install --no-cache-dir tox && \
    pyenv rehash

# COPY requirements.txt requirements.txt
# COPY requirements-dev.txt requirements-dev.txt

# RUN pip3 install --no-cache-dir -r requirements.txt && \
#     pip3 install --no-cache-dir -r requirements-dev.txt && \
#     pip3 install --no-cache-dir tox && \
#     pyenv rehash

# # Copy over everything required to run tox
# COPY setup.cfg setup.py tox.ini ./
# COPY moonbeam_cli/__about__.py moonbeam_cli/__about__.py

RUN tox -e py36 --notest

ENV PATH="/home/${NON_ROOT_USER}/.local/bin:${PATH}"

# add app info as environment variables
ARG GIT_COMMIT
ENV GIT_COMMIT $GIT_COMMIT
ARG BUILD_TIMESTAMP
ENV BUILD_TIMESTAMP $BUILD_TIMESTAMP
