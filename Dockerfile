FROM node:0.10.39

MAINTAINER pierre@ozoux.net

RUN groupadd -r rocketchat \
&&  useradd -r -g rocketchat rocketchat

# gpg: key 4FD08014: public key "Rocket.Chat Buildmaster <buildmaster@rocket.chat>" imported
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 0E163286C20D07B9787EBE9FD7F9D0414FD08104

ENV RC_VERSION v0.4.0

RUN curl -fSL "https://rocket.chat/dists/$RC_VERSION/rocket.chat-$RC_VERSION.tgz" -o rocket.chat.tgz \
&&  curl -fSL "https://rocket.chat/dists/$RC_VERSION/rocket.chat-$RC_VERSION.tgz.asc" -o rocket.chat.tgz.asc \
&&  gpg --verify rocket.chat.tgz.asc \
&&  tar zxvf ./rocket.chat.tgz \
&&  rm ./rocket.chat.tgz

WORKDIR /app/bundle/programs/server
RUN npm install

WORKDIR /app/bundle
USER rocketchat
ENV MONGO_URL=mongodb://db:27017/meteor
ENV PORT=3000
EXPOSE 3000
CMD ["node", "main.js"]

