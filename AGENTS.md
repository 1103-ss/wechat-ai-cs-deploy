# AGENTS.md — 给 AI 编码/运维代理的部署说明

本仓库是 **Windows 微信 AI 客服机器人**的可克隆部署版（SiverWXbot_plus + wxautox4 Plus）。
当用户要求"部署/恢复/迁移微信客服机器人"时，按本文件执行，不要重新自研机器人或面板。

## 硬性事实（避免重复踩坑）

- 只支持 **Windows**，Python **3.10–3.12**（3.13 可能有依赖兼容问题）
- PC 微信兼容版本：**4.1.9 ~ 4.1.15.13**（4.1.8.107 基础监听可用但非官方推荐）
- wxautox4 内核为**付费设备授权**：`wxautox4 auth activate <码>`，一码绑一机不可解绑
- 面板入口 `python web_server.py`，端口 10001–11000 自动选择，默认账密 admin/123456
- 同一台机器同一时刻**只能有一个机器人进程**连接微信（脚本里有实例检测）
- 配置热更新：除监听注册类字段（group / listen_list / admin / 定时任务注册等，见
  `config_apply.py` 的 RESTART_REASONS）外都可热生效；改监听名单必须在面板重启机器人
- Dify 集成调的是 **chat-messages 阻塞接口**，URL 必须填到 `.../v1/chat-messages` 结尾，
  Dify 端必须建 Chatflow/聊天助手，不能建 Workflow

## 标准部署流程

> 给最终用户的图文全流程（Gitee 克隆、国内镜像、面板逐页操作）维护在 `使用手册.md`，用户问"怎么装/怎么用面板"时直接引用它，不要另写一套。
> 代码主分发渠道为 Gitee 私有仓库（国内无 VPN 场景）；install.bat 已默认走清华 pip 镜像并回退官方源。

1. `scripts\install.bat`（装依赖、生成 config/config.json、跑 doctor）
2. `python scripts\doctor.py` 确认 PASS/WARN 项，FAIL 必须解决
3. 引导用户完成两件 AI 无法代办的事：wxautox4 激活、安装兼容版微信
4. `start.bat` 启动面板 → 用户在面板填 API Key → 状态面板启动机器人
5. 用另一个微信号在测试群 @机器人 验证端到端回复

## 红线

- **绝不**把 API Key、激活码写进任何被 git 跟踪的文件或命令行参数；
  `config/config.json`、`config/admin.json`、`config/panel_secret.key`、
  `config/email.txt`、`config/webhook.json`、`memory/`、`panel_logs/`、`*.log` 均已被忽略
- 配置模板唯一来源：仓库根的 `config.example.json`（维护时先改它，再同步本机 config.json）
- bat / ps1 启动脚本只能用 **ASCII**（GBK 控制台解析非 ASCII 会直接语法崩溃）；
  中文文档写 .md 文件
- 停止机器人必须优雅退出（面板停止按钮 / Ctrl+C），不要强杀 python 进程，
  否则 wxauto 的独立监听子窗口会残留导致下次启动卡住
- 不要修改 `config/` 下文件后让用户重启面板进程本身；面板 7x24 常驻，只需重启"机器人"

## 排障速查

| 现象 | 处理 |
|---|---|
| 未找到已登录的微信主窗口 | 微信版本不符/未登录/窗口最小化；先跑 doctor.py |
| 激活后仍提示未授权 | 确认用的是 wxautox4（非 wxauto4）；`wxautox4 auth check` |
| 启动卡住无输出 | 上次强杀残留监听窗；重启微信客户端 |
| 群消息不回复 | 确认群名与微信显示完全一致、机器人在群内、触发消息是 @机器人 |
| 群回复带多余前缀 | config 的 group_reply_at_msg 控制回复是否 @发言人 |
| API 返回错误 | 面板「模型配置」点"测试可用性"；查 panel_logs/ 与面板实时日志 |

## 维护上游

本仓库主体是 SiverKing/SiverWXbot_plus（Apache-2.0）的快照 + 本仓库的部署增量
（README.md、AGENTS.md、config.example.json、start.bat、scripts/）。
升级上游时重新下载官方 zip 覆盖，但保留上述部署增量与 LICENSE，并重新核对
config_defaults.py 中新增字段是否需要补进 config.example.json。
