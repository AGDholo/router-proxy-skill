---
name: router-proxy-skill
description: 通过 SSH 连接家用路由器或旁路由，排查代理系统的安装状态、DNS、透明代理、IPv6 绕过与订阅节点质量，并按 AIGC、默认上网、流媒体等用途筛选和切换节点。用户提到路由器、ttyd、PassWall、PassWall2、OpenWrt、iStoreOS、旁路由、DNS 分流、节点测速、AIGC IP 纯净度、抖音或 B 站卡顿时使用。
---

# Router Proxy Skill

## 适用场景

用这套 skill 处理家用路由器和旁路由上的代理问题，重点是：

- PassWall / PassWall2 有没有装好、跑起来没有
- DNS、分流和透明代理哪里出了问题
- IPv6 有没有绕过代理
- 哪些节点适合 AIGC，哪些更适合日常上网或看视频

## 先连路由器

优先用 SSH。只有 SSH 不通时，再看 `ttyd`。

先查端口：

```sh
nc -vz <host> 22 7681
```

如果 `22` 开着，直接登录：

```sh
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/router_known_hosts root@<host>
```

如果只知道 `ttyd` 端口，先确认它是不是独立终端，不要把 LuCI 配置页当成 shell。

## 先看基线

先把服务状态看清楚，再决定怎么改。

```sh
opkg list-installed | grep -Ei 'passwall|passwall2'
ls /etc/config | grep -i passwall
ls /etc/init.d | grep -i passwall
ps w | grep -i '[p]asswall\|[x]ray\|[s]ing-box\|[c]hinadns-ng\|[d]nsmasq'
uci -q show passwall.@global[0]
```

如果要看订阅节点，直接跑：

```sh
./scripts/list-passwall-nodes.sh <host>
```

## DNS 和分流怎么查

遇到这些现象时，优先看 DNS 和规则：

- 关代理反而更快
- 抖音直播、B 站 feed 卡
- 有些网站明显没走代理
- 切节点后效果飘

先查这几处：

```sh
uci -q show passwall.@global[0] | grep -E 'dns|direct_dns|remote_dns|dns_mode|dns_shunt'
sed -n '1,80p' /tmp/etc/passwall/acl/default/chinadns_ng.conf
grep -n 'geosite:douyin\|geosite:bilibili\|outboundTag' /tmp/etc/passwall/acl/default/TCP_SOCKS_DNS.json
ip6tables -t mangle -S
iptables -t mangle -S | grep -nE 'socket|TPROXY|PSW_DIVERT'
```

判断时抓住这几个点：

- 国内 DNS 如果跟着上游主路由，CDN 调度很容易偏
- `douyin`、`bilibili` 如果被显式打到 `direct`，会直接覆盖默认节点
- LAN 开了 IPv6，但代理没接住 IPv6 时，流量会一部分走代理、一部分绕过
- `socket` 和 `TPROXY` 扩展没装时，透明代理规则会掉

详细做法见 [dns-and-routing-playbook.md](./references/dns-and-routing-playbook.md)。

## 常见修法

### 国内 DNS

如果国内 DNS 跟着上游主路由，先改成固定国内 DNS：

```sh
uci set passwall.@global[0].direct_dns='223.5.5.5'
uci set passwall.@global[0].direct_dns_mode='udp'
uci commit passwall
/etc/init.d/passwall restart
```

### socket / tproxy 扩展

如果重启 PassWall 时看到：

```text
Couldn't load match `socket'
```

直接补装：

```sh
opkg update
opkg install iptables-mod-socket iptables-mod-tproxy
/etc/init.d/passwall restart
```

### IPv6

如果怀疑 IPv6 绕过，就先把它当成排障项来处理：

- 看 LAN 有没有在发 IPv6 前缀
- 看代理有没有完整接住 IPv6
- 没接住的话，先临时关 LAN 的 IPv6 广播做验证

## 节点怎么选

不要把所有用途都塞给一条线。AIGC 和默认上网，标准不一样。

### AIGC

先看：

1. 真实出口 ISP / ASN
2. 稳定性
3. 延迟波动
4. 再看倍率

不要只看节点备注里的“家宽”“原生”。要看它实际从哪家运营商出去。

先列候选，再测：

```sh
./scripts/probe-passwall-nodes.sh <host> <aigc_candidate_1> <aigc_candidate_2> <aigc_candidate_3>
```

### 默认上网

默认节点更看重：

1. 吞吐
2. 稳定性
3. 延迟
4. 倍率

视频、网页和日常冲浪，通常比 AIGC 更在意速度和稳定，不一定非要最“纯”的出口。

更细的判断见 [node-selection-heuristics.md](./references/node-selection-heuristics.md)。

## 切换节点

改配置时只改目标字段，改完立刻重启 `PassWall`，然后看运行中的 JSON 确认有没有真的生效。

### 切 AIGC 节点

```sh
uci set passwall.<shunt_node_id>.AIGC='<node_id>'
uci commit passwall
/etc/init.d/passwall restart
grep -n 'AIGC:' /tmp/etc/passwall/acl/default/TCP_SOCKS_DNS.json
```

### 切默认节点

```sh
uci set passwall.<shunt_node_id>.default_node='<node_id>'
uci commit passwall
/etc/init.d/passwall restart
grep -n 'default:' /tmp/etc/passwall/acl/default/TCP_SOCKS_DNS.json
```

## 脚本

### [list-passwall-nodes.sh](./scripts/list-passwall-nodes.sh)

列出节点 ID、备注、分组、类型、协议、地址和端口，适合先做一轮清点。

### [probe-passwall-nodes.sh](./scripts/probe-passwall-nodes.sh)

对指定节点做统一探测，包括：

- 临时拉起本地 SOCKS
- 查询真实出口 ISP / ASN
- 多轮请求测试稳定性和首包时间
- 小文件下载测试吞吐
