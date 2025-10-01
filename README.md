# Claude Code Everywhere

**让你的 Claude Code UI 真正实现随时随地访问！**

这个项目是 [siteboon/claudecodeui](https://github.com/siteboon/claudecodeui) 的一个 Fork，旨在提供一个开箱即用的解决方案，让你能够通过一个稳定的公共域名，在任何设备（包括手机）上，在任何有网络连接的地方（车上/餐厅/公园，everywhere!）安全地访问和操作你本地的 Claude Code 实例。

## ✨ 特性

-   **一键安装**: 通过一个简单的脚本自动完成所有复杂的环境配置。
-   **稳定公网访问**: 基于 Cloudflare Tunnel，为你提供一个永久免费的 HTTPS 公共域名。
-   **后台稳定运行**: 使用 `tmux` 管理后台服务，一键启动、一键停止，并可随时查看日志。
-   **Linux/WSL 优先**: 专为 Linux 和 WSL 用户优化，并为其他平台提供指引。
-   **完整的生命周期管理**: 提供安装、启动、停止和卸载全套脚本。

## 🚀 快速开始

在开始之前，请确保你已经准备好了**一个你自己的域名**和**一个免费的 Cloudflare 账户**。如果你还没有，请先展开下面的**详细图文指南**完成准备工作。

准备就绪后，只需一行命令即可开始安装：

```bash
# 克隆仓库并运行安装脚本
git clone https://github.com/SpringWu5/claude-code-everywhere.git
cd claude-code-everywhere/scripts
./setup.sh
```

## 📋 先决条件

在运行安装脚本前，请确保你已经满足：

1.  一个 Linux 或 WSL (Ubuntu) 环境。
2.  一个你完全控制的域名。
3.  一个免费的 [Cloudflare](https://dash.cloudflare.com/) 账户。
4.  已安装 `git`, `npm`, `curl` 等基础工具。

## 📚 使用指南

-   **启动所有服务:** `./start.sh`
-   **停止所有服务:** `./stop.sh`
-   **完全卸载:** `./uninstall.sh`

---

<summary>
<h3 style="display: inline-block;">📚 步骤一：获取免费域名并添加到 Cloudflare (详细文字指南)</h3>
</summary>

> **目标：** 在本节结束时，你应该拥有一个自己的域名，并成功将其添加到 Cloudflare，状态为“活动 (Active)”。这是整个设置中最关键的一步，请耐心操作。

#### 第1部分：注册免费域名

我们将使用 `DigitalPlat` 提供的免费二级域名服务作为示例。

1.  **访问注册网站**
    打开浏览器，访问：[https://dash.domain.digitalplat.org/register](https://dash.domain.digitalplat.org/register)

2.  **完成账户注册**
    *   填写你的邮箱和密码进行注册。
    *   检查你的邮箱，点击确认邮件中的链接以激活账户。
    *   按照网站提示完成 KYC 授权，通常需要连接你的 GitHub 账户。
    *   完成后，回到登录页面并登录。

3.  **检查并选择你的域名**
    *   在域名管理仪表板中，找到“注册新域名”或类似选项。
    *   想一个你喜欢的、独特的名字（例如 `my-awesome-claude`），然后在 `dpdns.org` 下检查其可用性。
    *   如果可用，进入“Checkout”或注册页面。

    > **【截图点 1】** 此时，你应该会看到一个页面，上面显示你的域名信息，并要求你填写 **Name Server 1** 和 **Name Server 2**。**请保持这个页面不要关闭**，我们将从 Cloudflare 获取这两个地址。

#### 第2部分：将域名添加到 Cloudflare

1.  **登录 Cloudflare**
    * 在新的浏览器标签页中，登录你的 [Cloudflare 仪表板](https://dash.cloudflare.com/)。

2.  **添加站点 (Add a site)**
    *   在主页上，点击 **“+ Add a site”** 按钮。
    *   输入你刚刚选择的完整域名（例如 `my-awesome-claude.dpdns.org`），然后点击“Continue”。

3.  **选择免费计划 (Free Plan)**
    *   滚动页面，选择 **Free** 计划，然后点击“Continue”。

4.  **获取 Cloudflare 的 Name Servers**
    *   Cloudflare 会扫描你现有的 DNS 记录（通常是空的），然后会进入一个名为 **“Change your nameservers”** 的页面。
    *   在这个页面上，Cloudflare 会提供**两个**它自己的名称服务器地址。它们看起来像 `xxxx.ns.cloudflare.com`。

    > **【截图点 2】** 请将这两个名称服务器地址完整地复制下来。

#### 第3部分：完成域名注册

1.  **回到域名注册商的页面**（我们在第1部分的最后一步打开的那个页面）。

2.  **填写 Name Servers**
    *   将 Cloudflare 提供的第一个名称服务器地址粘贴到 **Name Server 1** 输入框中。
    *   将 Cloudflare 提供的第二个名称服务器地址粘贴到 **Name Server 2** 输入框中。

    > **【截图点 3】** 确保填写无误。

3.  **完成注册**
    点击“Continue”或“Register”按钮，完成域名的注册流程。

#### 第4部分：验证域名状态

1.  **回到 Cloudflare 仪表板**。
2.  点击 **“Done, check nameservers”** 按钮。Cloudflare 会开始检查你的域名是否已经指向了它的名称服务器。
3.  这个过程可能需要几分钟到几小时。你可以偶尔刷新页面。
4.  当你在域名的“Overview”页面看到绿色的对勾和 **“Great news! Cloudflare is now protecting your site”** 的提示时，说明你的域名已成功激活！

    > **【截图点 4】** 域名状态变为“活动 (Active)”的成功界面。

**恭喜！最复杂的部分已经完成。现在你可以继续运行 `./setup.sh` 脚本了。**


<summary>
<h3 style="display: inline-block;">🔧 问题排查 (Troubleshooting)</h3>
</summary>

#### Q: 安装/运行时出现代理错误 (Proxy Error)？

**A:** 我们的脚本设计了 `( unset ...; command )` 的方式来尝试绕过本地代理。如果仍然失败，说明你的代理（如 Clash）可能配置为“透明代理”或 TUN 模式，捕获了所有流量。
**解决方案：** 在运行脚本（特别是 `setup.sh` 和 `start.sh`）时，**临时关闭**你 WSL 中的代理客户端，完成后再重新开启。

#### Q: `cloudflared tunnel login` 认证超时？

**A:** 这通常也是由本地代理引起的。请按照上述方法，在没有代理的环境下重新运行 `cloudflared tunnel login`。
