
FROM frenzylab/devcontainer:latest

RUN apt-get update && apt-get install -y \
    pkg-config \
    npm \
    && npm install yarn --global

WORKDIR /workspace