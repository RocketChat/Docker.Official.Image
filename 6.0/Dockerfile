FROM debian:buster-slim

## Installing Node.js
ENV NODE_ENV production
ENV NODE_VERSION 14.21.2

# Node installation based on https://github.com/nodejs/docker-node/blob/66b46292a6e5dd5856b1d5204dc51547c80eb17a/12/buster-slim/Dockerfile
RUN ARCH="x64" \
  && set -eux \
  && apt-get update && apt-get install -y --no-install-recommends ca-certificates curl wget gnupg dirmngr xz-utils \
  && rm -rf /var/lib/apt/lists/* \
  && for key in \
  4ED778F539E3634C779C87C6D7062848A1AB005C \
  94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
  74F12602B6F1C4E913FAA37AD3A89613643B6201 \
  71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
  8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
  C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
  C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
  DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
  A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
  108F52B48DB57BB0CC439B2997B01419BD92F80A \
  B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
  gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
  gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
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

ENV RC_VERSION 6.0.7

WORKDIR /app

RUN set -eux \
  && apt-get update \
  && apt-get install -y --no-install-recommends fontconfig \
  && aptMark="$(apt-mark showmanual)" \
  && apt-get install -y --no-install-recommends g++ make python ca-certificates curl gnupg \
  && rm -rf /var/lib/apt/lists/* \
  # gpg: key 4FD08104: public key "Rocket.Chat Buildmaster <buildmaster@rocket.chat>" imported
  && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 0E163286C20D07B9787EBE9FD7F9D0414FD08104 \
  && curl -fSL "https://releases.rocket.chat/${RC_VERSION}/download" -o rocket.chat.tgz \
  && curl -fSL "https://releases.rocket.chat/${RC_VERSION}/asc" -o rocket.chat.tgz.asc \
  && gpg --batch --verify rocket.chat.tgz.asc rocket.chat.tgz \
  && tar zxf rocket.chat.tgz \
  && rm rocket.chat.tgz rocket.chat.tgz.asc \
  && cd bundle/programs/server \
  && npm install \
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
  ROOT_URL=http://localhost:3000 \
  Accounts_AvatarStorePath=/app/uploads

EXPOSE 3000

CMD ["node", "main.js"]
