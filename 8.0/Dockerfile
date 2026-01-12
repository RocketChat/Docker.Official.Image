FROM node:22-bookworm-slim

ENV DENO_VERSION=1.43.5

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
  amd64) ARCH='x86_64';; \
  arm64) ARCH='aarch64';; \
  *) echo "unsupported Deno architecture"; exit 1 ;; \
  esac \
  && set -ex \
  && apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL https://dl.deno.land/release/v${DENO_VERSION}/deno-${ARCH}-unknown-linux-gnu.zip --output /tmp/deno-${ARCH}-unknown-linux-gnu.zip \
  && echo "246bf818932c5e11adb85afaaf3c90e65d5cbe14bcaa8ea14d35fc085869775d /tmp/deno-x86_64-unknown-linux-gnu.zip" | sha256sum -c - \
  && unzip /tmp/deno-${ARCH}-unknown-linux-gnu.zip -d /tmp \
  && rm /tmp/deno-${ARCH}-unknown-linux-gnu.zip \
  && chmod 755 /tmp/deno \
  && mv /tmp/deno /usr/local/bin/deno \
  && apt-mark auto '.*' > /dev/null \
  && find /usr/local -type f -executable -exec ldd '{}' ';' \
  | awk '/=>/ { print $(NF-1) }' \
  | sort -u \
  | xargs -r dpkg-query --search \
  | cut -d: -f1 \
  | sort -u \
  | xargs -r apt-mark manual \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

RUN groupadd -r rocketchat \
  && useradd -r -g rocketchat rocketchat \
  && mkdir -p /app/uploads \
  && chown rocketchat:rocketchat /app/uploads

VOLUME /app/uploads

WORKDIR /app

ENV NODE_ENV=production

ENV RC_VERSION=8.0.1

RUN set -eux \
  && apt-get update \
  && apt-get install -y --no-install-recommends fontconfig \
  && aptMark="$(apt-mark showmanual)" \
  && apt-get install -y --no-install-recommends g++ make python3 ca-certificates curl gnupg \
  && rm -rf /var/lib/apt/lists/* \
  # gpg: key 4FD08104: public key "Rocket.Chat Buildmaster <buildmaster@rocket.chat>" imported
  && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 0E163286C20D07B9787EBE9FD7F9D0414FD08104 \
  && curl -fSL "https://releases.rocket.chat/${RC_VERSION}/download" -o rocket.chat.tgz \
  && curl -fSL "https://releases.rocket.chat/${RC_VERSION}/asc" -o rocket.chat.tgz.asc \
  && gpg --batch --verify rocket.chat.tgz.asc rocket.chat.tgz \
  && tar zxf rocket.chat.tgz \
  && rm rocket.chat.tgz rocket.chat.tgz.asc \
  && cd bundle/programs/server \
  && npm install --unsafe-perm=true \
  && apt-mark auto '.*' > /dev/null \
  && apt-mark manual $aptMark > /dev/null \
  && find /usr/local -type f -executable -exec ldd '{}' ';' \
  | awk '/=>/ { print $(NF-1) }' \
  | sort -u \
  | xargs -r dpkg-query --search \
  | cut -d: -f1 \
  | sort -u \
  | xargs -r apt-mark manual \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && npm cache clear --force \
  && chown -R rocketchat:rocketchat /app

USER rocketchat

WORKDIR /app/bundle

# needs a mongoinstance - defaults to container linking with alias 'db'
ENV DEPLOY_METHOD=docker-official \
  MONGO_URL=mongodb://db:27017/meteor \
  HOME=/tmp \
  PORT=3000 \
  ROOT_URL=http://localhost:3000

EXPOSE 3000

CMD ["node", "main.js"]
