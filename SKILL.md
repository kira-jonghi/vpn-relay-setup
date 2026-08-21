---
name: vpn-relay-setup
description: VPN中转站搭建完整指南 - 从零开始部署Xray/V2Ray代理服务器，覆盖KVM、NAT小鸡、IPv6-only等各种环境，包含常见问题排查和客户端配置。
triggers:
  - VPN搭建
  - 代理服务器
  - 中转站
  - Xray部署
  - V2Ray配置
  - 梯子搭建
  - 科学上网
  - NAT小鸡VPN
  - 住宅IP中转
---

# VPN中转站搭建完整指南

## 核心概念

### 什么是VPN中转站？
VPN中转站是在VPS上部署代理服务器，将客户端流量通过VPS中转，实现：
- **隐私保护**：隐藏真实IP
- **访问限制内容**：绕过地理限制
- **固定IP出口**：通过住宅代理实现固定IP

### 架构图
```
客户端(手机/电脑)
  → 中转VPS(Xray代理服务器)
    → 目标网站(显示VPS IP或住宅IP)
```

## 服务器选择指南

### 1. KVM VPS（推荐）
- **优点**：完整root权限、TUN设备可用、支持所有协议
- **配置**：1核CPU、1GB内存、20GB硬盘足够
- **推荐地区**：香港（低延迟）、日本、新加坡
- **价格**：¥30-100/月

### 2. NAT小鸡（省钱选择）
- **优点**：超低价（¥5-10/月）
- **缺点**：共享IP、端口受限、性能有限
- **适用场景**：个人使用、预算有限
- **必备条件**：KVM虚拟化、端口映射明确

### 3. IPv6-only VPS
- **优点**：最便宜
- **缺点**：需要客户端支持IPv6、延迟可能较高
- **适用场景**：客户端有IPv6、预算极度有限

## 部署方案选择

### 方案一：3x-ui面板（图形化管理）
**适用场景**：需要多用户管理、流量统计、Web界面操作

**优点**：
- Web GUI管理，操作简单
- 支持多用户、流量统计
- 自动续签证书

**缺点**：
- 资源占用较高（~50MB内存）
- 1GB硬盘可能装不下
- 自动化较难

**安装命令**：
```bash
# 更新系统
apt update && apt install -y curl wget

# 一键安装
bash <(curl -fsSL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)

# 安装后立即修改默认密码
/usr/local/x-ui/x-ui setting -username admin -password YOUR_PASSWORD
systemctl restart x-ui
```

### 方案二：原生Xray（轻量级）
**适用场景**：低配服务器、需要脚本自动化、追求性能

**优点**：
- 资源占用极低（~10MB内存）
- 1GB硬盘也能运行
- 完全脚本化

**缺点**：
- 命令行操作
- 需要手动编辑JSON配置

**安装命令**：
```bash
# 安装Xray（带geo数据）
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 安装Xray（不带geo数据，省空间）
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata
```

## 协议选择指南

### 1. VLESS+Reality（推荐）
**优点**：
- 无需域名和证书
- 隐蔽性最好
- 性能优秀

**缺点**：
- 部分客户端兼容性问题
- 需要Xray 26.7.x+

**适用场景**：追求最佳隐蔽性

### 2. VMess+WebSocket
**优点**：
- 兼容性最好
- 配置简单
- 不需要证书

**缺点**：
- 隐蔽性一般
- 容易被识别

**适用场景**：快速部署、兼容性要求高

### 3. Trojan
**优点**：
- 隐蔽性好（伪装成HTTPS）
- 兼容性好
- 性能优秀

**缺点**：
- 需要域名和TLS证书
- 配置稍复杂

**适用场景**：需要伪装成正常HTTPS流量

## 详细部署步骤

### 步骤一：环境准备
```bash
# 更新系统
apt update && apt upgrade -y

# 安装必要工具
apt install -y curl wget unzip jq

# 检查系统信息
cat /etc/os-release
df -h /
free -m
```

### 步骤二：安装Xray
```bash
# 方法1：官方脚本（推荐）
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 方法2：手动下载（适合出站受限的服务器）
curl -fSL -o /tmp/xray.zip "https://gh-proxy.com/https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
unzip -o /tmp/xray.zip xray -d /usr/local/bin/
chmod +x /usr/local/bin/xray
```

### 步骤三：生成配置
```bash
# 生成UUID
UUID=$(xray uuid)
echo "UUID: $UUID"

# 生成Reality密钥对
KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public" | awk '{print $3}')
echo "Private Key: $PRIVATE_KEY"
echo "Public Key: $PUBLIC_KEY"

# 生成Short ID
SHORT_ID=$(openssl rand -hex 8)
echo "Short ID: $SHORT_ID"
```

### 步骤四：创建配置文件
```bash
cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "$UUID", "flow": "xtls-rprx-vision"}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "dest": "www.microsoft.com:443",
        "serverNames": ["www.microsoft.com", "microsoft.com"],
        "privateKey": "$PRIVATE_KEY",
        "shortIds": ["", "$SHORT_ID"]
      }
    },
    "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

# 重启Xray
systemctl restart xray
systemctl enable xray
```

### 步骤五：验证服务
```bash
# 检查状态
systemctl status xray

# 检查端口
ss -tlnp | grep 443

# 检查日志
journalctl -u xray -f
```

## 客户端配置

### V2RayNG（Android）
```
vless://UUID@SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp#节点名称
```

### Clash Meta（Windows/Mac/Android）
```yaml
proxies:
  - name: 节点名称
    type: vless
    server: SERVER_IP
    port: 443
    uuid: UUID
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: www.microsoft.com
    reality-opts:
      public-key: PUBLIC_KEY
      short-id: SHORT_ID
    client-fingerprint: chrome

proxy-groups:
  - name: 节点选择
    type: select
    proxies:
      - 节点名称
      - DIRECT

rules:
  - MATCH,节点选择
```

## NAT小鸡特殊处理

### 端口映射配置
NAT小鸡需要使用商家提供的端口映射：
```bash
# 查看端口映射
cat /etc/xray/config.json | jq '.inbounds[].port'

# 常见映射关系
# 外网端口20039 → 内网端口22 (SSH)
# 外网端口20040 → 内网端口443 (Xray)
```

### 1GB硬盘优化
```bash
# 清理空间
apt purge -y exim4-base exim4-daemon-light exim4-config bsd-mailx socat
apt autoremove -y && apt clean
rm -rf /var/log/*

# 安装轻量级Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata

# 安装最小Python（订阅服务需要）
apt install -y python3-minimal
```

### 订阅服务部署
```bash
# 创建订阅目录
mkdir -p /www/clash

# 创建Clash配置文件
cat > /www/clash/clash-meta.yaml << EOF
mixed-port: 7890
allow-lan: true
mode: rule
proxies:
  - name: NAT-VPN
    type: vmess
    server: SHARED_IP
    port: XRAY_PORT
    uuid: UUID
    alterId: 0
    cipher: auto
    udp: true
    network: ws
    ws-opts:
      path: "/wunian"
proxy-groups:
  - name: 节点选择
    type: select
    proxies:
      - NAT-VPN
      - DIRECT
rules:
  - MATCH,节点选择
EOF

# 启动HTTP服务
nohup python3 -m http.server HTTP_PORT --bind 0.0.0.0 --directory /www/clash &>/tmp/http.log &
```

## 常见问题排查

### 问题一：连接超时
**可能原因**：
1. 服务器防火墙未开放端口
2. Xray服务未启动
3. 客户端配置错误

**排查步骤**：
```bash
# 检查Xray状态
systemctl status xray

# 检查端口监听
ss -tlnp | grep 443

# 检查防火墙
iptables -L -n | grep 443

# 测试本地连接
curl -x socks5://127.0.0.1:1080 http://ip.sb
```

### 问题二：认证失败
**可能原因**：
1. UUID不匹配
2. Reality密钥不匹配
3. Short ID错误

**解决方法**：
```bash
# 重新生成密钥
xray x25519

# 更新配置文件
vim /usr/local/etc/xray/config.json

# 重启Xray
systemctl restart xray
```

### 问题三：能连接但无法上网
**可能原因**：
1. DNS解析问题
2. 路由规则错误
3. 目标网站被屏蔽

**排查步骤**：
```bash
# 测试DNS解析
nslookup google.com

# 测试代理连接
curl -x socks5://127.0.0.1:1080 https://ipinfo.io

# 检查Xray日志
tail -f /var/log/xray/access.log
```

### 问题四：速度慢
**可能原因**：
1. 服务器带宽不足
2. 线路质量差
3. 协议选择不当

**优化建议**：
1. 选择靠近用户的服务器位置
2. 使用VMess+WebSocket协议
3. 考虑使用Cloudflare CDN中转

## 高级功能

### 多节点合并
```bash
# 创建多节点配置
cat > /www/clash/clash-meta.yaml << EOF
mixed-port: 7890
allow-lan: true
mode: rule
proxies:
  - name: 香港节点
    type: vmess
    server: HK_IP
    port: 443
    uuid: UUID1
    alterId: 0
    cipher: auto
    udp: true
    network: ws
    ws-opts:
      path: "/wunian"
  - name: 美国节点
    type: vmess
    server: US_IP
    port: 443
    uuid: UUID2
    alterId: 0
    cipher: auto
    udp: true
    network: ws
    ws-opts:
      path: "/wunian"
proxy-groups:
  - name: 节点选择
    type: select
    proxies:
      - 香港节点
      - 美国节点
      - DIRECT
rules:
  - MATCH,节点选择
EOF
```

### 流量监控
```bash
# 安装vnstat
apt install -y vnstat

# 启动服务
systemctl enable vnstat
systemctl start vnstat

# 查看流量统计
vnstat -l
vnstat -d
```

### 自动备份
```bash
# 创建备份脚本
cat > /root/backup.sh << EOF
#!/bin/bash
DATE=$(date +%Y%m%d)
tar -czf /root/backup-$DATE.tar.gz /usr/local/etc/xray/
find /root/backup-*.tar.gz -mtime +7 -delete
EOF

# 添加定时任务
echo "0 2 * * * /root/backup.sh" | crontab -
```

## 安全注意事项

### 1. 修改默认端口
```bash
# 更改SSH端口
vim /etc/ssh/sshd_config
# 修改 Port 22 为其他端口
systemctl restart sshd
```

### 2. 配置防火墙
```bash
# 安装ufw
apt install -y ufw

# 允许必要端口
ufw allow 22/tcp
ufw allow 443/tcp

# 启用防火墙
ufw enable
```

### 3. 定期更新
```bash
# 更新系统
apt update && apt upgrade -y

# 更新Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

## 性能优化

### 1. 内核参数调优
```bash
cat >> /etc/sysctl.conf << EOF
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

sysctl -p
```

### 2. BBR加速
```bash
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

### 3. 连接数限制
```bash
# 查看当前限制
ulimit -n

# 修改限制
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf
```

## 监控和维护

### 1. 服务状态检查
```bash
# 检查Xray状态
systemctl status xray

# 检查端口状态
ss -tlnp | grep 443

# 检查系统资源
htop
df -h
free -m
```

### 2. 日志分析
```bash
# 查看Xray日志
tail -f /var/log/xray/access.log
tail -f /var/log/xray/error.log

# 查看系统日志
journalctl -u xray -f
```

### 3. 性能监控
```bash
# 安装监控工具
apt install -y iftop nethogs

# 监控网络流量
iftop -i eth0
nethogs eth0
```

## 故障恢复

### 1. 服务崩溃恢复
```bash
# 重启Xray
systemctl restart xray

# 检查配置文件
xray run -test -c /usr/local/etc/xray/config.json

# 查看错误日志
journalctl -u xray -n 100
```

### 2. 配置文件丢失
```bash
# 从备份恢复
tar -xzf /root/backup-latest.tar.gz -C /

# 重新生成配置
xray uuid
xray x25519
```

### 3. 系统重装
```bash
# 备份重要数据
tar -czf /root/backup-all.tar.gz /usr/local/etc/xray/ /www/clash/

# 重装系统后恢复
tar -xzf /root/backup-all.tar.gz -C /
systemctl restart xray
```

## 最佳实践

### 1. 文档记录
每个VPS都应该有记录文档：
- 服务器信息（IP、端口、密码）
- 配置参数（UUID、密钥、端口）
- 变更历史
- 问题记录

### 2. 定期维护
- 每月检查系统更新
- 每季度更新Xray版本
- 定期备份配置文件

### 3. 安全审计
- 定期检查登录日志
- 监控异常流量
- 及时更新密码

## 快速参考

### 常用命令
```bash
# Xray管理
systemctl status xray
systemctl restart xray
journalctl -u xray -f

# 配置检查
xray run -test -c /usr/local/etc/xray/config.json

# 端口检查
ss -tlnp | grep 443

# 流量监控
vnstat -l
iftop -i eth0
```

### 默认路径
- Xray配置：`/usr/local/etc/xray/config.json`
- Xray日志：`/var/log/xray/`
- 订阅文件：`/www/clash/`
- 备份文件：`/root/backup-*.tar.gz`

### 默认端口
- SSH：22
- Xray：443
- HTTP订阅：8080
- Clash代理：7890