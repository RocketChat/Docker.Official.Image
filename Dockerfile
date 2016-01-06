FROM node:0.10

# crafted and tuned by pierre@ozoux.net and sli@makawave.com
MAINTAINER buildmaster@rocket.chat 

RUN apt-get update \
&& apt-get install -y graphicsmagick \
&& rm -rf /var/lib/apt/lists/*

RUN groupadd -r rocketchat \
&&  useradd -r -g rocketchat rocketchat

# gpg: key 4FD08014: public key "Rocket.Chat Buildmaster <buildmaster@rocket.chat>" imported
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 0E163286C20D07B9787EBE9FD7F9D0414FD08104

ENV RC_VERSION 0.12.1

RUN curl -fSL "https://github.com/RocketChat/Rocket.Chat/releases/download/v${RC_VERSION}/rocket.chat.tgz" -o rocket.chat.tgz \
&&  curl -fSL "https://github.com/RocketChat/Rocket.Chat/releases/download/v${RC_VERSION}/rocket.chat.tgz.asc" -o rocket.chat.tgz.asc \
&&  gpg --verify rocket.chat.tgz.asc \
&&  tar zxvf ./rocket.chat.tgz \
&&  rm ./rocket.chat.tgz \
&&  cd /bundle/programs/server \
&&  npm install

WORKDIR /bundle
USER rocketchat

# needs a mongoinstance - defaults to container linking with alias 'db' 
ENV MONGO_URL=mongodb://db:27017/meteor \
    PORT=3000 \
    ROOT_URL=http://localhost:3000

EXPOSE 3000
CMD ["node", "main.js"]

