# 节点筛选

## 不同用途，不同标准

### AIGC

AIGC 不只是“能打开网页”就够了，更看重：

1. 出口像不像民用 ISP
2. 稳不稳定
3. 会不会频繁换 IP
4. 延迟和倍率

首页能打开，只能说明没有完全被拦。对 AIGC 来说，这远远不够。

### 默认上网

默认上网更实际，主要看：

1. 吞吐
2. 稳定性
3. 延迟
4. 倍率

视频和日常冲浪，不一定要最“纯”的出口，但一定不能卡。

## 怎么看出口质量

不要只信节点备注。

先测真实出口：

```sh
./scripts/probe-passwall-nodes.sh <host> <node_id_1> <node_id_2>
```

重点看返回里的：

- ISP
- ASN
- 稳定性
- 下载速度

## 哪些出口更适合 AIGC

更像民用 ISP 的出口，一般更适合 AIGC：

- `TELUS`
- `Windstream Communications`
- `Chunghwa Telecom`

这类线路通常更适合长期交互、登录和账号使用。

## 哪些出口更适合默认上网

偏机房或托管网络的出口，不一定差，只是不一定适合 AIGC 主力。

常见的例子：

- `ReliableSite`
- `Akari Networks`
- `SpeedyPage`
- `Kuroit`
- `Nexet`
- `LSHIY`
- `Southeast Asia Telecomsg`

这类线路更适合：

- 默认代理
- 视频
- 流媒体
- 临时备用线

## 实际用法

如果你在一组候选里挑线，顺序可以这样：

### 选 AIGC 主力

先看：

1. ISP / ASN
2. 多轮成功率
3. 首包时间
4. 倍率

### 选默认主力

先看：

1. 下载速度
2. 多轮成功率
3. 首包时间
4. 倍率

如果一条线出口很好看，但稳定性一般，就把它放到 AIGC 备选，不要直接做主力。
