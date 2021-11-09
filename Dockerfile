FROM debian:bullseye

LABEL maintainer="Julio Gutierrez"
ARG NORDVPN_VERSION=3.12.0-1

RUN apt update -y && \
    apt upgrade -y && \
    apt install -y curl iputils-ping tzdata ca-certificates wireguard wireguard-tools && \
    curl https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn-release_1.0.0_all.deb --output /tmp/nordrepo.deb && \
    apt install -y /tmp/nordrepo.deb && \
    apt update -y && \
    apt install -y nordvpn${NORDVPN_VERSION:+=$NORDVPN_VERSION} && \
    apt remove -y nordvpn-release && \
    apt autoremove -y && \
    apt autoclean -y && \
    rm -rf \
		/tmp/* \
		/var/cache/apt/archives/* \
		/var/lib/apt/lists/* \
		/var/tmp/* && \
    echo '#!/bin/bash\nservice nordvpn start\nsleep 1\nnordvpn countries' > /usr/bin/countries && \
    echo '#!/bin/bash\nservice nordvpn start\nsleep 1\nnordvpn cities $1' > /usr/bin/cities && \
    echo '#!/bin/bash\nservice nordvpn start\nsleep 1\nnordvpn groups' > /usr/bin/n_groups && \
    chmod +x /usr/bin/countries && \
    chmod +x /usr/bin/cities && \
    chmod +x /usr/bin/n_groups

CMD /usr/bin/start_vpn.sh
COPY start_vpn.sh /usr/bin
