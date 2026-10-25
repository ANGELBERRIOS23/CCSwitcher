### A new look for the menu bar panel

The dropdown is now a floating panel in Claude's colours — warm ivory and charcoal surfaces with terracotta accents — that opens from under the menu bar icon and closes with Esc or a click outside. Every tab has been restyled, and the glow at the top of the panel warms toward red as your current session nears its limit. Right-click the menu bar icon for Refresh, Settings and Quit.

Accounts that are not active now have a **Switch** button right on the Usage tab, and the Usage tab shows each account's name with its email underneath.

### The model-specific weekly limit (Fable)

Anthropic now applies a third limit: a weekly quota for a single model, such as Fable. CCSwitcher shows it next to the session and weekly limits — in the widget, on the Usage tab, and as optional menu bar items (off by default). Accounts without this limit look exactly as before.

### Log in from any browser

While a login is waiting for you, **Copy Login URL** copies the sign-in link so you can open it in a different browser or profile, and **Cancel** stops the login.

### One email, several organisations

If the same email belongs to more than one Team or organisation, each one is now kept as its own account instead of overwriting the others.

### Usage history is kept for good

Usage and activity history now lives in a local database (`~/Library/Application Support/CCSwitcher/usage.sqlite`). Refreshes only write what changed, instead of rewriting a cache file that could exceed 100 MB, and history is no longer lost when Claude Code deletes old transcripts. Your existing history is imported automatically on first launch, and the old file is left in place.  

### Settings

- **Settings → General → System** lets you turn automatic update checks and automatic downloads on or off.
- The General tab is shorter: refresh and auto-switch share one section, and *Show full email address* moved under Appearance.
- Español is now available as an interface language.

### Anonymous launch counts

CCSwitcher now sends one anonymous "app launched" event to [Aptabase](https://aptabase.com), together with Aptabase's standard technical details such as the app and macOS version. No account data, credentials, conversations or usage figures are sent. You can turn it off in **Settings → About → Send anonymous launch counts**; the change applies from the next launch.

### Fixes

- The menu bar could freeze for up to a minute right after launch while the widget's data was being saved for the first time.
- A switch to an account whose saved login had become empty is now refused before anything is changed, and a switch that fails part-way puts your previous account back instead of signing you out of both.
- While another Claude Code session was running, usage could be shown on the wrong account card, and a switch could save one account's login under another account's name.
- The app could hang while waiting for the `claude` command when that command printed a lot of output.
- Usage lines containing certain Unicode characters were skipped and are now counted.
- Quitting no longer waits indefinitely for a slow save.

### Thanks

- **[@mcnaveen](https://github.com/mcnaveen)** — the new panel design and the Switch button on the Usage tab ([#42](https://github.com/XueshiQiao/CCSwitcher/pull/42)).
- **[@chang-feather](https://github.com/chang-feather)** — the model-specific weekly limit and the launch freeze fix ([#31](https://github.com/XueshiQiao/CCSwitcher/pull/31)).
- **[@rakei076](https://github.com/rakei076)** — tracking which account a login really belongs to ([#25](https://github.com/XueshiQiao/CCSwitcher/issues/25), [#26](https://github.com/XueshiQiao/CCSwitcher/pull/26)).
- **[@fahrulalwan](https://github.com/fahrulalwan)** — refusing empty saved logins and rolling back failed switches ([#32](https://github.com/XueshiQiao/CCSwitcher/pull/32)).
- **[@ercgn](https://github.com/ercgn)** — finding the oversized cache rewrites and the quit hang ([#39](https://github.com/XueshiQiao/CCSwitcher/pull/39)).
- **[@ANGELBERRIOS23](https://github.com/ANGELBERRIOS23)** — the Spanish translation ([#27](https://github.com/XueshiQiao/CCSwitcher/pull/27)).
- **[@timc13](https://github.com/timc13)**, **[@roc-zjp](https://github.com/roc-zjp)** and **[@alekc](https://github.com/alekc)** — for suggesting login from another browser ([#33](https://github.com/XueshiQiao/CCSwitcher/issues/33)), multi-organisation accounts ([#24](https://github.com/XueshiQiao/CCSwitcher/pull/24)) and the update settings ([#36](https://github.com/XueshiQiao/CCSwitcher/issues/36)).

---

### 菜单栏面板换了新样子

下拉菜单改成了 Claude 配色的浮动面板：暖白和深炭灰的底色，配上陶土橙的点缀。面板从菜单栏图标下方弹出，按 Esc 或点击面板外面就会关闭。所有标签页都重新设计过，面板顶部的光晕会随着当前会话接近限额逐渐变红。右键点击菜单栏图标，可以直接刷新、打开设置或退出。

用量标签页上，不是当前账户的卡片现在多了一个**切换**按钮；每个账户会显示名字，邮箱显示在名字下面。

### 单个模型的每周限额（Fable）

Anthropic 现在多了第三种限额：针对单个模型（例如 Fable）的每周额度。CCSwitcher 会把它和会话限额、每周限额放在一起显示：小组件里有，用量标签页里有，菜单栏上也可以选择显示（默认不显示）。没有这项限额的账户，显示和以前完全一样。

### 可以用任意浏览器登录

等待登录的时候，点 **Copy Login URL**（复制登录链接）可以把登录地址复制下来，拿到别的浏览器或别的浏览器账户里打开；点**取消**可以中止这次登录。

### 同一个邮箱属于多个组织

同一个邮箱如果同时属于多个 Team 或组织，现在每个组织会作为单独的账户保存，不会再互相覆盖。

### 用量历史会一直保留

用量和活动历史现在存放在本地数据库里（`~/Library/Application Support/CCSwitcher/usage.sqlite`）。每次刷新只写入有变化的部分，不再整份重写一个可能超过 100 MB 的缓存文件；Claude Code 删掉旧的对话记录之后，这些对话的用量历史也不会跟着消失。第一次启动新版本时会自动导入原有的历史数据，原来的文件会原样保留。

### 设置

- **设置 → 通用 → 系统**里可以分别开关「自动检查更新」和「自动下载更新」。
- 通用标签页变短了：刷新间隔和自动切换放在同一组里，「显示完整邮箱地址」移到了「外观」下面。
- 界面语言新增西班牙语（Español）。

### 匿名统计启动次数

CCSwitcher 现在会向 [Aptabase](https://aptabase.com) 发送一个匿名的「App 已启动」事件，附带 Aptabase 默认收集的技术信息，比如 App 版本和 macOS 版本。不会发送任何账户信息、登录凭据、对话内容或用量数据。可以在**设置 → 关于 → 发送匿名启动统计**中关掉，关掉后从下次启动开始生效。

### 缺陷修复

- 刚启动时，小组件数据第一次保存期间，菜单栏可能卡住长达一分钟。
- 如果某个账户保存的登录信息已经变成空的，切换到这个账户时会在改动任何东西之前直接拒绝；切换中途失败时，会把原来的账户恢复回去，不会再让两个账户都退出登录。
- 有其他 Claude Code 会话在运行时，用量可能显示到错误的账户卡片上，切换时也可能把一个账户的登录信息存到另一个账户名下。
- 当 `claude` 命令输出内容很多时，App 可能一直卡在等待这个命令结束。
- 含有某些 Unicode 字符的用量记录以前会被漏掉，现在能正确统计。
- 退出 App 时不会再因为保存数据太慢而一直等下去。

### 致谢

- **[@mcnaveen](https://github.com/mcnaveen)** —— 新的面板设计，以及用量标签页上的切换按钮（[#42](https://github.com/XueshiQiao/CCSwitcher/pull/42)）。
- **[@chang-feather](https://github.com/chang-feather)** —— 单个模型的每周限额，以及修复启动时菜单栏卡住的问题（[#31](https://github.com/XueshiQiao/CCSwitcher/pull/31)）。
- **[@rakei076](https://github.com/rakei076)** —— 准确判断当前登录信息属于哪个账户（[#25](https://github.com/XueshiQiao/CCSwitcher/issues/25)、[#26](https://github.com/XueshiQiao/CCSwitcher/pull/26)）。
- **[@fahrulalwan](https://github.com/fahrulalwan)** —— 拒绝切换到登录信息为空的账户，切换失败时自动恢复（[#32](https://github.com/XueshiQiao/CCSwitcher/pull/32)）。
- **[@ercgn](https://github.com/ercgn)** —— 发现缓存文件被反复整份重写和退出时卡住的问题（[#39](https://github.com/XueshiQiao/CCSwitcher/pull/39)）。
- **[@ANGELBERRIOS23](https://github.com/ANGELBERRIOS23)** —— 西班牙语翻译（[#27](https://github.com/XueshiQiao/CCSwitcher/pull/27)）。
- **[@timc13](https://github.com/timc13)**、**[@roc-zjp](https://github.com/roc-zjp)** 和 **[@alekc](https://github.com/alekc)** —— 分别提出了用其他浏览器登录（[#33](https://github.com/XueshiQiao/CCSwitcher/issues/33)）、同一邮箱多个组织（[#24](https://github.com/XueshiQiao/CCSwitcher/pull/24)）和更新设置（[#36](https://github.com/XueshiQiao/CCSwitcher/issues/36)）的建议。

---

**Full Changelog**: https://github.com/XueshiQiao/CCSwitcher/compare/v1.12.0...v2.0.0
