# Official Rocket.Chat image

## Supported tags and respective `Dockerfile` links

- [`0.4.0`, `latest` (*Dockerfile*)](https://github.com/RocketChat/Docker.Official.Image/blob/master/Dockerfile)

For more information about this image and its history, please see the [relevant manifest file (`library/Rocket.Chat`)](https://github.com/docker-library/official-images/blob/master/library/Rocket.Chat) in the [`docker-library/official-images` GitHub repo](https://github.com/docker-library/official-images).

## Rocket.Chat

Rocket.Chat is a Web Chat Server, developed in JavaScript, using the Meteor fullstack framework.

It is a great solution for communities and companies wanting to privately host their own chat service or for developers looking forward to build and evolve their own chat platforms.

![Rocket.Chat logo](https://rocket.chat/images/logo/logo-dark.svg?v2)

## How to use this image

First, start an instance of mongo:

    docker run --name db -d mongo mongod --smallfiles

Then start Rocket.Chat linked to this mongo instance:

    docker run --name rocketchat --env ROOT_URL=http://localhost --link db rocket.chat

This will start a Rocket.Chat instance listening on the default Meteor port of 3000.

If you'd like to be able to access the instance from the host without the container's IP, standard port mappings can be used:

    docker run --name rocketchat -p 80:3000 --env ROOT_URL=http://localhost --link db:db -d rocket.chat

Then, access it via `http://localhost:80` or `http://host-ip:80` in a browser.

## User Feedback

### Documentation

Documentation for this image is stored in the [`Rocket.Chat/` directory](https://github.com/docker-library/docs/tree/master/Rocket.Chat) of the [`docker-library/docs` GitHub repo](https://github.com/docker-library/docs). Be sure to familiarize yourself with the [repository's `README.md` file](https://github.com/docker-library/docs/blob/master/README.md) before attempting a pull request.

### Issues

If you have any problems with or questions about this image, please contact us through a [GitHub issue](https://github.com/RocketChat/Docker.Official.Image/issues).

You can also reach many of the official image maintainers via the `#docker-library` IRC channel on [Freenode](https://freenode.net).

### Contributing

You are invited to contribute new features, fixes, or updates, large or small; we are always thrilled to receive pull requests, and do our best to process them as fast as we can.

Before you start to code, we recommend discussing your plans through a [GitHub issue](https://github.com/RocketChat/Docker.Official.Image/issues), especially for more ambitious contributions. This gives other contributors a chance to point you in the right direction, give you feedback on your design, and help you find out if someone else is working on the same thing.

