#!/bin/sh

# GEOIP and GEOSITE files
GEOIP_VER="https://github.com/Loyalsoldier/geoip/releases/download/202112230051"
GEOSITE_VER="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/202112272210"

GEOIP_URL="${GEOIP_VER}/cn.dat"
GEOSITE_URL="${GEOSITE_VER}/geosite.dat"

# Binary and config paths
SRC_NAME="mosdns"
STORAGE_DIR="/etc/storage/$SRC_NAME"
BIN_PATH="/usr/bin/$SRC_NAME"
CONF_PATH="$STORAGE_DIR/$SRC_NAME.conf"
GEOIP_PATH="$STORAGE_DIR/cn.dat"
GEOSITE_PATH="$STORAGE_DIR/geosite.dat"
ARG1=$1
ARG2=$2

func_save(){
/sbin/mtd_storage.sh save
}

func_start(){
if [ ! -d "$STORAGE_DIR" ];then
mkdir -p $STORAGE_DIR
fi
if [ ! -f "$GEOIP_PATH" ];then
curl --retry 5 --connect-timeout 20 -skL -o $GEOIP_PATH $GEOIP_URL && \
logger -t $SRC_NAME "Downloaded GEOIP file from $GEOIP_URL"
fi
if [ ! -f "$GEOSITE_PATH" ];then
curl --retry 5 --connect-timeout 20 -skL -o $GEOSITE_PATH $GEOSITE_URL && \
logger -t $SRC_NAME "Downloaded GEOSITE file from $GEOSITE_URL"
fi
if [ ! -f "$CONF_PATH" ];then
cat > $CONF_PATH <<EOF
log:
  level: error
  file: ""

plugin:
  - tag: server
    type: server
    args:
      entry:
        - custom_hosts
        - mem_cache
        - main_sequence
      server:
        - addr: "[::]:5354"
          protocol: udp
        - addr: "[::]:5354"
          protocol: tcp

  - tag: main_sequence
    type: sequence
    args:
      exec:
        - if:
            - query_is_ad_domain
          exec:
            - _block_with_nxdomain
            - _end

        - if:
            - query_is_cn
          exec:
            - forward_cn
            - _end
          else_exec:
            - forward_catchall
            - _end

  - tag: custom_hosts
    type: hosts
    args:
      hosts:
        - "my.router 192.168.2.1"

  # Cache queries
  - tag: mem_cache
    type: cache
    args:
      size: 1024

  # Use Ali DNS for Chinese websites
  - tag: forward_cn
    type: fast_forward
    args:
      upstream:
        - addr: https://dns.alidns.com/dns-query
          dial_addr: "223.5.5.5:443"

        - addr: tls://223.5.5.5
          idle_timeout: 30
        - addr: tls://223.6.6.6
          idle_timeout: 30

      ca:
        - /etc_ro/cert.pem

  # Use Cloudflare & Google servers for most websites
  - tag: forward_catchall
    type: fast_forward
    args:
      upstream:
        # Cloudflare
        - addr: https://cloudflare-dns.com/dns-query
          dial_addr: "1.1.1.1:443"

        - addr: tls://1.1.1.1
          idle_timeout: 30
        - addr: tls://1.0.0.1
          idle_timeout: 30

        # Google
        - addr: https://dns.google/dns-query
          dial_addr: "8.8.8.8:443"

        - addr: tls://dns.google
          dial_addr: "8.8.8.8:443"
          idle_timeout: 30

      ca:
        - /etc_ro/cert.pem

  # Match CN IP
  - tag: query_is_cn
    type: query_matcher
    args:
      domain:
        - "ext:$GEOSITE_PATH:cn"
      client_ip:
        - "ext:$GEOIP_PATH:cn"

  # Match ad domain
  - tag: query_is_ad_domain
    type: query_matcher
    args:
      domain:
        - "ext:$GEOSITE_PATH:category-ads-all"
EOF
func_save
logger -t $SRC_NAME "Configuration written"
fi
if [ -n "`pidof $SRC_NAME`" ];then
func_stop
logger -t $SRC_NAME "Already running, killed"
fi
$BIN_PATH -c $CONF_PATH &> /dev/null &
logger -t $SRC_NAME "Started"
}

func_stop(){
killall $SRC_NAME
logger -t $SRC_NAME "Killed"
}

func_restart(){
func_stop
func_start
}

func_iptables(){
iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5354
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5354
logger -t $SRC_NAME "iptables setup done."
}

func_ioff(){
iptables -t nat -D PREROUTING `iptables -t nat -L PREROUTING --line-numbers|grep 5354|head -n 1|tr -cd [1-9]|sed "s/5354//g"`
iptables -t nat -D PREROUTING `iptables -t nat -L PREROUTING --line-numbers|grep 5354|head -n 1|tr -cd [1-9]|sed "s/5354//g"`
logger -t $SRC_NAME "iptables cleaned."
}

func_dnsmasq(){
func_doff
cat >> /etc/storage/dnsmasq/dnsmasq.conf << EOF
no-resolv
server=127.0.0.1#5354
EOF
/sbin/restart_dhcpd
logger -t $SRC_NAME "dnsmasq setup done."
}

func_doff(){
sed -i '/no-resolv/d' /etc/storage/dnsmasq/dnsmasq.conf
sed -i '/server=127.0.0.1/d' /etc/storage/dnsmasq/dnsmasq.conf
/sbin/restart_dhcpd
logger -t $SRC_NAME "dnsmasq cleaned."
}

func_setup(){
case $ARG2 in
	"dnsmasq")
		func_dnsmasq
		;;
	"iptables")
		func_iptables
		;;
	*)
		echo "Please specify the setup method"
		;;
esac
}

func_destroy(){
	case $ARG2 in
		"iptables")
			func_ioff
			;;
		"dnsmasq")
			func_doff
			;;
		*)
			echo "Please specify the setup method"
			;;
	esac
}

case $ARG1 in
	"start")
		func_start
		;;
	"stop")
		func_stop
		;;
	"setup")
		func_setup
		;;
	"destroy")
		func_destroy
		func_stop
		;;
	"restart")
		func_restart
		;;
	*)
		echo "Usage: start / stop / setup [mode] / destroy [mode] / restart"
		;;
esac
