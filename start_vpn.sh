#!/bin/bash
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
iptables-legacy -P OUTPUT DROP
iptables-legacy -P INPUT DROP
iptables-legacy -P FORWARD DROP
ip6tables-legacy -P OUTPUT DROP 2>/dev/null
ip6tables-legacy -P INPUT DROP 2>/dev/null
ip6tables-legacy -P FORWARD DROP 2>/dev/null
iptables-legacy -F
iptables-legacy -X
ip6tables-legacy -F 2>/dev/null
ip6tables-legacy -X 2>/dev/null

[[ "${DEBUG,,}" == trace* ]] && set -x

if [ "$(cat /etc/timezone)" != "${TZ}" ]; then
  if [ -d "/usr/share/zoneinfo/${TZ}" ] || [ ! -e "/usr/share/zoneinfo/${TZ}" ] || [ -z "${TZ}" ]; then
    TZ="Etc/UTC"
  fi
  ln -fs "/usr/share/zoneinfo/${TZ}" /etc/localtime
  dpkg-reconfigure -f noninteractive tzdata 2>/dev/null
fi

echo "[$(date -Iseconds)] Firewall is up, everything has to go through the vpn"
docker_network="$(ip -o addr show dev eth0 | awk '$3 == "inet" {print $4}')"
docker6_network="$(ip -o addr show dev eth0 | awk '$3 == "inet6" {print $4; exit}')"

echo "[$(date -Iseconds)] Enabling connection to secure interfaces"
if [[ -n ${docker_network} ]]; then
  iptables-legacy -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables-legacy -A INPUT -i lo -j ACCEPT
  iptables-legacy -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables-legacy -A FORWARD -i lo -j ACCEPT
  iptables-legacy -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables-legacy -A OUTPUT -o lo -j ACCEPT
  iptables-legacy -A OUTPUT -o tap+ -j ACCEPT
  iptables-legacy -A OUTPUT -o tun+ -j ACCEPT
  iptables-legacy -A OUTPUT -o nordlynx+ -j ACCEPT
  iptables-legacy -t nat -A POSTROUTING -o tap+ -j MASQUERADE
  iptables-legacy -t nat -A POSTROUTING -o tun+ -j MASQUERADE
  iptables-legacy -t nat -A POSTROUTING -o nordlynx+ -j MASQUERADE
fi
if [[ -n ${docker6_network} ]]; then
  ip6tables-legacy -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ip6tables-legacy -A INPUT -p icmp -j ACCEPT
  ip6tables-legacy -A INPUT -i lo -j ACCEPT
  ip6tables-legacy -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ip6tables-legacy -A FORWARD -p icmp -j ACCEPT
  ip6tables-legacy -A FORWARD -i lo -j ACCEPT
  ip6tables-legacy -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ip6tables-legacy -A OUTPUT -o lo -j ACCEPT
  ip6tables-legacy -A OUTPUT -o tap+ -j ACCEPT
  ip6tables-legacy -A OUTPUT -o tun+ -j ACCEPT
  ip6tables-legacy -A OUTPUT -o nordlynx+ -j ACCEPT
  ip6tables-legacy -t nat -A POSTROUTING -o tap+ -j MASQUERADE
  ip6tables-legacy -t nat -A POSTROUTING -o tun+ -j MASQUERADE
  ip6tables-legacy -t nat -A POSTROUTING -o nordlynx+ -j MASQUERADE
fi

echo "[$(date -Iseconds)] Enabling connection to nordvpn group"
if [[ -n ${docker_network} ]]; then
  iptables-legacy -A OUTPUT -m owner --gid-owner nordvpn -j ACCEPT || {
    echo "[$(date -Iseconds)] group match failed, fallback to open necessary ports"
    iptables-legacy -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
    iptables-legacy -A OUTPUT -p udp -m udp --dport 51820 -j ACCEPT
    iptables-legacy -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT
    iptables-legacy -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT
    iptables-legacy -A OUTPUT -p tcp -m tcp --dport 443 -j ACCEPT
  }
fi
if [[ -n ${docker6_network} ]]; then
  ip6tables-legacy -A OUTPUT -m owner --gid-owner nordvpn -j ACCEPT || {
    echo "[$(date -Iseconds)] ip6 group match failed, fallback to open necessary ports"
    ip6tables-legacy -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
    ip6tables-legacy -A OUTPUT -p udp -m udp --dport 51820 -j ACCEPT
    ip6tables-legacy -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT
    ip6tables-legacy -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT
    ip6tables-legacy -A OUTPUT -p tcp -m tcp --dport 443 -j ACCEPT
  }
fi

echo "[$(date -Iseconds)] Enabling connection to docker network"
if [[ -n ${docker_network} ]]; then
  iptables-legacy -A INPUT -s "${docker_network}" -j ACCEPT
  iptables-legacy -A FORWARD -d "${docker_network}" -j ACCEPT
  iptables-legacy -A FORWARD -s "${docker_network}" -j ACCEPT
  iptables-legacy -A OUTPUT -d "${docker_network}" -j ACCEPT
fi
if [[ -n ${docker6_network} ]]; then
  ip6tables-legacy -A INPUT -s "${docker6_network}" -j ACCEPT 2>/dev/null
  ip6tables-legacy -A FORWARD -d "${docker6_network}" -j ACCEPT 2>/dev/null
  ip6tables-legacy -A FORWARD -s "${docker6_network}" -j ACCEPT 2>/dev/null
  ip6tables-legacy -A OUTPUT -d "${docker6_network}" -j ACCEPT 2>/dev/null
fi

if [[ -n ${docker_network} && -n ${NETWORK} ]]; then
  gw=$(ip route | awk '/default/ {print $3}')
  for net in ${NETWORK//[;,]/ }; do
    echo "[$(date -Iseconds)] Enabling connection to network ${net}"
    ip route | grep -q "$net" || ip route add to "$net" via "$gw" dev eth0
    iptables-legacy -A INPUT -s "$net" -j ACCEPT
    iptables-legacy -A FORWARD -d "$net" -j ACCEPT
    iptables-legacy -A FORWARD -s "$net" -j ACCEPT
    iptables-legacy -A OUTPUT -d "$net" -j ACCEPT
  done
fi
if [[ -n ${docker6_network} && -n ${NETWORK6} ]]; then
  gw6=$(ip -6 route | awk '/default/{print $3}')
  for net6 in ${NETWORK6//[;,]/ }; do
    echo "[$(date -Iseconds)] Enabling connection to network ${net6}"
    ip -6 route | grep -q "$net6" || ip -6 route add to "$net6" via "$gw6" dev eth0
    ip6tables-legacy -A INPUT -s "$net6" -j ACCEPT
    ip6tables-legacy -A FORWARD -d "$net6" -j ACCEPT
    ip6tables-legacy -A FORWARD -s "$net6" -j ACCEPT
    ip6tables-legacy -A OUTPUT -d "$net6" -j ACCEPT
  done
fi

if [[ -n ${WHITELIST} ]]; then
  for domain in ${WHITELIST//[;,]/ }; do
    domain=$(echo "$domain" | sed 's/^.*:\/\///;s/\/.*$//')
    echo "[$(date -Iseconds)] Enabling connection to host ${domain}"
    if [[ -n ${docker_network} ]]; then
      sg nordvpn -c "iptables-legacy -A OUTPUT -o eth0 -d ${domain} -j ACCEPT"
    fi
    if [[ -n ${docker6_network} ]]; then
      sg nordvpn -c "ip6tables-legacy -A OUTPUT -o eth0 -d ${domain} -j ACCEPT 2>/dev/null"
    fi
  done
fi

echo "Bypass requests to NordVPN API thru regular connection"
if [[ -n ${docker_network} ]]; then
  sg nordvpn -c "iptables-legacy -A OUTPUT -o eth0 -d "api.nordvpn.com" -j ACCEPT"
fi
if [[ -n ${docker6_network} ]]; then
  sg nordvpn -c "ip6tables-legacy -A OUTPUT -o eth0 -d "api.nordvpn.com" -j ACCEPT 2> /dev/null"
fi

mkdir -p /dev/net
[[ -c /dev/net/tun ]] || mknod -m 0666 /dev/net/tun c 10 200

restart_daemon() {
  echo "[$(date -Iseconds)] Restarting the service"
  service nordvpn stop
  sleep 0.2
  # TODO: maybe remove this
  if [[ "${DEBUG,,}" == trace* ]]; then
    ls -la /run/nordvpn/
    ps -ef
    sysctl net.ipv4.conf.all.rp_filter
  fi
  rm -rf /run/nordvpn/nordvpnd.sock
  service nordvpn start

  echo "[$(date -Iseconds)] Waiting for the service to start"
  attempt_counter=0
  max_attempts=50
  until [ -S /run/nordvpn/nordvpnd.sock ]; do
    if [ ${attempt_counter} -eq ${max_attempts} ]; then
      echo "[$(date -Iseconds)] Max attempts reached"
      exit 1
    fi
    attempt_counter=$((attempt_counter + 1))
    sleep 0.2
  done
  [[ "${DEBUG,,}" == trace+* ]] && nordvpn settings
}
restart_daemon

echo "[$(date -Iseconds)] Pre-logging settings $(nordvpn -version)"
[[ -n ${DNS} ]] && nordvpn set dns ${DNS//[;,]/ }
[[ -n ${CYBER_SEC} ]] && nordvpn set cybersec ${CYBER_SEC}
[[ -n ${OBFUSCATE} ]] && nordvpn set obfuscate ${OBFUSCATE} && sleep 3

if [[ "${DEBUG,,}" == trace+* ]]; then
  echo "[$(date -Iseconds)] ############# WARNING ############### make sure to remove user/pass before sharing this log"
else
  set +x
  [[ "${DEBUG,,}" == trace* ]] && echo "[$(date -Iseconds)] Hiding user/password from the logs, set DEBUG=trace+ if you want to show them in the logs"
fi
[[ -z "${PASS}" ]] && [[ -f "${PASSFILE}" ]] && PASS="$(head -n 1 "${PASSFILE}")"
echo "[$(date -Iseconds)] Logging in"
nordvpn logout >/dev/null
nordvpn login --username "${USER}" --password "${PASS}" || {
  echo "[$(date -Iseconds)] Invalid Username or password."
  exit 1
}
[[ "${DEBUG,,}" == trace* ]] && set -x

echo "[$(date -Iseconds)] Post-logging settings $(nordvpn -version)"
[[ -n ${FIREWALL} ]] && nordvpn set firewall ${FIREWALL}
[[ -n ${KILLSWITCH} ]] && nordvpn set killswitch ${KILLSWITCH}
[[ -n ${PROTOCOL} ]] && nordvpn set protocol ${PROTOCOL}
[[ -n ${TECHNOLOGY} ]] && nordvpn set technology ${TECHNOLOGY}

if [[ -n ${docker_network} ]]; then
  nordvpn whitelist add subnet ${docker_network}
  [[ -n ${NETWORK} ]] && for net in ${NETWORK//[;,]/ }; do nordvpn whitelist add subnet "${net}"; done
fi
if [[ -n ${docker6_network} ]]; then
  nordvpn set ipv6 on
  nordvpn whitelist add subnet ${docker6_network}
  [[ -n ${NETWORK6} ]] && for net in ${NETWORK6//[;,]/ }; do nordvpn whitelist add subnet "${net}"; done
fi
[[ -n ${PORTS} ]] && for port in ${PORTS//[;,]/ }; do nordvpn whitelist add port "${port}"; done
[[ -n ${PORT_RANGE} ]] && nordvpn whitelist add ports ${PORT_RANGE}
[[ -n ${DEBUG} ]] && nordvpn settings

connect() {
  echo "[$(date -Iseconds)] Connecting..."
  current_sleep=1
  until nordvpn connect ${CONNECT}; do
    if [ ${current_sleep} -gt 4096 ]; then
      echo "[$(date -Iseconds)] Unable to connect."
      tail -n 200 /var/log/nordvpn/daemon.log
      exit 1
    fi
    echo "[$(date -Iseconds)] Unable to connect retrying in ${current_sleep} seconds."
    sleep ${current_sleep}
    current_sleep=$((current_sleep * 2))
  done
  if [[ ! -z "${POST_CONNECT}" ]]; then
    eval ${POST_CONNECT}
  fi
}
connect
[[ -n ${DEBUG} ]] && tail -n 1 -f /var/log/nordvpn/daemon.log &

cleanup() {
  nordvpn status
  nordvpn disconnect
  nordvpn logout
  service nordvpn stop
  trap - SIGTERM SIGINT EXIT # https://bash.cyberciti.biz/guide/How_to_clear_trap
  exit 0
}
trap cleanup SIGTERM SIGINT EXIT # https://www.ctl.io/developers/blog/post/gracefully-stopping-docker-containers/

[[ -n ${RECONNECT} && -z ${CHECK_CONNECTION_INTERVAL} ]] && CHECK_CONNECTION_INTERVAL=${RECONNECT}
while true; do
  sleep "${CHECK_CONNECTION_INTERVAL:-300}"
  attempt_counter=0
  max_attempts="${CHECK_CONNECTION_ATTEMPTS:-5}"
  until [[ $(curl -Is -m "${CHECK_CONNECTION_TIMEOUT:-30}" -o /dev/null -w "%{http_code}" "${CHECK_CONNECTION_URL:-www.google.com}") =~ ^[23] ]]; do
    if [ ${attempt_counter} -ge ${max_attempts} ]; then
      echo "[$(date -Iseconds)] Unstable connection detected!"
      nordvpn status
      case "${CHECK_CONNECTION_FAILURE_ACTION:-"restart"}" in
        "restart")
          restart_daemon
          connect
          ;;
        "reconnect")
          # Possible fix for issue: https://forum.manjaro.org/t/nordvpn-bin-breaks-every-4-hours/80927/22
          # SERVER=$(nordvpn status | grep -o "[a-z]\{2\}[0-9]\+")
          # nordvpn c "${SERVER}"
          connect
          ;;
        "log")
          # Already logged above, so just keep looping. Useful for diagnosing an issue when you don't want the service restarted.
          ;;
        *)
          echo "Invalid option for CHECK_CONNECTION_FAILURE_ACTION: ${CHECK_CONNECTION_FAILURE_ACTION}"
          exit 1
          ;;
      esac
    fi
    attempt_counter=$((attempt_counter + 1))
    sleep "${CHECK_CONNECTION_RETRY_INTERVAL:-15}"
  done
done
