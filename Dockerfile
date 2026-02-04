FROM mcr.microsoft.com/devcontainers/typescript-node:20-bookworm

ARG SDK_VERSION=commandlinetools-linux-11076708_latest.zip
ARG ANDROID_BUILD_VERSION=36
ARG ANDROID_TOOLS_VERSION=36.0.0
ARG NDK_VERSION=27.1.12297006
ARG NODE_VERSION=22.14
ARG WATCHMAN_VERSION=4.9.0
ARG CMAKE_VERSION=3.30.5
ARG RUNNER_VERSION=2.331.0

# set default environment variables, please don't remove old env for compatibilty issue
ENV ADB_INSTALL_TIMEOUT=10
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
ENV ANDROID_NDK_HOME=${ANDROID_HOME}/ndk/$NDK_VERSION

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV CMAKE_BIN_PATH=${ANDROID_HOME}/cmake/$CMAKE_VERSION/bin

ENV PATH=${CMAKE_BIN_PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/emulator:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${PATH}


# Prevents installdependencies.sh from prompting the user and blocking the image creation
ARG DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt update -y && apt upgrade -y
RUN apt install -qq -y --no-install-recommends \
        usbutils \
        openjdk-17-jdk-headless \
        ruby \
        ruby-dev \
        ninja-build \
        # Dev libraries requested by Hermes
        libicu-dev \
        # Dev dependencies required by linters
        jq \
        ;
RUN gem install bundler;
RUN rm -rf /var/lib/apt/lists/*;

# Full reference at https://dl.google.com/android/repository/repository2-1.xml
# download and unpack android
RUN curl -sS https://dl.google.com/android/repository/${SDK_VERSION} -o /tmp/sdk.zip \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && unzip -q -d ${ANDROID_HOME}/cmdline-tools /tmp/sdk.zip \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm /tmp/sdk.zip \
    && yes | sdkmanager --licenses \
    && yes | sdkmanager "platform-tools" \
        "platforms;android-$ANDROID_BUILD_VERSION" \
        "build-tools;$ANDROID_TOOLS_VERSION" \
        "cmake;$CMAKE_VERSION" \
        "ndk;$NDK_VERSION" \
    && rm -rf ${ANDROID_HOME}/.android \
    && chmod 777 -R /opt/android

# Disable git safe directory check as this is causing GHA to fail on GH Runners
RUN git config --global --add safe.directory '*'

# Configure USB/ADB access for Android development
RUN groupadd -f plugdev \
    && usermod -a -G plugdev node \
    && mkdir -p /etc/udev/rules.d \
    && echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"' > /etc/udev/rules.d/51-android.rules \
    && echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"' >> /etc/udev/rules.d/51-android.rules \
    && echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0bb4", MODE="0666", GROUP="plugdev"' >> /etc/udev/rules.d/51-android.rules \
    && echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", MODE="0666", GROUP="plugdev"' >> /etc/udev/rules.d/51-android.rules \
    && echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1004", MODE="0666", GROUP="plugdev"' >> /etc/udev/rules.d/51-android.rules \
    && chmod 644 /etc/udev/rules.d/51-android.rules

RUN cd /home/node && mkdir actions-runner && cd actions-runner \
    && curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

RUN chown -R node ~node && /home/node/actions-runner/bin/installdependencies.sh

COPY start.sh start.sh

# make the script executable
RUN chmod +x start.sh

# since the config and run script for actions are not allowed to be run by root,
# set the user to "docker" so all subsequent commands are run as the docker user
USER node

ENTRYPOINT ["./start.sh"]