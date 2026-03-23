# DNS 与路由排障

## 先看什么

如果你碰到这些情况，先查 DNS 和路由，不要急着换节点：

- 关代理反而更快
- 抖音直播、B 站 feed 卡
- 有些网站明显没走代理
- 同一条线路有时快有时慢

先跑这几条：

```sh
uci -q show passwall.@global[0] | grep -E 'direct_dns|remote_dns|dns_mode|dns_shunt'
sed -n '1,80p' /tmp/etc/passwall/acl/default/chinadns_ng.conf
grep -n 'geosite:douyin\|geosite:bilibili\|outboundTag' /tmp/etc/passwall/acl/default/TCP_SOCKS_DNS.json
ip6tables -t mangle -S
iptables -t mangle -S | grep -nE 'socket|TPROXY|PSW_DIVERT'
```

## 常见问题

### 国内 DNS 跟着上游主路由

这类配置最容易把国内 CDN 调度搞偏。

如果你在 `chinadns_ng.conf` 里看到 `china-dns 192.168.x.x` 这种内网网关地址，先改成固定国内 DNS 试一下：

```sh
uci set passwall.@global[0].direct_dns='223.5.5.5'
uci set passwall.@global[0].direct_dns_mode='udp'
uci commit passwall
/etc/init.d/passwall restart
```

### 规则把国内 App 强制直连

抖音、B 站这类业务经常不只是一个主域名。只要其中一部分规则被强制直连，另一部分走代理，体验就会很怪。

重点看：

```sh
grep -n 'geosite:douyin\|geosite:bilibili\|outboundTag' /tmp/etc/passwall/acl/default/TCP_SOCKS_DNS.json
```

### IPv6 绕过

如果 LAN 在发 IPv6，但代理没完整接住 IPv6，现象通常是：

- 有的请求走 IPv4
- 有的请求走 IPv6
- 表面看像“同一条线路忽快忽慢”

这时先确认：

```sh
ip addr show
uci -q show network.lan
ip6tables -t mangle -S
```

### socket / tproxy 扩展缺失

如果重启 PassWall 报：

```text
Couldn't load match `socket'
```

直接补：

```sh
opkg update
opkg install iptables-mod-socket iptables-mod-tproxy
/etc/init.d/passwall restart
```

然后再看规则有没有真的挂上：

```sh
iptables -t mangle -S | grep -nE 'socket|TPROXY|PSW_DIVERT'
```

## 改完怎么验

不要只看 UCI。

改完之后至少确认这三处：

```sh
sed -n '1,80p' /tmp/etc/passwall/acl/default/chinadns_ng.conf
grep -n 'AIGC:\|default:' /tmp/etc/passwall/acl/default/TCP_SOCKS_DNS.json
iptables -t mangle -S | grep -nE 'socket|TPROXY|PSW_DIVERT'
```
