## Start Hack
FROM debian:jessie-slim
## All of this needed because of missing 8.11.x tag.  Once we update to 8.15+ we can resume using Dockerfile.old or remove hack and use FROM node:8-slim

## Installing Node.js
RUN gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys DD8F2338BAE7501E3DD5AC78C273792F7D83545D
ENV NODE_VERSION 8.15.1
ENV NODE_ENV production
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates curl fontconfig; \
	rm -rf /var/lib/apt/lists/*; \
	curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz"; \
	curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc"; \
	gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc; \
	grep " node-v$NODE_VERSION-linux-x64.tar.gz\$" SHASUMS256.txt | sha256sum -c -; \
	tar -xf "node-v$NODE_VERSION-linux-x64.tar.gz" -C /usr/local --strip-components=1 --no-same-owner; \
	rm "node-v$NODE_VERSION-linux-x64.tar.gz" SHASUMS256.txt.asc SHASUMS256.txt; \
	npm cache clear --force
## End Hack

## Actual Rocket.Chat stuff
LABEL maintainer="buildmaster@rocket.chat"

RUN groupadd -r rocketchat \
&&  useradd -r -g rocketchat rocketchat \
&&  mkdir -p /app/uploads \
&&  chown rocketchat:rocketchat /app/uploads

VOLUME /app/uploads

# gpg: key 4FD08104: public key "Rocket.Chat Buildmaster <buildmaster@rocket.chat>" imported
RUN gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys 0E163286C20D07B9787EBE9FD7F9D0414FD08104

ENV RC_VERSION 2.4.9

WORKDIR /app

RUN set -x; BUILDDEPS="python make git g++" \
&&  apt-get update &&  apt-get install -y --no-install-recommends ${BUILDDEPS} \
&&  curl -fSL "https://releases.rocket.chat/${RC_VERSION}/download" -o rocket.chat.tgz \
&&  curl -fSL "https://releases.rocket.chat/${RC_VERSION}/asc" -o rocket.chat.tgz.asc \
&&  gpg --batch --verify rocket.chat.tgz.asc rocket.chat.tgz \
&&  tar zxf rocket.chat.tgz \
&&  rm rocket.chat.tgz rocket.chat.tgz.asc \
&&  cd bundle/programs/server \
&&  npm install \
&&  npm cache clear --force \
&&  chown -R rocketchat:rocketchat /app \
&&  cd /app/bundle/programs/server/npm \
&&  npm uninstall sharp && npm install sharp \
&&  cd /app/bundle/programs/server/npm \
&&  npm uninstall grpc && npm install grpc \
&&  apt-get purge -y --auto-remove $BUILDDEPS

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
