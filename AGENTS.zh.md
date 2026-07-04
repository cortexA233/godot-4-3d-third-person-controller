# AGENTS.zh.md

这是 `AGENTS.md` 的中文预览译本。正式代理指令仍保留在英文版
`AGENTS.md` 中；如果两个版本出现差异，以英文版为准。

## 项目目标

这个仓库是一个 take-home assignment 工作区。目标不只是修改 RoboBlast
游戏本身，而是完成 `game_take_home.html` 中描述的作业。

把 `game_take_home.html` 当作事实来源。简而言之，你需要基于这个真实的
Godot 游戏构建一个 agent-coding 评估任务：

- 选择一个足够实质性的游戏元素。
- 在一个干净的 ablated task 分支上移除或禁用它。
- 为 rollout agent 编写只描述行为的规格说明。
- 构建一个确定性的 headless verifier，对 agent 尝试按 100 分制评分。
- 至少运行 3 次 coding agent 来解决 ablated task。
- 对尝试结果评分、分析失败，并发布一个可直接浏览的 HTML writeup。

verifier 和评估流程是最主要的交付物。一个聪明的游戏功能改动不如一个诚实、
可复现的 grader 重要。

## 游戏背景

- 项目：RoboBlast: Third-Person Shooter demo。
- 引擎：Godot 4.6。这个项目固定使用 Godot 4.6；除非用户明确要求，否则不要把
  项目、verifier、本地工具或分支设置切换到其他 Godot 版本。记录 verifier
  运行时使用的精确 Godot 4.6 build 和命令。
- 主场景：`res://main.tscn`。
- 核心玩法区域：
  - `player/`：角色控制器、摄像机、武器、手雷、金币、HUD。
  - `enemies/`：bee 和 beetle 机器人、敌人行为、击败效果。
  - `box/`：可破坏箱子的行为。
  - `jumping_pad/`：跳台行为和视觉表现。
  - `environment/`、`level/`、`shared/`：世界、材质、shader、navmesh
    和共享资源。

## 工作规则

- 让改动严格服务于当前正在处理的作业步骤。
- 保留已有的用户改动。除非明确要求，不要 reset、checkout 或 revert
  不相关文件。
- 对场景和资源改动，优先使用 Godot 编辑器或可用的 Godot MCP 操作。只有在
  diff 很小且你理解序列化格式时，才手动编辑 `.tscn` 或 `.tres` 文件。
- 当资源或脚本需要时，保持 Godot 生成的 sidecar 文件同步，尤其是 `.uid`
  和 `.import` 文件。
- 构建 eval task 时不要引入大范围重构。这个作业奖励的是干净、可理解的
  end-to-end slice。
- 修改 `C:\recent_project\roboblast-grenade-verifier` 里的 verifier 仓库时，
  也要在那个 verifier 仓库中提交这些改动。
- 在英文源文档之后新增或更新的中文文档，包括 `AGENTS.zh.md`，是给用户看的
  个人预览译本。除非用户明确要求提交，否则不要提交这些中文预览文档。
- 尽量使用带类型的 GDScript，并遵循本地风格：用 `@export` 暴露可调参数，
  用 `@onready` 获取节点引用，用 signal 表达玩法事件，用 `res://` 路径
  引用项目资源。

## 作业分支模型

为主要交付物使用独立分支或干净 worktree：

- Original/reference 分支：未 ablate 的游戏，用来证明 verifier 可以通过真实
  行为。
- Ablated task 分支：rollout agent 实际看到的版本。它应该包含被移除或禁用的
  功能和行为规格说明，但不能包含原始实现、verifier、答案提示或明显 stub。
- Verifier 分支或私有 verifier 工作区：包含 grader 和 anti-cheat probes。
  Rollout agent 不能读取这些内容。
- Agent-run 分支：最好每次 rollout attempt 使用一个单独分支。记录 agent、
  model/version、工具、prompt/spec、diff、verifier score 和备注。
- Report 分支或最终交付分支：包含可直接浏览的 HTML writeup，以及各次运行的
  链接或证据。

评估完整性很重要。在启动 rollout agent 前，要确认它的 workspace 无法通过
git history、其他分支、remote、verifier 文件、隐藏本地文件或在线副本访问
原始解法。

## 选择并 Ablate 任务

- 选择一个完整行为或元素，并确保它有足够深度可以评分。合适目标包括战斗行为、
  敌人行为、手雷瞄准/轨迹、金币收集、跳台行为、可破坏箱子、HUD 状态、动画、
  shader、VFX、音频或某个视觉效果。
- 优先选择有可观察视觉或玩法结果的任务。视觉正确性对 agent 更难，也能帮助
  校准难度。
- ablation 必须完整。不要留下注释掉的源码、实现线索、重命名的原文件或
  过于明显的 stub。
- 给 agent 的规格说明只能描述行为。描述玩家看到或体验到什么。不要提到文件名、
  class 名、method 名、node path、signal、resource path 或精确实现细节。

## Verifier 要求

verifier 是这个项目的核心。

- 它必须能 headless 运行，并包含运行它所需的精确命令。
- 它必须运行真实游戏系统，而不是检查某种特定代码形状。
- 它必须按 100 分制评分，并为不同子行为提供有意义的部分分。
- 它必须让 original/reference 行为通过，并让 ablated 版本失败。
- 它必须是确定性的：在相关场景中控制 timing、random seed、test scene setup
  以及 camera/viewport 假设。
- 它必须避免对有效的替代实现产生 false negative。
- 它必须拒绝 near-miss 或 reward-hacking 实现。保留 anti-cheat probes 来
  证明这一点。
- 对视觉特性，尽可能使用 rendered-frame 或 screenshot-based 检查；只有当
  state 本身确实属于玩家可见行为时，才结合 state 检查。

一个强 verifier 应该让强 rollout agent 落在部分得分区间，而不是轻松 100 分，
也不是总是 0 分。如果 agent 很容易拿到 100 分，就提高任务难度或改进评分维度。

## 运行 Rollout Agents

- 只给 rollout agent ablated project 和行为规格说明。
- 不要给它原始实现、verifier、anti-cheat probes、隐藏分支或报告笔记。
- 作业至少要求 Claude Code，并至少运行 3 次。也欢迎使用更多 agent。
- 在可用时，为 rollout agent 提供 Godot MCP 访问权限，让它能检查并运行真实
  项目。
- 捕获每次运行的最终 diff、score、值得注意的行为和 failure mode。

## 报告要求

最终报告应是一个可浏览的 HTML 文件，可以直接在浏览器打开，不需要 build step。

需要包含：

- 选择的功能，以及为什么它是一个好的评估任务。
- ablated 的内容，以及给 agent 的行为规格说明。
- verifier 设计、评分 rubric 和精确运行命令。
- verifier 通过 original、失败 ablated 的证据。
- anti-cheat probes 和结果。
- 至少 3 次 rollout attempts，并包含 diffs/scores/tooling。
- failure analysis：区分真实 agent 缺陷和 verifier artifact。
- 有帮助时加入视觉材料，例如截图、短片或 before/after 对比。

## 有用的本地检查

优先使用这台机器上配置好的 Godot 可执行文件或 MCP 设置。如果 Godot 在 PATH 中，
常用 smoke check 可能类似：

```powershell
godot --headless --path . --quit
godot --headless --path . --script res://path/to/verifier.gd
```

如果使用本地 Codex MCP 配置，查看 `.codex/config.toml` 来确认 Godot binary
路径和 Godot MCP server 设置。
