#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

# You can use any Debian/Ubuntu based image as a base
FROM debian:11.3-slim

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# This Dockerfile adds a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Configure apt and install packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends apt-utils dialog 2>&1 \
    #
    # Verify git, process tools installed
    && apt-get -y install git openssh-client less iproute2 procps \
    #
    # Install Docker CE CLI
    && apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common lsb-release \
    && curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | (OUT=$(apt-key add - 2>&1) || echo $OUT) \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    #
    # Install kubectl
    && curl -sSL -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    #
    # Install Helm
    && curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash - \
    #
    # Copy localhost's ~/.kube/config file into the container and swap out localhost
    # for host.docker.internal whenever a new shell starts to keep them in sync.
    && echo '\n\
        if [[ "$SYNC_LOCALHOST_KUBECONFIG" == "true" ]]; then\n\
            mkdir -p $HOME/.kube\n\
            cp -r $HOME/.kube-localhost/* $HOME/.kube\n\
            sed -i -e "s/localhost/host.docker.internal/g" $HOME/.kube/config\n\
        \n\
            if [ -d "$HOME/.minikube-localhost" ]; then\n\
                mkdir -p $HOME/.minikube\n\
                cp -r $HOME/.minikube-localhost/ca.crt $HOME/.minikube\n\
                sed -i -r "s|(\s*certificate-authority:\s).*|\\1$HOME\/.minikube\/ca.crt|g" $HOME/.kube/config\n\
                cp -r $HOME/.minikube-localhost/client.crt $HOME/.minikube\n\
                sed -i -r "s|(\s*client-certificate:\s).*|\\1$HOME\/.minikube\/client.crt|g" $HOME/.kube/config\n\
                cp -r $HOME/.minikube-localhost/client.key $HOME/.minikube\n\
                sed -i -r "s|(\s*client-key:\s).*|\\1$HOME\/.minikube\/client.key|g" $HOME/.kube/config\n\
            fi\n\
        fi' \
        >> $HOME/.bashrc \
    #
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
    && chmod 0440 /etc/sudoers.d/$USERNAME
    #
    # # Clean up
    # && apt-get autoremove -y \
    # && apt-get clean -y \
    # && rm -rf /var/lib/apt/lists/*

RUN apt install -y build-essential direnv zsh vim

RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && echo 'eval "$(direnv hook zsh)"' >> "/root/.zshrc"

RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && echo $SNIPPET >> "/root/.zshrc"


ARG DOCTL_VERSION=1.43.0
RUN curl -sL https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz | tar -xzv \
    && mv doctl /usr/local/bin

RUN helm plugin install https://github.com/futuresimple/helm-secrets 

RUN curl -sSL -o /usr/local/bin/sops https://github.com/mozilla/sops/releases/download/v3.5.0/sops-v3.5.0.linux 

RUN curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
RUN sudo install skaffold /usr/local/bin/


ARG VELERO_VERSION=v1.3.2
ARG VELERO_NAME=velero-${VELERO_VERSION}-linux-amd64
RUN curl -sL https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/${VELERO_NAME}.tar.gz | tar -xzv \
      && mv ${VELERO_NAME}/velero /usr/local/bin \
      && rm -rf ${VELERO_NAME}


RUN apt install -y unzip
RUN curl -Lo awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
    && unzip awscliv2.zip \
    && sudo ./aws/install

ARG CURRENT_SAML_VERSION=2.26.1
RUN CURRENT_SAML_VERSION=${CURRENT_SAML_VERSION} curl -sL "https://github.com/Versent/saml2aws/releases/download/v${CURRENT_SAML_VERSION}/saml2aws_${CURRENT_SAML_VERSION}_linux_amd64.tar.gz" | tar -xzv \
    && mv saml2aws /usr/local/bin

RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf
RUN sed -i "/^plugins=(/ s/\([^)]*\)/\1 asdf/" /root/.zshrc


ARG DOCKER_COMPOSE_VERSION=2.5.1
RUN sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose
# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog
