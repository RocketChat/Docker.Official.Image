# Rocket.Chat AIO (All-In-One)

This repository provides an **all-in-one Docker image for Rocket.Chat** that bundles:

- Rocket.Chat (latest stable build)
- MongoDB Community Edition v7 (single-node replica set)
- Node.js v22 (supported by Rocket.Chat 7.x)

No external MongoDB container is required.

---

## Docker Hub

**Image:**  
https://hub.docker.com/r/bmmbmm01/rocketchat-aio

---

## Quick Start

### Minimal `docker run` (bridge mode)

```bash
docker run -d \
  --name rocketchat \
  --restart unless-stopped \
  -e ROOT_URL="http://localhost:3000" \
  -e PORT=3000 \
  -p 3000:3000 \
  -v /mnt/user/appdata/rocket.chat/uploads:/app/uploads \
  -v /mnt/user/appdata/rocket.chat/mongodb:/var/lib/mongodb \
  bmmbmm01/rocketchat-aio:latest
```

Then Open: http://localhost:3000
You will be greeted by the Rocket.Chat setup wizard.

## What This Image Does:

- Uses the latest Rocket.Chat release
- Runs MongoDB CE v7 locally inside the container
- Automatically initializes a MongoDB replica set (rs01)
- Starts Rocket.Chat only after MongoDB is ready
- Uses a custom entrypoint to ensure correct startup order
- Fully compatible with Unraid, Docker bridge, and macvlan/ipvlan

## Example Runtime Output
```text
+--------------------------------------------------+
|                  SERVER RUNNING                  |
+--------------------------------------------------+
|                                                  |
|  Rocket.Chat Version: 7.13.2                     |
|       NodeJS Version: 22.21.0 - x64              |
|      MongoDB Version: 7.0.28                     |
|       MongoDB Engine: wiredTiger                 |
|             Platform: linux                      |
|         Process Port: 3000                       |
|             Site URL: http://192.168.2.248:3000  |
|     ReplicaSet OpLog: Enabled                    |
|          Commit Hash: 72fe118ea7                 |
|        Commit Branch: HEAD                       |
|                                                  |
+--------------------------------------------------+
```
