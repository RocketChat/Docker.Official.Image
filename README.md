# Rocket.Chat

Rocket.Chat is a Web Chat Server, developed in JavaScript, using the Meteor fullstack framework.

It is a great solution for communities and companies wanting to privately host their own chat service or for developers looking forward to build and evolve their own chat platforms.

%%LOGO%%

# How to use this image
### Docker Compose
For deploying the recomemnd stack with Rocket.Chat, Traefik, Mongodb, Nats and Prometheus for monitoring
```sh
    ./rocketchat.sh
```

Which will run all containers, with Rocket.Chat listening on http://localhost and grafana at http://grafana.localhost
Then, access it via `http://localhost` in a browser.  Replace `localhost` in `ROOT_URL` with your own domain name if you are hosting at your own domain.

Stop the containers with:
```sh
    ./rocketchat.sh down
```

In case you wan't to disable any of the components, they are toggleable using the .env:
```sh
COMPOSE_NATS_ENABLED=y # or n, when disabling nats you should also set to blank with `NATS_URL=`
COMPOSE_TRAEFIK_ENABLED=y # or n
COMPOSE_ROCKETCHAT_ENABLED=y # or n
COMPOSE_MONITORING_ENABLED=y # or n
```


### Individual containers
First, start an instance of mongo:

```sh
    docker run --name db -d mongo:6.0
```

Then start Rocket.Chat linked to this mongo instance:
```sh
    docker run --name rocketchat --link db:db -d rocket.chat
```
This will start a Rocket.Chat instance listening on the default Meteor port of 3000 on the container.

If you'd like to be able to access the instance directly at standard port on the host machine:

```sh
    docker run --name rocketchat -p 80:3000 --env ROOT_URL=http://localhost --link db:db -d rocket.chat
```

Then, access it via `http://localhost` in a browser.  Replace `localhost` in `ROOT_URL` with your own domain name if you are hosting at your own domain.

If you're using a third party Mongo provider, or working with Kubernetes, you need to override the `MONGO_URL` environment variable:
```sh
    docker run --name rocketchat -p 80:3000 --env ROOT_URL=http://localhost --env MONGO_URL=mongodb://mymongourl/mydb -d rocket.chat
```
