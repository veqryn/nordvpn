<p align="center">
    <a href="https://nordvpn.com/"><img src="https://github.com/bubuntux/nordvpn/raw/master/.img/NordVpn_logo.png"/></a>
    </br>
    <a href="https://github.com/bubuntux/nordvpn/blob/master/LICENSE"><img src="https://badgen.net/github/license/bubuntux/nordvpn?color=cyan"/></a>
    <a href="https://cloud.docker.com/u/bubuntux/repository/docker/bubuntux/nordvpn"><img src="https://badgen.net/docker/size/bubuntux/nordvpn?icon=docker&label=size"/></a>
    <a href="https://cloud.docker.com/u/bubuntux/repository/docker/bubuntux/nordvpn"><img src="https://badgen.net/docker/pulls/bubuntux/nordvpn?icon=docker&label=pulls"/></a>
    <a href="https://cloud.docker.com/u/bubuntux/repository/docker/bubuntux/nordvpn"><img src="https://badgen.net/docker/stars/bubuntux/nordvpn?icon=docker&label=stars"/></a>
    <a href="https://github.com/bubuntux/nordvpn"><img src="https://badgen.net/github/forks/bubuntux/nordvpn?icon=github&label=forks&color=black"/></a>
    <a href="https://github.com/bubuntux/nordvpn"><img src="https://badgen.net/github/stars/bubuntux/nordvpn?icon=github&label=stars&color=black"/></a>
    <a href="https://github.com/bubuntux/nordvpn/actions?query=workflow%3Arelease"><img src="https://github.com/bubuntux/nordvpn/workflows/release/badge.svg"/></a>
</p>

Official `NordVPN` client in a docker container; it makes routing traffic through the `NordVPN` network easy.

# How to use this image
This container was designed to be started first to provide a connection to other containers (using `--net=container:vpn`, see below *Starting an NordVPN client instance*).

**NOTE**: More than the basic privileges are needed for NordVPN. With docker 1.2 or newer you can use the `--cap-add=NET_ADMIN` option. Earlier versions, or with fig, and you'll have to run it in privileged mode.

## Starting an NordVPN instance
    docker run -ti --cap-add=NET_ADMIN --name vpn \
               -e USER=user@email.com -e PASS='pas$word' \
               -e TECHNOLOGY=NordLynx -d ghcr.io/bubuntux/nordvpn

Once it's up other containers can be started using its network connection:

    docker run -it --net=container:vpn -d some/docker-container

## docker-compose example
```
version: "3"
services:
  vpn:
    image: ghcr.io/bubuntux/nordvpn
    cap_add:
      - NET_ADMIN               # Required
    environment:                # Review https://github.com/bubuntux/nordvpn#environment-variables
      - USER=user@email.com     # Required
      - "PASS=pas$word"         # Required
      - CONNECT=United_States
      - TECHNOLOGY=NordLynx
      - NETWORK=192.168.1.0/24  # So it can be accessed within the local network
    ports:
      - 8080:8080
  torrent:
    image: ghcr.io/linuxserver/qbittorrent
    network_mode: service:vpn
    depends_on:
      - vpn
      
# The torrent service would be available at http://localhost:8080/ 
# or anywhere inside of the local network http://192.168.1.xxx:8080
 ```

## docker-compose example using reverse proxy
```
version: "3"
services:
  proxy:
    image: traefik:v2.4         # Review traefik documentation https://doc.traefik.io/traefik/ 
    container_name: traefik
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
    ports:
      - 80:80
      - 8080:8080
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
  vpn:
    image: ghcr.io/bubuntux/nordvpn
    cap_add:
      - NET_ADMIN               # Required
    environment:                # Review https://github.com/bubuntux/nordvpn#environment-variables
      - USER=user@email.com     # Required
      - "PASS=pas$word"         # Required
      - CONNECT=United_States
      - TECHNOLOGY=NordLynx
  torrent:
    image: ghcr.io/linuxserver/qbittorrent
    network_mode: service:vpn
    labels:
      - traefik.enable=true
      - traefik.http.services.torrent.loadbalancer.server.port=8080
      - traefik.http.routers.torrent.rule=Host(`custom-host`)
    depends_on:
      - vpn
      
# Make sure that custom-host resolves to the ip address of the server 
# for example /etc/hosts contains 127.0.0.1  custom-host
# the torrent service would be available at http://custom-host
```

## docker-compose example using reverse proxy with TLS
```
version: "3"
services:
  proxy:
    image: traefik:v2.4             # Review traefik documentation https://doc.traefik.io/traefik/ 
    container_name: traefik
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.websecure.address=:443
      - --entrypoints.websecure.http.tls.certresolver=letsencrypt
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.email=my@email.com # Replace with your email
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
    ports:
      - 80:80
      - 443:443
      - 8080:8080
    volumes:
      - ./letsencrypt:/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
  domain:
    image: ghcr.io/linuxserver/duckdns   # Review doc https://github.com/linuxserver/docker-duckdns
    container_name: duckdns
    environment:
      - TOKEN=ABCDFEG                    # Required
      - SUBDOMAINS=domain1,domain2       # Required
    restart: unless-stopped
  media:
    image: ghcr.io/linuxserver/plex
    container_name: plex
    labels:
      - traefik.enable=true
      - traefik.http.services.media.loadbalancer.server.port=32400
      - traefik.http.routers.media.rule=Host(`myplex.duckdns.org`)   # Replace with your domain
    devices:
      - /dev/dri:/dev/dri
    restart: unless-stopped
  vpn:
    image: ghcr.io/bubuntux/nordvpn
    container_name: nordvpn
    cap_add:
      - NET_ADMIN               # Required
    environment:                # Review https://github.com/bubuntux/nordvpn#environment-variables
      - USER=user@email.com     # Required
      - "PASS=pas$word"         # Required
      - CONNECT=United_States
      - TECHNOLOGY=NordLynx
      - WHITELIST=showrss.info,rarbg.to,yts.mx
  torrent:
    image: ghcr.io/linuxserver/qbittorrent
    container_name: qbittorrent
    network_mode: service:vpn
    depends_on:
      - vpn
    labels:
      - traefik.enable=true
      - traefik.http.services.torrent.loadbalancer.server.port=8080
      - traefik.http.routers.torrent.rule=Host(`mytorrent.duckdns.org`) # Replace with your domain
    restart: unless-stopped
    
# Make sure that you can access your server from the internet
# for example configure dmz on your router
# the torrent service would be available at https://mytorrent.duckdns.org
```

# ENVIRONMENT VARIABLES

* `USER`     - User for NordVPN account.
* `PASS`     - Password for NordVPN account, surrounding the password in single quotes will prevent issues with special characters such as `$`.
* `PASSFILE` - File from which to get `PASS`, if using [docker secrets](https://docs.docker.com/compose/compose-file/compose-file-v3/#secrets) this should be set to `/run/secrets/<secret_name>`. This file should contain just the account password on the first line.
* `CONNECT`  -  [country]/[server]/[country_code]/[city]/[group] or [country] [city], if none provide you will connect to  the recommended server.
   - Provide a [country] argument to connect to a specific country. For example: Australia , Use `docker run --rm ghcr.io/bubuntux/nordvpn countries` to get the list of countries.
   - Provide a [server] argument to connect to a specific server. For example: jp35 , [Full List](https://nordvpn.com/servers/tools/)
   - Provide a [country_code] argument to connect to a specific country. For example: us 
   - Provide a [city] argument to connect to a specific city. For example: 'Hungary Budapest' , Use `docker run --rm ghcr.io/bubuntux/nordvpn cities [country]` to get the list of cities. 
   - Provide a [group] argument to connect to a specific servers group. For example: P2P , Use `docker run --rm ghcr.io/bubuntux/nordvpn n_groups` to get the full list.
   - --group value  Specify a server group to connect to. For example: '--group p2p us'
* `POST_CONNECT` - Command to execute after successful connection.
* `CYBER_SEC`  - Enable or Disable. When enabled, the CyberSec feature will automatically block suspicious websites so that no malware or other cyber threats can infect your device. Additionally, no flashy ads will come into your sight. More information on how it works: https://nordvpn.com/features/cybersec/.
* `DNS` -   Can set up to 3 DNS servers. For example 1.1.1.1,8.8.8.8 or Disable, Setting DNS disables CyberSec.
* `FIREWALL`  - Enable or Disable.
* `KILLSWITCH`  - Enable or Disable. (Enabled by default using iptables) This security feature blocks your device from accessing the Internet while not connected to the VPN or in case connection with a VPN server is lost.
* `OBFUSCATE`  - Enable or Disable. When enabled, this feature allows to bypass network traffic sensors which aim to detect usage of the protocol and log, throttle or block it (only valid when using OpenVpn).
* `PROTOCOL`   - TCP or UDP (only valid when using OpenVPN).
* `TECHNOLOGY` - Specify Technology to use: 
   * OpenVPN    - Traditional connection.
   * NordLynx   - NordVpn wireguard implementation (3x-5x times faster).
* `WHITELIST` - List of domains that are going to be accessible _outside_ vpn (IE rarbg.to,yts.mx).
* `NETWORK`  - CIDR networks (IE 192.168.1.0/24), add a route to allows replies once the VPN is up.
* `NETWORK6` - CIDR IPv6 networks (IE fe00:d34d:b33f::/64), add a route to allows replies once the VPN is up.
* `PORTS`  - Semicolon delimited list of ports to whitelist for both UDP and TCP. For example '- PORTS=9091;9095'
* `PORT_RANGE`  - Port range to whitelist for both UDP and TCP. For example '- PORT_RANGE=9091 9095'
* `CHECK_CONNECTION_INTERVAL`  - Time in seconds to check connection and reconnect if need it. (300 by default) For example '- CHECK_CONNECTION_INTERVAL=600'
* `CHECK_CONNECTION_RETRY_INTERVAL`  - Time in seconds to sleep between connection retries. (15 by default) For example '- CHECK_CONNECTION_RETRY_INTERVAL=60'
* `CHECK_CONNECTION_ATTEMPTS`  - Number of connection attempts to make. (5 by default) For example '- CHECK_CONNECTION_ATTEMPTS=10'
* `CHECK_CONNECTION_TIMEOUT`  - Time in seconds before connection attempt is timed out. (30 by default) For example '- CHECK_CONNECTION_TIMEOUT=60'
* `CHECK_CONNECTION_URL`  - URL for checking Internet connection. (www.google.com by default) For example '- CHECK_CONNECTION_URL=www.custom.domain'
* `CHECK_CONNECTION_FAILURE_ACTION`  - Action to take after connection attempts have been exceeded. Values can be `restart`, `reconnect`, or `log`. (restart by default) For example '- CHECK_CONNECTION_FAILURE_ACTION=log'
* `TZ`  - Specify a timezone to use. For example  '- TZ=Europe/London'
* `DEBUG`  - info, trace or trace+. Set to 'trace' for troubleshooting, 'trace+' will log your User and Pass.

# Issues

If you have any problems with or questions about this image, please contact me through a [GitHub issue](https://github.com/bubuntux/nordvpn/issues).

# Disclaimer 
This project is independently developed for personal use, there is no affiliation with NordVpn or Nord Security companies,
Nord Security companies are not responsible for and have no control over the nature, content and availability of this project.