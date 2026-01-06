README.md latter notes

docker run -d \
  --name Rocket.Chat \
  --net br0 \
  --ip 192.168.2.60 \
  --restart unless-stopped \
  -e ROOT_URL="http://192.168.2.60:3000" \
  -e PORT=3000 \
  -v /mnt/user/appdata/rocket.chat/mongodb:/var/lib/mongodb \
  -v /mnt/user/appdata/rocket.chat/uploads:/app/uploads \
  rocketchat-aio:test

usining unraid macvlan/ipvlan custom ip via br0
