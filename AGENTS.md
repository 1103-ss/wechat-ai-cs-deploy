# AGENTS.md — 给 AI 编码/运维代理的部署与操作手册

本仓库是 **Windows 微信 AI 客服机器人**的可克隆部署版（SiverWXbot_plus + wxautox4 Plus）。
当用户说"帮我装一下/部署/恢复/迁移微信客服机器人"时，严格按本文件执行，**不要重新自研机器人或面板**。
给最终用户的图文版是根目录 **`使用手册.md`**，需要给人看的步骤直接引用它，不要另写一套。

## 目标终态（5 分钟能不能说清楚）

用户提供：Windows 10/11 x64、兼容版 PC 微信安装包（4.1.9~4.1.15.13，已由提供方私下交付）、
**他自己的** wxautox4 激活码、**他自己的** DeepSeek API Key、一个客服微信号。
Agent 自动化完成其余全部环节：Python（国内镜像自动下载静默安装）→ pip 依赖（清华源）→
微信（用用户已有的本地安装包辅助安装）→ 引导激活 → 启动面板 → 引导配置 → 群 @ 验证。

## 硬性事实（避免重复踩坑）

- 只支持 **Windows**，Python **3.10–3.12**（3.13 可能有依赖兼容问题）
- PC 微信兼容版本：**4.1.9 ~ 4.1.15.13**（4.1.8.107 基础监听可用但非官方推荐；5.x 不兼容）
- wxautox4 内核为**付费设备授权**：`wxautox4 auth activate <码>`，一码绑一机不可解绑；
  激活只需国内网络即可，一次联网校验
- 面板由 `python web_server.py` 启动（日常用根目录 `start.bat`），端口 10001–11000 自动选端口，
  默认账密 admin/123456
- 同一台机器同一时刻**只能有一个机器人进程**连接微信（有单实例检测）
- 配置热更新：除监听注册类字段（group / listen_list / admin / 定时任务注册等，见
  `config_apply.py` 的 RESTART_REASONS）外都可热生效；改监听名单必须在面板重启机器人
- Dify 集成调的是 **chat-messages 阻塞接口**，URL 必须以 `/v1/chat-messages` 结尾；
  Dify 端必须建 Chatflow/聊天助手，不能建 Workflow
- 机器人靠 PC 微信窗口的界面自动化工作，运行时微信必须**已登录、主窗口不能最小化到托盘**

## 阶段 0｜向用户收齐 4 样东西（不能替代用户做的事）

以提问方式收齐，不要臆造：

1. **PC 微信兼容版安装包的本地路径**（提供方已私下交付，通常在下载文件夹或桌面，
   名字类似 `WeChatSetup-4.1.x.exe`；本项目不提供下载）
2. **wxautox4 Plus 激活码**（每台机器一个、不可转移；让用户在需要输入时亲手粘贴，
   **不要把激活码写进任何文件、命令参数或日志**）
3. **DeepSeek API Key**（`sk-` 开头；同样让用户在面板里亲手填或通过面板 API，不落盘到仓库）
4. 一个**专门做客服的微信号**及需要机器人进的群（机器人运行期间要在本机保持登录）

## 阶段 1｜获取代码（三选一，已在项目目录内则跳过）

1. **已收到安装包/压缩包**（国内最常见）：解压到纯英文路径如 `D:\wechat-ai-cs`（避免桌面和中文路径）。
2. **git clone**（有 git 时）：`git clone https://github.com/1103-ss/wechat-ai-cs-deploy.git`
3. **ZIP 下载**（能访问 GitHub 时）：
   `https://github.com/1103-ss/wechat-ai-cs-deploy/archive/refs/heads/main.zip`
   无 VPN 拉不动可尝试公共 GitHub 加速前缀（非官方、稳定性随时间变化，多试几个）：
   `https://ghfast.top/https://github.com/1103-ss/wechat-ai-cs-deploy/archive/refs/heads/main.zip`

> 若用户需要 git 但机器上没有，bootstrap 加 `-WithGit` 参数即可从 npmmirror 自动安装 Git for Windows。

## 阶段 2｜一键 bootstrap（Agent 直接执行）

在项目根目录（`web_server.py` 所在目录）执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup_windows.ps1
# 需要同时自动装 Git：
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup_windows.ps1 -WithGit
```

人类用户也可以直接双击 `scripts\install.bat`（`install.bat --git` 含 Git）。脚本会按序完成：

1. 探测 Python 3.10–3.12（`py` 启动器 → PATH → 默认用户目录三通道）；
   缺失时从 **华为云镜像**（失败转阿里云镜像）下载 Python 3.12.10（约 27MB），
   **按用户静默安装、不需要管理员权限**，并刷新当前会话 PATH；
2. `-WithGit` 时从 npmmirror 下载 Git for Windows 并静默安装（约 64MB）；
3. 从**清华 pip 镜像**安装 requirements.txt（失败自动回退官方 PyPI）；
4. 从 `config.example.json` 生成 `config/config.json`（**已存在则完全不碰用户配置**，可重复执行）；
5. 运行 `scripts/doctor.py`。

**验收标准**：doctor 输出 `Summary: x pass, x warn, 0 fail`。此时有 wxautox4 未激活、
微信未安装/版本 WARN、无 API Key 的 WARN 都正常，后续阶段处理；出现任何 FAIL 必须先解决。
若 3.13 已独占 PATH：脚本会另装 3.12 用户版并优先使用它，不需要卸载 3.13。

## 阶段 3｜安装并登录 PC 微信（用用户已有的安装包）

用提供的本地安装包执行（路径换成实际文件）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install_wechat.ps1 -InstallerPath "$env:USERPROFILE\Downloads\WeChatSetup.exe"
```

- 脚本先查注册表：已装兼容版则直接成功（幂等）；已装 5.x 等不兼容版会提示先卸载；
- 先尝试 `/S` 静默安装并轮询注册表确认；不成功会**自动打开图形安装界面**，此时引导用户点完，
  然后运行 `python scripts\doctor.py` 复核版本（exit 2 表示等用户图形安装，不是故障）；
- **登录与设置必须用户亲手做（扫码 + 微信设置属账户操作）**，Agent 提醒并核对：
  1. 手机扫码登录客服微信号；
  2. 微信左下角 `设置 → 通用设置`，**取消勾选"有更新时自动升级微信"**（升级即失效，必查）；
  3. 主窗口保持打开、**不要最小化到托盘**；
  4. 把需要服务的群聊在微信里打开一次，留在会话列表；
  5. Windows 电源设置建议关闭自动休眠，屏幕缩放保持 100%（图片识别相关功能需要）。

## 阶段 4｜激活 wxautox4（每机一次，码由用户亲手提供）

1. 让用户把激活码准备好；在项目根目录打开终端：
   ```
   wxautox4 auth activate
   ```
   （输入不显示字符属正常；也支持 `wxautox4 auth activate <码>`，但避免把码留在命令历史里。
   也可启动面板后在「状态面板」顶部红色激活条点"点我激活"。）
2. 验证：`wxautox4 auth check` 能看到 active/已激活；或 `python scripts\doctor.py` 中
   `wxautox4 license` 为 PASS。
3. 不要替用户输入激活码、不要把激活码写入任何文件或聊天外的地方。

## 阶段 5｜启动面板并完成首次安全设置

```
start.bat        （或 python web_server.py；黑窗口不能关，关=停服务）
```

- 浏览器自动打开，否则手动访问黑窗口打印的地址（默认 `http://127.0.0.1:10001`，占用则顺延）；
- 默认 **admin / 123456**，登录后第一件事到左侧「账号密码」页改掉；
- 面板只监听 127.0.0.1，除非用户明确要求，不要开启公网/内网穿透。

## 阶段 6｜面板配置（左侧共 19 个页面，首配只需前 6 个）

Agent 可引导用户操作，或在征得同意后用浏览器自动化代填（**Key 类字段让用户亲手输入**）。

1. **模型配置**：SDK 选「OpenAI API 格式兼容接口」；模型 `deepseek-chat`；
   Base URL `https://api.deepseek.com`；API Key 由用户粘贴；点「测试可用性」成功；
   确认该卡片单选框被选中（绿色边框/当前使用角标）→ 顶部「保存配置」。
   （Dify 槽位可选：SDK 选 Dify，URL 以 `/v1/chat-messages` 结尾，Key 为 app-xxxx，
   Dify 端建聊天助手/Chatflow 并发布。）
2. **Prompt**：检查/编辑默认人设（卖什么、价格口径、禁区、转人工条件），保存。
3. **管理员**：保持或修改管理员微信名（默认 `文件传输助手` 最方便自测）。
4. **私聊监听**：按需开 AllListen 或加监听名单（只能是联系人，不能写群名）。
5. **群组管理**（客服主场景）：启用群聊监听 → 勾「仅@时回复」→ 关「回复时@发言人」→
   底部添加群名（**与微信显示一字不差**）→ 可按群单独指定 Prompt/接口 → 保存配置。
6. **关键词回复**：先把敏感词拦截、转人工、确定答案的百问百答配成关键词固定回复
   （命中关键词不调 AI、优先级最高；注意关键词监听依托私聊/群监听对象设置）。

改完监听类配置（群名单、监听开关、管理员等）→ 回「状态面板」**停止→启动机器人**。

## 阶段 7｜端到端验证（必做，全部满足才算交付）

1. 微信已登录且窗口未最小化；doctor 为 0 fail；
2. 状态面板点「启动机器人」，状态变绿、有运行时长；
3. 用**另一个微信号**往测试群发 `@机器人 你好，这个怎么收费？`，1~5 秒内群内收到回复；
   状态面板"收到消息/已回复"计数 +1；
4. 再发一条**不 @** 的普通消息，机器人**不应回复**（验证防骚扰）；
5. 私聊/关键词规则按配置抽查一条；
6. 向用户交代每日开关机顺序：开机 登录微信→start.bat→启动机器人；
   关机 面板停止（或黑窗口 Ctrl+C）→ 再关机。**禁止强杀 python/直接关黑窗口**，
   否则残留监听窗导致下次启动卡住（卡住就重启微信客户端）。

## 可复制的验收命令

```powershell
python --version                 # 3.10 - 3.12
python scripts\doctor.py         # 0 fail
wxautox4 auth check              # active
Invoke-WebRequest http://127.0.0.1:10001 -UseBasicParsing | Select-Object StatusCode  # 面板在跑
```

## 红线

- **绝不**把 API Key、激活码写进任何被 git 跟踪的文件或命令行参数；
  `config/config.json`、`config/admin.json`、`config/panel_secret.key`、`config/email.txt`、
  `config/webhook.json`、`memory/`、`panel_logs/`、`*.log` 均已被 .gitignore 忽略
- 配置模板唯一来源：仓库根的 `config.example.json`（维护时先改它，再同步本机 config.json）
- bat / ps1 脚本只能用 **ASCII**（GBK 控制台解析非 ASCII 会直接语法崩溃）；中文写 .md；
  ps1 内需要匹配中文时用 `[char]0xXXXX` 拼接（见 install_wechat.ps1）
- PowerShell 5.1 给原生存参时会吞掉内嵌双引号——脚本中调用 `python -c "..."` 一律避免内嵌引号，
  优先用 `python --version`、临时 .py 文件或 stdin
- 下载类操作落地后必须校验文件大小（Python 安装包 >20MB、Git >50MB），再执行安装
- 停止机器人必须优雅退出（面板停止按钮 / Ctrl+C），不要强杀 python 进程
- 不要修改 `config/` 后让用户重启面板进程本身；面板 7x24 常驻，只需重启"机器人"

## 排障速查

| 现象 | 处理 |
|---|---|
| 未找到已登录的微信主窗口 | 微信版本不符/未登录/窗口最小化；先跑 doctor.py |
| 注册表显示 5.x/企业微信干扰判断 | doctor 已排除企业微信；5.x 需卸载改装兼容版 |
| 激活后仍提示未授权 | 确认用的是 wxautox4（非 wxauto4）；`wxautox4 auth check` |
| 启动卡住无输出 | 上次强杀残留监听窗；重启微信客户端 |
| 群消息不回复 | 群名一字不差、机器人在群内、消息确实 @、启用群监听并已重启机器人 |
| 群回复带多余前缀 | 群组管理关闭"回复时@发言人"，保存后重启机器人 |
| API 返回错误 | 面板「模型配置」点"测试可用性"；查 panel_logs/ 与面板实时日志 |
| 镜像下载失败 | setup 会自动换源；公司网可切手机热点；Python 也可手动装后重跑脚本 |
| 面板打不开 | 黑窗口还在吗？端口看黑窗口输出；防火墙放行 python |

## 维护上游

主体是 SiverKing/SiverWXbot_plus（Apache-2.0）快照 + 本仓库部署增量
（README.md、AGENTS.md、使用手册.md、config.example.json、start.bat、scripts/）。
升级上游时重新下载官方 zip 覆盖，但保留部署增量与 LICENSE，
并重新核对 config_defaults.py 新增字段是否需要补进 config.example.json。
