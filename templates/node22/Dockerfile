FROM node:22-bookworm-slim

ENV DENO_VERSION=1.43.5
# Digest for zip version 1.43.5 is not available in the release assets, so we keep it hardcoded as a fallback
ENV DENO_LEGACY_DIGEST='246bf818932c5e11adb85afaaf3c90e65d5cbe14bcaa8ea14d35fc085869775d'

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
  amd64) ARCH='x86_64';; \
  arm64) ARCH='aarch64';; \
  *) echo "unsupported Deno architecture"; exit 1 ;; \
  esac \
  && set -ex \
  && apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/* \
  && DENO_ZIP_NAME=deno-${ARCH}-unknown-linux-gnu.zip \
  && DENO_DIGEST=$( (curl -fs https://dl.deno.land/release/v${DENO_VERSION}/${DENO_ZIP_NAME}.sha256sum || echo ${DENO_LEGACY_DIGEST}) | awk '{print $1}') \
  && curl -fsSL https://dl.deno.land/release/v${DENO_VERSION}/${DENO_ZIP_NAME} --output /tmp/${DENO_ZIP_NAME} \
  && echo "${DENO_DIGEST} /tmp/${DENO_ZIP_NAME}" | sha256sum -c - \
  && unzip /tmp/${DENO_ZIP_NAME} -d /tmp \
  && rm /tmp/${DENO_ZIP_NAME} \
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

ENV RC_VERSION=7

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
