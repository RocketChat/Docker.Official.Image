FROM node:12.14-slim

## Actual Rocket.Chat stuff
LABEL maintainer="buildmaster@rocket.chat"

RUN set -x \
&&  groupadd -r rocketchat \
&&  useradd -r -g rocketchat rocketchat \
&&  mkdir -p /app/uploads \
&&  chown rocketchat:rocketchat /app/uploads \
&& apt-get update \
&& apt-get install -y -o Dpkg::Options::="--force-confdef" --no-install-recommends \
   imagemagick \
   fontconfig \
   ca-certificates \
   curl \
   gpg \
   dirmngr \
&& apt-get clean all

VOLUME /app/uploads

# fix for IPv6 build environments https://rvm.io/rvm/security#ipv6-issues
RUN echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf
# gpg: key 4FD08104: public key "Rocket.Chat Buildmaster <buildmaster@rocket.chat>" imported
RUN gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys 0E163286C20D07B9787EBE9FD7F9D0414FD08104

ENV RC_VERSION 3.0.2

WORKDIR /app

RUN curl -fSL "https://releases.rocket.chat/${RC_VERSION}/download" -o rocket.chat.tgz \
&&  curl -fSL "https://releases.rocket.chat/${RC_VERSION}/asc" -o rocket.chat.tgz.asc \
&&  gpg --batch --verify rocket.chat.tgz.asc rocket.chat.tgz \
&&  tar zxvf rocket.chat.tgz \
&&  rm rocket.chat.tgz rocket.chat.tgz.asc \
&&  cd bundle/programs/server \
&&  npm install \
&&  npm cache clear --force \
&&  chown -R rocketchat:rocketchat /app

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
