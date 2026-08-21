---
name: vpn-relay-setup
description: VPN中转站一键自动部署 - 其他Hermes agent收到用户"搭建VPN"指令后，收集SSH信息自动执行。支持KVM/NAT/IPv6各种服务器。
triggers:
  - VPN搭建
  - 代理服务器
  - 中转站
  - Xray部署
  - V2Ray配置
  - 梯子搭建
  - 科学上网
  - NAT小鸡VPN
  - 搭建vpn
  - 部署代理
---

# VPN中转站一键自动部署

## 🎯 其他Agent执行流程（最简版）

**用户说"帮我搭建VPN"时，Agent执行：**

```
1. 向用户收集：SSH地址、SSH端口、SSH密码、服务器类型(kvm/nat/ipv6)
2. 执行 ssh_deploy_vpn() 函数
3. 将结果（连接信息+导入链接）发送给用户
```

## 📋 Agent收集信息模板

```
收到！我来帮你搭建VPN。请提供以下信息：

1. SSH地址（IP或域名）：
2. SSH端口（默认22）：
3. SSH密码：
4. 服务器类型（kvm/nat/ipv6，默认kvm）：

提供信息后我会自动完成部署。
```

## 🚀 Agent执行脚本（一键版）

用户信息收集完成后，执行以下脚本：

```bash
#!/bin/bash
# 用法: bash vpn_deploy.sh [SSH地址] [SSH端口] [密码] [类型]
# 示例: bash vpn_deploy.sh 1.2.3.4 22 mypassword kvm

set -e

HOST=$1
PORT=${2:-22}
PASS=$3
TYPE=${4:-kvm}

if [ -z "$HOST" ] || [ -z "$PASS" ]; then
    echo "❌ 缺少参数"
    echo "用法: bash vpn_deploy.sh [SSH地址] [SSH端口] [密码] [类型]"
    exit 1
fi

echo "🚀 连接 $HOST:$PORT ..."

sshpass -p "$PASS" ssh -p "$PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@$HOST << 'REMOTE_SCRIPT'
#!/bin/bash
set -e

echo "📦 安装依赖..."
apt update -qq >/dev/null 2>&1
apt install -y curl wget unzip >/dev/null 2>&1

echo "📦 安装Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata >/dev/null 2>&1

# 生成配置
UUID=$(cat /proc/sys/kernel/random/uuid)
XRAY_PORT=443
WS_PATH="/$(openssl rand -hex 8)"
SERVER_IP=$(curl -s http://ip.sb 2>/dev/null || curl -s http://ifconfig.me)

echo "⚙️ 写入配置..."
mkdir -p /usr/local/etc/xray
cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "port": $XRAY_PORT,
    "protocol": "vmess",
    "settings": {"clients": [{"id": "$UUID", "alterId": 0}]},
    "streamSettings": {"network": "ws", "wsSettings": {"path": "$WS_PATH"}},
    "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

echo "🔄 启动Xray..."
systemctl restart xray
systemctl enable xray >/dev/null 2>&1

# 验证
if systemctl is-active --quiet xray; then
    echo ""
    echo "===DEPLOY_OK==="
    echo "SERVER=$SERVER_IP"
    echo "PORT=$XRAY_PORT"
    echo "UUID=$UUID"
    echo "PATH=$WS_PATH"
    echo "===END==="
else
    echo "===DEPLOY_FAIL==="
    echo "ERROR=Xray启动失败"
    echo "LOG=$(journalctl -u xray -n 10 --no-pager 2>&1)"
    echo "===END==="
fi
REMOTE_SCRIPT

echo "✅ 远程部署完成"
```

## 📱 Agent生成客户端配置

部署成功后，Agent自动输出：

### V2RayNG导入链接
```
vmess://BASE64编码
```

生成方法：
```bash
# 替换为实际值
SERVER="x.x.x.x"
PORT="443"
UUID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
PATH="/xxxxxxxx"

# 生成链接
echo -n "{\"v\":\"2\",\"ps\":\"VPN节点\",\"add\":\"$SERVER\",\"port\":\"$PORT\",\"id\":\"$UUID\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"$PATH\",\"tls\":\"\"}" | base64 -w0 | xargs -I {} echo "vmess://{}"
```

### Clash Meta配置
```yaml
mixed-port: 7890
allow-lan: true
mode: rule
proxies:
  - name: VPN节点
    type: vmess
    server: SERVER_IP
    port: 443
    uuid: UUID
    alterId: 0
    cipher: auto
    udp: true
    network: ws
    ws-opts:
      path: "/PATH"
proxy-groups:
  - name: 节点选择
    type: select
    proxies:
      - VPN节点
      - DIRECT
rules:
  - MATCH,节点选择
```

## 🎯 Agent完整执行流程（Python版）

```python
def handle_vpn_request(user_message):
    """Agent收到VPN搭建请求后的完整处理流程"""
    
    # 1. 收集信息
    ssh_info = {
        "host": ask_user("SSH地址："),
        "port": ask_user("SSH端口[22]：") or "22",
        "password": ask_user("SSH密码："),
        "type": ask_user("服务器类型(kvm/nat/ipv6)[kvm]：") or "kvm"
    }
    
    # 2. 执行部署
    result = execute_deploy(ssh_info)
    
    # 3. 解析结果
    if "DEPLOY_OK" in result:
        config = parse_config(result)
        
        # 4. 生成客户端配置
        vmess_link = generate_vmess_link(config)
        clash_config = generate_clash_config(config)
        
        # 5. 发送给用户
        send_to_user(f"""
✅ VPN部署成功！

📋 连接信息：
服务器：{config['server']}
端口：{config['port']}
UUID：{config['uuid']}
传输：ws
路径：{config['path']}

📱 V2RayNG导入链接：
{vmess_link}

💻 Clash配置：
{clash_config}
        """)
    else:
        send_to_user(f"❌ 部署失败：{result}")
```

## 📋 Agent自动响应模板

### 场景1：用户说"帮我搭建VPN"
```
好的，我来帮你搭建VPN。请提供：
1. SSH地址：
2. SSH端口（默认22）：
3. SSH密码：
4. 服务器类型（kvm/nat/ipv6，默认kvm）：
```

### 场景2：用户提供了信息
```
收到，开始部署...

[执行部署脚本]

✅ 部署成功！

服务器：x.x.x.x
端口：443
UUID：xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
路径：/xxxxxxxx

📱 导入链接：
vmess://xxxxxxxx

请导入即可使用。
```

### 场景3：部署失败
```
❌ 部署失败

可能原因：
1. SSH信息错误
2. 服务器无法访问外网
3. 端口被占用

请检查后重试。
```

## ⚠️ NAT小鸡特殊处理

如果服务器类型是 `nat`，需要额外处理：

1. **端口映射**：NAT小鸡的端口需要映射才能外网访问
2. **确认映射关系**：问用户商家面板里的端口映射规则
3. **修改端口号**：如果443被映射到其他端口，配置中要改

```bash
# NAT小鸡示例：外部端口20039映射到内部443
XRAY_PORT=443  # 内部监听端口
# 客户端连接时用外部端口20039
```

## ⚠️ 1GB硬盘小鸡处理

如果硬盘只有1GB：
```bash
# 清理空间
apt purge -y exim4* socat 2>/dev/null
apt autoremove -y && apt clean

# 安装轻量Xray（不带geo数据）
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata
```

## ⚠️ IPv6-only VPS处理

如果服务器只有IPv6：
```bash
# 先装WARP获取IPv4出口
wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh
bash menu.sh
# 选选项4
```

## 📌 Agent执行检查清单

- [ ] 收集SSH信息（地址、端口、密码、类型）
- [ ] 测试SSH连接
- [ ] 执行部署脚本
- [ ] 验证Xray状态
- [ ] 生成vmess链接
- [ ] 生成clash配置
- [ ] 发送配置给用户

## 🔧 故障排查

| 问题 | 原因 | 解决 |
|------|------|------|
| SSH连不上 | 端口/密码错 | 检查信息 |
| Xray启动失败 | 端口占用 | 换端口 |
| 能连不能上网 | DNS问题 | 不影响，客户端会处理 |
| 速度慢 | 线路差 | 换地区 |

## 📌 关键提醒

1. **NAT小鸡**：必须确认端口映射
2. **1GB硬盘**：加 `--without-geodata`
3. **IPv6-only**：先装WARP
4. **共享IP**：注意邻居风险