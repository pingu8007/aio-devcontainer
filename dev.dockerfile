# focal, jammy
ARG OS_DIST=jammy
# 8, 15, 17
ARG JDK_VERSION=17
# 0, 1
ARG INSTALL_JDK_SRC=1

FROM alpine:3.18 AS downloader
RUN apk add curl git gnupg dirmngr bash

# prefetch maven
# https://github.com/carlossg/docker-maven/blob/main/eclipse-temurin-11/Dockerfile
FROM downloader AS mvn-builder
ARG MAVEN_VERSION=3.9.3
ARG SHA=400fc5b6d000c158d5ee7937543faa06b6bda8408caa2444a9c947c21472fde0f0b64ac452b8cec8855d528c0335522ed5b6c8f77085811c7e29e1bedbb5daa2
ARG BASE_URL=https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries
ENV MAVEN_HOME /usr/share/maven
RUN set -eux; curl -fsSLO --compressed ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA} *apache-maven-${MAVEN_VERSION}-bin.tar.gz" | sha512sum -c - \
  && curl -fsSLO --compressed ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz.asc \
  && export GNUPGHOME="$(mktemp -d)"; \
  for key in \
  6A814B1F869C2BBEAB7CB7271A2A1C94BDE89688 \
  29BEA2A645F2D6CED7FB12E02B172E3E156466E8 \
  ; do \
  gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" ; \
  done; \
  gpg --batch --verify apache-maven-${MAVEN_VERSION}-bin.tar.gz.asc apache-maven-${MAVEN_VERSION}-bin.tar.gz
RUN mkdir -p ${MAVEN_HOME} ${MAVEN_HOME}/ref \
  && tar -xzf apache-maven-${MAVEN_VERSION}-bin.tar.gz -C ${MAVEN_HOME} --strip-components=1 \
  && ln -s ${MAVEN_HOME}/bin/mvn /usr/bin/mvn

# prefetch nvm & node
FROM downloader AS node-builder
ENV NVM_DIR /usr/share/nvm
# COMPATIBILITY ISSUE! DON'T USE "--latest-npm"!
RUN mkdir -p ${NVM_DIR} \
  && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash \
  && [ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh" \
  && nvm install --lts --no-progress --default 14 \
  && nvm cache clear

# prefetch awscli2
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html
FROM downloader AS aws-builder
ENV AWS_DIR=/usr/share/aws
RUN curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.13.34.zip -o awscliv2.zip \
  && unzip awscliv2.zip -d awscliv2 \
  && mv awscliv2/aws ${AWS_DIR}

# install common package
# https://github.com/adoptium/containers/blob/main/17/jdk/ubuntu/focal/Dockerfile.releases.full
FROM ubuntu:20.04 AS focal-base
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends software-properties-common gpg-agent \
  && add-apt-repository -y ppa:git-core/ppa && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    sudo nano unzip tzdata curl wget ca-certificates fontconfig locales p11-kit binutils \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    socat patch less htop net-tools iputils-ping dnsutils bash-completion openssh-server \
  && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen en_US.UTF-8 \
  && DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove software-properties-common \
  && apt-get clean && apt-get auto-clean && rm -rf /var/lib/apt/lists/*

# install common package
# https://github.com/adoptium/containers/blob/main/17/jdk/ubuntu/jammy/Dockerfile.releases.full
FROM ubuntu:22.04 AS jammy-base
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends software-properties-common gpg-agent \
  && add-apt-repository -y ppa:git-core/ppa && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    sudo nano unzip tzdata curl wget ca-certificates fontconfig locales p11-kit binutils \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    socat patch less htop net-tools iputils-ping dnsutils bash-completion openssh-server \
  && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen en_US.UTF-8 \
  && DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove software-properties-common \
  && apt-get clean && apt-get auto-clean && rm -rf /var/lib/apt/lists/*

# install JDK 8
# https://github.com/adoptium/containers/blob/main/8/jdk/ubuntu/focal/Dockerfile.releases.full
# https://github.com/adoptium/containers/blob/main/8/jdk/ubuntu/jammy/Dockerfile.releases.full
FROM ${OS_DIST}-base AS jdk8-base
ARG INSTALL_JDK_SRC=1
ENV JAVA_VERSION=jdk8u382-b05 JAVA_HOME=/opt/java/openjdk PATH="/opt/java/openjdk/bin:$PATH"
RUN set -eux; \
  ARCH="$(dpkg --print-architecture)"; \
  case "${ARCH}" in \
    aarch64|arm64) \
      ESUM='0951398197b7bef39ab987b59c22852812ee2c2da6549953eed7fced4c08e13d'; \
      BINARY_URL='https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u382-b05/OpenJDK8U-jdk_aarch64_linux_hotspot_8u382b05.tar.gz'; \
      ;; \
    amd64|i386:x86-64) \
      ESUM='789ad24dc0d9618294e3ba564c9bfda9d3f3a218604350e0ce0381bbc8f28db3'; \
      BINARY_URL='https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u382-b05/OpenJDK8U-jdk_x64_linux_hotspot_8u382b05.tar.gz'; \
      ;; \
    *) \
      echo "Unsupported arch: ${ARCH}"; \
      exit 1; \
      ;; \
  esac; \
  wget -O /tmp/openjdk.tar.gz ${BINARY_URL}; \
  echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
  mkdir -p "$JAVA_HOME"; \
  tar --extract \
    --file /tmp/openjdk.tar.gz \
    --directory "$JAVA_HOME" \
    --strip-components 1 \
    --no-same-owner \
  ; \
  [ "${INSTALL_JDK_SRC}" != 1 ] && rm -f ${JAVA_HOME}/src.zip; \
  rm -f /tmp/openjdk.tar.gz; \
  # https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
  find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
  ldconfig;

# install JDK 15
# https://github.com/AdoptOpenJDK/openjdk-docker/blob/master/15/jdk/ubuntu/Dockerfile.hotspot.releases.full
FROM ${OS_DIST}-base AS jdk15-base
ARG INSTALL_JDK_SRC=1
ENV JAVA_VERSION=jdk-15.0.2+7 JAVA_HOME=/opt/java/openjdk PATH="/opt/java/openjdk/bin:$PATH"
RUN set -eux; \
  ARCH="$(dpkg --print-architecture)"; \
  case "${ARCH}" in \
    aarch64|arm64) \
      ESUM='6e8b6b037148cf20a284b5b257ec7bfdf9cc31ccc87778d0dfd95a2fddf228d4'; \
      BINARY_URL='https://github.com/AdoptOpenJDK/openjdk15-binaries/releases/download/jdk-15.0.2%2B7/OpenJDK15U-jdk_aarch64_linux_hotspot_15.0.2_7.tar.gz'; \
      ;; \
    amd64|x86_64) \
      ESUM='94f20ca8ea97773571492e622563883b8869438a015d02df6028180dd9acc24d'; \
      BINARY_URL='https://github.com/AdoptOpenJDK/openjdk15-binaries/releases/download/jdk-15.0.2%2B7/OpenJDK15U-jdk_x64_linux_hotspot_15.0.2_7.tar.gz'; \
      ;; \
    *) \
      echo "Unsupported arch: ${ARCH}"; \
      exit 1; \
      ;; \
  esac; \
  curl -LfsSo /tmp/openjdk.tar.gz ${BINARY_URL}; \
  echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
  mkdir -p /opt/java/openjdk; \
  cd /opt/java/openjdk; \
  tar -xf /tmp/openjdk.tar.gz --strip-components=1; \
  [ "${INSTALL_JDK_SRC}" != 1 ] && rm -f ${JAVA_HOME}/lib/src.zip; \
  rm -f /tmp/openjdk.tar.gz;

# install JDK 17
# https://github.com/adoptium/containers/blob/main/17/jdk/ubuntu/focal/Dockerfile.releases.full
# https://github.com/adoptium/containers/blob/main/17/jdk/ubuntu/jammy/Dockerfile.releases.full
FROM ${OS_DIST}-base AS jdk17-base
ARG INSTALL_JDK_SRC=1
ENV JAVA_VERSION=jdk-17.0.8+7 JAVA_HOME=/opt/java/openjdk PATH="/opt/java/openjdk/bin:$PATH"
RUN set -eux; \
  ARCH="$(dpkg --print-architecture)"; \
  case "${ARCH}" in \
    aarch64|arm64) \
      ESUM='c43688163cfdcb1a6e6fe202cc06a51891df746b954c55dbd01430e7d7326d00'; \
      BINARY_URL='https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.8%2B7/OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.8_7.tar.gz'; \
      ;; \
    amd64|i386:x86-64) \
      ESUM='aa5fc7d388fe544e5d85902e68399d5299e931f9b280d358a3cbee218d6017b0'; \
      BINARY_URL='https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.8%2B7/OpenJDK17U-jdk_x64_linux_hotspot_17.0.8_7.tar.gz'; \
      ;; \
    *) \
      echo "Unsupported arch: ${ARCH}"; \
      exit 1; \
      ;; \
  esac; \
  wget -O /tmp/openjdk.tar.gz ${BINARY_URL}; \
  echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
  mkdir -p "$JAVA_HOME"; \
  tar --extract \
      --file /tmp/openjdk.tar.gz \
      --directory "$JAVA_HOME" \
      --strip-components 1 \
      --no-same-owner \
  ; \
  [ "${INSTALL_JDK_SRC}" != 1 ] && rm -f ${JAVA_HOME}/lib/src.zip; \
  rm -f /tmp/openjdk.tar.gz; \
  # https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
  find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
  ldconfig; \
  # https://github.com/docker-library/openjdk/issues/212#issuecomment-420979840
  # https://openjdk.java.net/jeps/341
  java -Xshare:dump;

FROM ${OS_DIST}-base AS frontend-dev
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG AWS_DIR=/usr/share/aws
ENV NVM_DIR=/usr/share/nvm
COPY --from=node-builder --chown=${USER_UID}:${USER_UID} ${NVM_DIR} ${NVM_DIR}
RUN --mount=from=aws-builder,source=${AWS_DIR},target=${AWS_DIR} \
  update-ca-certificates \
  && addgroup --gid $USER_GID $USERNAME \
  && adduser --uid $USER_UID --gid $USER_GID $USERNAME \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME \
  && mkdir -p /workspace /project \
    /appdata/.m2 \
    /appdata/.npm \
    /appdata/.vscode-server/extensions \
    /appdata/.vscode-server-insiders/extensions \
  && ln -s -t /home/$USERNAME \
    /appdata/.m2 \
    /appdata/.npm \
    /appdata/.vscode-server \
    /appdata/.vscode-server-insiders \
  && chown -R $USERNAME: /workspace /project /appdata \
  \
  && sudo -u $USERNAME NVM_DIR=${NVM_DIR} bash -l ${NVM_DIR}/install.sh && . ${NVM_DIR}/nvm.sh \
  && echo Verifying NVM install ... \
  && echo nvm --version && nvm --version \
  && echo node --version && node --version \
  && echo npm --version && npm --version \
  && echo Complete. \
  \
  && ${AWS_DIR}/install \
  && echo Verifying AWS CLI install ... \
  && echo aws --version && aws --version \
  && echo Complete. \
  \
  && true
USER $USERNAME
WORKDIR /workspace

# install maven binary
FROM jdk${JDK_VERSION}-base AS java-dev
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ENV MAVEN_HOME=/usr/share/maven NVM_DIR=/usr/share/nvm
COPY --from=mvn-builder ${MAVEN_HOME} ${MAVEN_HOME}
COPY --from=node-builder --chown=${USER_UID}:${USER_UID} ${NVM_DIR} ${NVM_DIR}
RUN update-ca-certificates \
  && addgroup --gid $USER_GID $USERNAME \
  && adduser --uid $USER_UID --gid $USER_GID $USERNAME \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME \
  && mkdir -p /workspace /project \
    /appdata/.m2 \
    /appdata/.npm \
    /appdata/.vscode-server/extensions \
    /appdata/.vscode-server-insiders/extensions \
  && ln -s -t /home/$USERNAME \
    /appdata/.m2 \
    /appdata/.npm \
    /appdata/.vscode-server \
    /appdata/.vscode-server-insiders \
  && chown -R $USERNAME: /workspace /project /appdata \
  \
  && ln -s ${MAVEN_HOME}/bin/mvn /usr/bin/mvn \
  && echo Verifying MAVEN install ... \
  # && fileEncoding="$(echo 'System.out.println(System.getProperty("file.encoding"))' | jshell -s -)"; [ "$fileEncoding" = 'UTF-8' ]; rm -rf ~/.java \
  && echo javac -version && javac -version \
  && echo java -version && java -version \
  && echo mvn -version && mvn -version \
  && echo Complete. \
  \
  && sudo -u $USERNAME NVM_DIR=${NVM_DIR} bash -l ${NVM_DIR}/install.sh && . ${NVM_DIR}/nvm.sh \
  && echo Verifying NVM install ... \
  && echo nvm --version && nvm --version \
  && echo node --version && node --version \
  && echo npm --version && npm --version \
  && echo Complete. \
  \
  && true
USER $USERNAME
WORKDIR /workspace
