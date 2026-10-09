# 微信 AI 客服机器人（SiverWXbot_plus 部署版）

基于 [SiverWXbot_plus](https://github.com/SiverKing/SiverWXbot_plus)（Apache-2.0）+ wxautox4 Plus 的 Windows 微信 AI 客服，带完整 Web 管理面板。
本仓库在官方开源框架基础上增加了一键安装/体检脚本与部署模板，克隆后即可使用。

## 能力一览

- Web 面板：机器人启停、实时日志、20 个功能配置页（状态 / 模型 / Prompt / 私聊 / 群组 / 好友 / 关键词 / 转发 / 定时消息 / 朋友圈 / 定时启停 / 记忆 / 备份 …）
- 群聊仅被 @ 时回复、私聊自动回复、多群/多人独立 Prompt 与独立模型
- AI 接口：OpenAI 兼容（DeepSeek 等）、Dify（知识库 RAG）、Coze，支持故障自动降级
- 对话记忆、关键词回复、自定义转发、定时/随机消息、自动通过好友、定时启停

## 环境要求

| 项 | 要求 |
|---|---|
| 系统 | Windows 10/11（不支持 macOS/Linux） |
| Python | 3.10 ~ 3.12（安装时勾选 Add to PATH） |
| PC 微信 | 官方支持 4.1.9 ~ 4.1.15.13（4.1.8.107 基础监听也可用） |
| wxautox4 | Plus 已激活（一个激活码绑定一台电脑，不可转移） |

## 快速开始（新机器）

> 📖 **从零开始（含 Python/微信/激活/面板每一步点击流程）请看 [使用手册.md](使用手册.md)**，国内网络直连，无需 VPN。

```bat
git clone https://gitee.com/<你的组织或用户名>/<仓库名>.git
cd <仓库名>
scripts\install.bat
```

install.bat 会自动：从清华镜像安装 Python 依赖（失败自动回退官方源）→ 从 `config.example.json` 生成本地配置（不覆盖已有配置）→ 运行环境体检。

然后：

1. 激活 wxautox4（每台机器一次）：
   ```bat
   wxautox4 auth activate <你的激活码>
   ```
2. 登录 PC 微信，保持主窗口打开
3. 双击 **start.bat**，浏览器自动打开面板（端口在 10001–11000 自动选取）
4. 默认登录 `admin / 123456`，首次登录后请到「账号密码」页修改
5. 「模型配置」页填入 DeepSeek（或其它 OpenAI 兼容接口）的 API Key → 测试 → 保存
6. 「状态面板」→ 启动机器人 → 在群里 @机器人 测试

## 目录结构

```
SiverWXbot_plus/
├── web_server.py            # 面板入口（python web_server.py）
├── wxbot_core.py            # 机器人核心
├── config.example.json      # 配置模板（已脱敏，随仓库更新）
├── start.bat                # 日常启动（双击）
├── scripts/
│   ├── install.bat          # 新机器一键安装
│   └── doctor.py            # 环境体检（Python/依赖/激活/微信版本/配置/实例）
├── config/                  # 【不入库】本地数据
│   ├── config.json          #   全部配置（含 API Key，绝不提交）
│   ├── admin.json           #   面板账密哈希
│   ├── panel_secret.key     #   会话密钥
│   └── prompt/*.md          #   Prompt 人设文件
├── memory/                  # 【不入库】对话记忆
├── old_wxbot_config/        # 【不入库】自动备份
└── panel_logs/              # 【不入库】面板日志
```

## 接 Dify 知识库（可选）

1. Dify 上创建**聊天助手（Chatflow）**应用（不能选工作流），在编排中绑定知识库并发布
2. 「访问 API」创建密钥（形如 `app-xxxx`）
3. 面板「模型配置」新增/编辑一个接口：SDK 选 `Dify`
   - Base URL：`https://api.dify.ai/v1/chat-messages`（结尾必须是 /chat-messages）
   - API Key：`app-xxxx`；模型栏任意值
4. 测试通过后保存，单选框切到该接口

## 常见问题

- **启动报"找不到微信窗口"**：确认 PC 微信已登录、版本在支持范围；微信窗口不要最小化到托盘
- **改了群列表不生效**：监听名单只在启动时注册，到「状态面板」停止再启动机器人
- **回复前面带 @昵称**：「群组管理」关闭"回复时@发言人"
- **误杀进程后监听窗口残留/启动卡住**：重启微信客户端即可恢复
- **换机/备份**：复制 `config/` 与 `memory/` 两个文件夹；回滚用 `old_wxbot_config/`

## 安全须知

- API Key、面板密码、聊天记忆**只存在本机**，`.gitignore` 已排除，严禁提交
- 面板默认只监听 127.0.0.1；如需公网访问请使用官方 SiverPanel 并先改掉默认密码
- 本项目为第三方 UI 自动化工具，与腾讯/微信无关；请遵守当地法律法规与微信使用条款

## 致谢

核心代码来自 SiverKing 的 [SiverWXbot_plus](https://github.com/SiverKing/SiverWXbot_plus)（Apache License 2.0，见 LICENSE）。
