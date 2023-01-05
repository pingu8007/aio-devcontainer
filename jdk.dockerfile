FROM maven:3.6-adoptopenjdk-15 AS jdk15-mvn36
RUN apt-get update \
    && apt-get install -y ca-certificates sudo software-properties-common \
    && add-apt-repository -y ppa:git-core/ppa && apt-get update \
    && apt-get install -y socat vim curl wget git htop net-tools iputils-ping dnsutils bash-completion \
    && apt-get clean && apt-get auto-clean
CMD [ "/bin/bash" ]

FROM maven:3.8-adoptopenjdk-15 AS jdk15-mvn38
RUN apt-get update \
    && apt-get install -y ca-certificates sudo software-properties-common \
    && add-apt-repository -y ppa:git-core/ppa && apt-get update \
    && apt-get install -y socat vim curl wget git htop net-tools iputils-ping dnsutils bash-completion \
    && apt-get clean && apt-get auto-clean
CMD [ "/bin/bash" ]

FROM jdk15-mvn38 AS jdk15-mvn38-node14
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN update-ca-certificates \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && sudo -u $USERNAME bash -lc "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash" \
    && sudo -u $USERNAME bash -lc "nvm install --lts --latest-npm --no-progress --default 14" \
    && mkdir -p /workspace /project /appdata/.m2 \
        /appdata/.vscode-server/extensions \
        /appdata/.vscode-server-insiders/extensions \
    && ln -s -t /home/$USERNAME /appdata/.m2 \
        /appdata/.vscode-server /appdata/.vscode-server-insiders \
    && chown -R $USERNAME: /workspace /project /appdata
USER $USERNAME
WORKDIR /workspace
