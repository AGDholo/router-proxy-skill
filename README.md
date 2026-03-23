# skill

这是一套用来处理路由器代理问题的中文 skill，适合 OpenWrt、iStoreOS 和旁路由场景。

它主要解决这几类事：

- 连上路由器，确认代理服务是不是正常
- 排查 DNS、分流、IPv6 和透明代理
- 测节点的稳定性、速度和出口 ISP
- 按用途分开选线，比如 AIGC、默认上网、流媒体

仓库里的内容很简单：

- `SKILL.md`：主流程
- `scripts/list-passwall-nodes.sh`：列节点
- `scripts/probe-passwall-nodes.sh`：测节点
- `references/dns-and-routing-playbook.md`：DNS 和路由排障
- `references/node-selection-heuristics.md`：选线标准

如果你的问题是“为什么关代理反而更快”“为什么有些流量没走代理”“AIGC 该选哪条线”，直接从 `SKILL.md` 开始。
