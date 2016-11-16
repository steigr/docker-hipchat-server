# Docker hipchat-server

## Preparation

Go to https://www.hipchat.com/server#get-hipchat-server and discover the OVA-URL.

## Build the image
```
export HIPCHAT_SERVER_OVA_URL=ova-url # see Preparation
export HIPCHAT_SERVER_IMAGE=hipchat-server
export TRACE=1
./build.sh
```

## Start

Check out hipchat-server.service. Optionally create /etc/default/hipchat-server to customize container name and behaviour:

```
HIPCHAT_SERVER_NAME=hipchat-server
HIPCHAT_SERVER_HOSTNAME=hipchat-server.example.com
HIPCHAT_SERVER_NETWORK=bridge
HIPCHAT_SERVER_IMAGE=hipchat-server
HIPCHAT_SERVER_DATA=/var/lib/hipchat
HIPCHAT_SERVER_ID=
HIPCHAT_SERVER_LICENSE=
DOCKER_ARGS=--memory=4GB --cpuset-cpus=0-3
```

# State

This project is a PoC, don't use in production.

# Addtional Information

## Traefik

Set DOCKER_ARGS like this:
```
DOCKER_ARGS=--label=traefik.port=443 --label=traefik.frontend.rule=Host:hipchat-server.example.com --label=traefik.protocol=https
```

Setup (until SSL-Certificate has been applied) must be done directly (e.g. --publish=8443:443). Alternativly use Traefik 1.1 with `InsecureSkipVerify = true`.