# SQLite 用量数据库设计

本方案将 CCSwitcher 的历史用量和活动统计从整份 JSON 保存改为 SQLite 局部更新。数据库是长期保留的统计资料，不采用缓存过期、源文件消失后自动删除或升级清库的策略。

## 范围与存储分工

使用 GRDB 7.10.0，与 Swift 版 PastePawX 一致。Windows 版 PastePaw 使用 sqlx，不直接复用其 Rust 实现。

| 数据 | 存储位置 |
|---|---|
| 历史用量与活动统计 | `~/Library/Application Support/CCSwitcher/usage.sqlite` |
| 账号资料 | 保留 UserDefaults 中的 JSON 数据 |
| 登录凭据及凭据备份 | 保留现有 Keychain，不改变访问或迁移逻辑 |
| 语言、刷新频率、自动切换和菜单栏外观 | 保留 UserDefaults / AppStorage |
| Widget 展示快照 | 保留 App Group 中的 widget-data.json |
| 定价数据 | 保留现有 PricingService |

原始 `~/.claude/projects/**/*.jsonl` 只读。数据库包含两张业务表；GRDB 另外管理自己的迁移记录表。WAL 模式还会使用数量固定的 `-wal` 和 `-shm` 文件。

## 类型约定

`INTEGER` 使用 64 位整数。布尔值限定为 0/1。`*_us` 是 UTC Unix 微秒；`source_mtime_ns` 是文件修改时间的纳秒表示，精度受文件系统和读取 API 限制。JSON 存为合法对象形式的 TEXT。NULL 表示未知，不能编造旧数据缺失的时间、时区或账号归属。

## session_files

每个原始 JSONL 文件对应一行，不将主会话和子代理文件强行合并。

| 字段 | 类型 | 含义 |
|---|---|---|
| id | INTEGER PRIMARY KEY | 内部关联 ID |
| provider | TEXT NOT NULL | 来源，当前为 claude |
| root_path | TEXT NOT NULL | 展开后的数据根目录 |
| relative_path | TEXT NOT NULL | 相对根目录的文件路径 |
| project_key | TEXT NOT NULL | 项目目录标识 |
| session_id | TEXT NULL | 原始会话标识 |
| is_sidechain | INTEGER NOT NULL DEFAULT 0 | 是否为子代理文件 |
| source_mtime_ns | INTEGER NULL | 上次成功同步内容的文件修改时间 |
| source_size_bytes | INTEGER NULL | 上次成功同步内容的文件大小 |
| earliest_timestamp_us | INTEGER NULL | 最早有效时间，NULL 排在有效时间之后 |
| parser_version | INTEGER NOT NULL | 解析器版本；0 为旧 JSON 导入待核验状态 |
| statistics_timezone | TEXT NULL | 日期和活动分组时区；旧 JSON 未记录时保留 NULL |
| source_status | TEXT NOT NULL | present、missing 或 needs_review |
| activity_by_date_json | TEXT NOT NULL | 该文件贡献的每日活动统计 |
| extensions_json | TEXT NOT NULL | 文件级扩展对象，默认 {"_v":1} |
| created_at_us | INTEGER NOT NULL | 首次入库时间 |
| updated_at_us | INTEGER NOT NULL | 行内容最后变化时间 |

唯一约束：`(provider, root_path, relative_path)`。未变化的文件不更新访问时间或扫描时间。extensions_json 保存文件系统的设备、文件编号和创建时间，用于识别同一文件的移动。确认移动时事务更新原行的路径，不新增第二份活动统计；身份不明确的替换或复制进入 needs_review。

活动 JSON 结构：

```json
{"_v":1,"days":{"2026-10-25":{"turns":12,"active_minutes":48,"lines_written":230,"tool_counts":{"Bash":8,"Edit":15},"model_counts":{"Opus":6}}}}
```

活动统计来自所有相关对话事件，不能仅根据带 Token 用量的响应重建。`active_minutes` 和 `lines_written` 仍是当前算法的估算值。

## usage_records

保存每个源文件内去重后的用量条目。跨文件候选均保留，在查询时全局去重。

| 字段 | 类型 | 含义 |
|---|---|---|
| id | INTEGER PRIMARY KEY | 内部记录 ID |
| file_id | INTEGER NOT NULL REFERENCES session_files(id) ON DELETE RESTRICT | 来源文件 |
| record_key | TEXT NOT NULL | 文件内稳定标识，用于幂等更新 |
| dedup_key | TEXT NULL | 消息 ID 与请求 ID 组合，用于跨文件去重 |
| source_order | INTEGER NOT NULL | 解析条目在文件内的顺序 |
| timestamp_us | INTEGER NULL | 原始响应 UTC 时间，旧数据允许缺失 |
| local_date | TEXT NOT NULL | 已记录的 YYYY-MM-DD 日期 |
| model | TEXT NOT NULL | 完整模型名 |
| speed | TEXT NULL | standard、fast 或未提供 |
| input_tokens | INTEGER NOT NULL | 输入 Token |
| output_tokens | INTEGER NOT NULL | 输出 Token |
| cache_creation_tokens | INTEGER NOT NULL | 提示词缓存创建 Token 总量 |
| cache_creation_1h_tokens | INTEGER NOT NULL | 创建总量中属于一小时缓存的部分 |
| cache_read_tokens | INTEGER NOT NULL | 提示词缓存读取 Token |
| extensions_json | TEXT NOT NULL | 小时、工具、代码行数和原始 reported cost 等扩展 |
| created_at_us | INTEGER NOT NULL | 首次入库时间 |
| updated_at_us | INTEGER NOT NULL | 内容最后变化时间 |

唯一约束：`(file_id, record_key)`。dedup_key 只建立普通索引，不能全局唯一。

有标识的 record_key 根据 dedup_key 生成；缺少标识的条目使用文件内匿名条目序号。匿名条目不跨文件去重。重新解析时若不能可靠对应旧条目，保留旧数据并标记 needs_review。

`cache_creation_1h_tokens` 已包含在创建总量中，不能在总 Token 中重复相加。SQLite 中的这些 cache 字段描述模型提示词缓存，不表示本地数据可被清理。

## 扩展规则

核心计算、过滤、排序使用固定列。可选或不固定的信息存 extensions_json，带 `_v`。读写保留未知键；扩展成为高频查询字段后通过新迁移提升为正式列。不把整个会话的用量数组放入一个 JSON 列。

## 首次迁移

1. 首次初始化通过一次性数据迁移读取旧 session-parse-cache-v2.json，校验格式和版本。
2. 在事务中导入全部文件、用量和活动数据，保留扩展内容。
3. 缺失的原始 UTC 时间和时区保留 NULL，原始修改时间保存在导入元信息中。
4. 再扫描仍存在的原始文件，核验稳定标识后补充信息，不把两套数据重复相加。
5. 导入失败时回滚并报告，不将无法读取的旧 JSON 当成空数据覆盖。
6. 原 JSON 保留，停止向其写入。已有 SQLite 数据不被旧 JSON 反复覆盖。

导入完成回执由 GRDB 的数据迁移记录管理，与业务行数无关；导入和回执在同一事务完成。即使导入为空或日后用户删除全部业务数据，也不重新导入旧 JSON。中断后可以继续。无法从已经删除且旧 JSON 也未保留的数据恢复历史。

## 刷新和更新

检查文件修改时间、大小和解析器版本。未变化时跳过。第一阶段仍完整解析发生变化的文件，避免同时改变存储和 JSONL 增量解析算法。

新增文件插入文件行和条目。已有文件通过 record_key 比较：新增条目 INSERT，变化条目 UPDATE，相同条目不写入。使用 UPSERT，不采用 DELETE 全部再重新 INSERT。

一批文件变化中，用量差异、完整的单文件活动结果和成功同步签名在事务中提交。事务失败时保留旧签名以便重试。活动 JSON 是替换该文件完整结果，不是在旧汇总上再次累加。

源文件确认消失时标记 missing，仍计入历史。源目录无法访问不能触发批量 missing。文件异常截断、身份变化、旧条目丢失或匿名条目无法对应时标记 needs_review，保留旧内容并报告。读取中发生变化的文件推迟重试，不提交混合快照。

## 查询与功能

| 功能 | 数据来源 |
|---|---|
| 今日与每日费用 | usage_records 全局去重后逐条计价再按日期汇总 |
| 模型费用、各类 Token | 去重后按日期和模型汇总 |
| 会话数 | 胜出条目所属 session_id 去重，缺失时回退文件路径 |
| 今日对话、活跃分钟、代码行数 | 非子代理 session_files 的活动 JSON |
| 工具和模型使用次数 | 合并当天活动 JSON 字典 |
| Widget | 查询结果生成现有小型展示快照 |

全局去重按 provider 和 dedup_key 分组，输出 Token 最大者胜出。相同输出按文件最早有效时间、完整路径和条目顺序确定选择。NULL dedup_key 每条保留。先确定全局胜出记录，再过滤日期等范围。保留 synthetic 排除、单请求长上下文、fast 和一小时缓存计价规则。

费用在查询时使用同一份定价快照计算，不因定价更新改写历史 Token。统一的统计时区首次选定后保存在 UserDefaults，并在文件扩展元信息中保留恢复副本。解析、今日选择、最近七日窗口及 CostDetailView 日期标签使用同一时区，系统时区变化不静默改写历史日期。旧数据缺失时区时保留原日期和 NULL 时区，不伪造转换。

初始索引：文件身份唯一索引、文件与 record_key 唯一索引、dedup_key/output_tokens 普通索引、local_date 索引。

## 服务和生命周期

解析器负责 JSONL 到类型化结果；数据仓储负责 SQLite 事务、导入和查询；统计服务负责去重结果计价和界面模型。界面继续获取 CostSummary 和 ActivityStats，不直接使用 SQL。

一个共享 GRDB DatabasePool，WAL 模式，明确使用 synchronous=FULL。解析、迁移和数据库访问离开主线程。每次刷新批量提交，不逐行提交；不每次刷新 VACUUM、强制 checkpoint 或复制整库。不依赖退出时保存整份数据。

## 版本维护与保护

GRDB DatabaseMigrator 管理 schema 历史。已提交迁移不修改，只追加新的标识。迁移使用固定表列名，不依赖可变业务模型。schema 版本、parser_version 和 JSON `_v` 分别维护。

新结构被旧程序打开时拒绝写入并报告。数据库损坏、锁定、权限或版本错误不自动删库，不影响已有账号配置和 Keychain。迁移或用户导出时使用一致性备份；已提交历史只能由明确的用户删除操作移除。

不新增 account_id：当前 JSONL 缺少可靠账号归属依据，不能把当前登录账号当成全部历史的所有者。

## 验收与预计工作量

验证旧 JSON 导入幂等与独立回执、导入失败后重试、主动清空后的不复活、未知字段保留、匿名条目、跨文件去重和相同输出顺序、费用计价、活动排除子代理、移动源文件不重复计数、删除或截断源文件后的历史保留、扫描失败、事务回滚、迁移升级与未来版本拒绝。验证跨时区午夜时今日数字和界面日期一致。

在隔离目录测试，不运行用户真实数据库迁移。对相同输入比较旧计算和新实现的 Token、费用、会话及活动。验证未变化扫描零业务写入、单文件变化不重写全部历史。新增 100 MB 级数据集测试局部更新写入量。正式发布前执行成本核对，完成独立代码审查并修复 bug。

完整实现初估 4–6 个工程人日，包含迁移和验收；原始 JSONL 追加式解析是后续独立工作。

## 参考

- PastePawX: pastepaw-swift/PastePaw/Core/Database/AppDatabase.swift
- https://github.com/groue/GRDB.swift/blob/v7.10.0/GRDB/Documentation.docc/Migrations.md
- https://github.com/groue/GRDB.swift/blob/v7.10.0/GRDB/Documentation.docc/Concurrency.md
- https://www.sqlite.org/json1.html
- https://www.sqlite.org/pragma.html#pragma_synchronous
- https://www.sqlite.org/backup.html
