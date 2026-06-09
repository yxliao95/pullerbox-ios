# 计划训练（Planned Training）工程设计指南

相关文档：

- 路线图：`../plans/planned-training-roadmap.md`
- UI 设计：`../ui/planned-training-ui-guide.md`

本文档面向开发工程师和 AI 开发代理，定义计划训练（Planned Training）的领域模型、有效性规则、执行规则、状态口径和统计口径。

实现必须遵循 `../01-architecture.md`：SwiftUI + MVVM + Repository + Service + Store。

## 架构边界

- View 只负责界面展示和用户交互。
- ViewModel 负责页面状态、用户操作、训练流程编排和数据转换。
- ViewModel 只依赖 RepositoryProtocol。
- Domain Model 表达训练计划、动作、执行快照、采样、摘要等业务含义，不依赖 SwiftUI、CoreBluetooth 或本地存储实现。
- Repository 组合 Store 和 Service，向 ViewModel 提供稳定接口。
- Store 负责本地持久化。
- Service 负责蓝牙、系统 API 等底层能力。

## 核心模型

### 训练计划（TrainingPlan）

训练计划由计划级步骤序列组成：

```text
TrainingPlan
  id
  name
  steps:
    - interval
    - actionGroup
    - interval
    - actionGroup
```

### 动作组（ActionGroup）

动作组只存在于训练计划内部，不是独立库对象：

```text
ActionGroup
  id
  title: String?
  steps:
    - interval
    - action
    - interval
    - action
  groupRestSeconds
  cycles
```

### 动作（Action）

动作是独立库对象。第一阶段只支持 timed reps：

```text
Action
  id
  name
  type: timed_reps
  targetReps
  workSecondsPerRep
  restSecondsBetweenReps
```

### 计划间隔（IntervalStep）

```text
IntervalStep
  id
  title: String?
  durationSeconds
```

### 动作引用（ActionReference）

训练计划引用动作 ID，不复制动作内容。开始训练时再解析引用并生成只读执行快照。

## 命名与有效性

- `TrainingPlan.name` 必填，并且在计划库内唯一。
- `Action.name` 必填，并且在动作库内唯一。
- `ActionGroup.title` 可选，不要求唯一。
- `IntervalStep.title` 可选，不要求唯一；为空时显示为“间隔”。
- 计划库和动作库都允许为空。
- 编辑过程中允许临时无效状态，例如空计划、空动作组。
- 保存计划时必须有效。
- 外部变化可以让已有计划变无效，例如删除被引用动作。

计划保存的最小有效规则：

- 至少有 1 个 `actionGroup` step。
- 至少有 1 个有效动作引用。
- 每个 `ActionGroup` 至少包含 1 个有效动作。
- `cycles >= 1`。
- 时间和次数满足字段范围。

字段范围：

```text
targetReps: 1...200
workSecondsPerRep: 1...600
restSecondsBetweenReps: 0...600
intervalSeconds: 1...3600
groupRestSeconds: 0...3600
cycles: 1...100
```

## 计划编排规则

- 训练计划（TrainingPlan）和动作组（ActionGroup）都采用步骤序列模型。
- `interval` 可以出现在步骤序列开头、结尾或中间。
- 允许连续 `interval`。
- 连续 `interval` 保留为多个独立阶段，不自动合并。
- 每个 `interval` 都独立倒计时、独立显示名称、独立重置阶段曲线视窗。
- `IntervalStep.durationSeconds >= 1`。

动作组循环规则：

- `ActionGroup.steps` 是一个 cycle 的完整内容。
- `cycles = N` 表示完整执行 `steps` N 次。
- 动作组内所有 steps 每个 cycle 都执行。
- `groupRestSeconds` 只发生在 cycle 之间，不发生在最后一轮之后。
- `groupRestSeconds = 0` 时跳过组间休息阶段。
- `groupRest` 不单独命名，训练中统一显示“组间休息”。

timed reps 动作执行规则：

- 每个 rep 包含 `workSecondsPerRep`。
- `restSecondsBetweenReps` 只发生在 rep 之间，不发生在最后一个 rep 后。
- `restSecondsBetweenReps = 0` 时跳过 rep rest 阶段。
- `targetReps` 和 `workSecondsPerRep` 都为正整数。

预计训练时间静态计算：

```text
actionDuration =
  targetReps * workSecondsPerRep
  + (targetReps - 1) * restSecondsBetweenReps

actionGroupDuration =
  oneCycleDuration * cycles
  + groupRestSeconds * (cycles - 1)

planDuration =
  sum(plan.steps)
```

预计训练时间不包含暂停、意外暂停、恢复倒计时和提前结束造成的差异。

## 动作库与计划库

动作库（Action Library）支持：

- 新增动作。
- 编辑动作。
- 删除动作。
- 编辑或删除时列出受影响训练计划。

计划库（TrainingPlan Library）支持：

- 新增计划。
- 编辑计划。
- 删除计划。
- 选择当前计划。
- 显示所有计划，包括无效计划。

动作引用规则：

- 训练计划引用动作 ID。
- 修改动作会影响引用它的训练计划。
- 保存已被引用的动作前，需要提醒用户并列出受影响计划。
- 保存已被引用动作时，业务操作包括：保存并更新训练计划、保存为新动作、取消。
- 选择“保存为新动作”只创建新动作，不修改任何已有训练计划。
- 删除被引用动作时允许删除；确认前列出受影响计划，删除后相关计划变为无效。

无效计划规则：

- 保留可见。
- 不可开始训练。
- 可编辑修复。
- 缺失动作位置支持替换动作或移除此步骤。
- 当前计划变无效时，保留 `currentPlanId`，首页显示无效原因和修复入口。

当前计划规则：

- 新建计划保存后，新计划成为当前计划。
- 编辑当前计划保存后，当前计划保持不变。
- 编辑非当前计划保存后，不切换当前计划。
- 删除当前计划后，清空当前选择，不自动切换到其他计划。

## 训练首页状态

训练首页以当前训练计划为中心。

计划库为空：

```text
暂无训练计划
主操作：新建计划
```

计划库非空但未选择当前计划：

```text
未选择训练计划
主操作：选择计划
次操作：新建计划
```

已选择有效计划：

```text
显示计划名称
显示动作数量
显示预计训练时间
显示设备状态
主操作：开始训练
次入口：编辑计划、切换计划、计划库、动作库
```

已选择无效计划：

```text
显示计划名称
显示无效原因
主操作：修复计划
次操作：选择其他计划
开始训练不可用
```

未连接设备时开始训练不弹二次确认，直接进入计时模式（timerOnly）。

## 训练开始与执行快照

开始训练时：

1. 校验当前计划有效。
2. 解析所有动作引用。
3. 生成完整训练执行快照（TrainingExecutionSnapshot）。
4. 根据设备连接状态确定测量模式（measurementMode）。
5. 直接进入计划第一个步骤。

训练开始前没有系统级准备倒计时。如果需要准备时间，用户应在计划开头添加 `interval`。

训练开始后：

- `TrainingExecutionSnapshot` 只读。
- 不允许修改计划或动作参数。
- 不允许调整剩余 reps、cycles、work、rest。
- 不允许跳过当前阶段。

## 测量模式

训练开始时确定测量模式（measurementMode）：

```text
forceDevice
timerOnly
```

训练开始后测量模式固定：

- 计时模式（timerOnly）不能中途切换为拉力计模式（forceDevice）。
- 拉力计模式（forceDevice）断连后进入意外暂停，不降级为计时模式（timerOnly）。

拉力计模式（forceDevice）：

- 显示实时力量读数。
- 绘制阶段曲线。
- 保存力量采样。
- 摘要包含力量统计。

计时模式（timerOnly）：

- 只执行训练倒计时。
- 不显示实时力量读数。
- 不绘制曲线。
- 不保存力量采样。
- 摘要不显示拉力计相关统计。

## 训练阶段

训练执行页需要支持这些阶段：

```text
work
repRest
interval
groupRest
paused
resumeCountdown
```

训练中只支持：

- 暂停。
- 恢复。
- 结束。

手动结束训练需要确认。确认后进入未保存摘要页。

计划自然完成后自动进入未保存摘要页。

## 实时曲线规则

拉力计模式（forceDevice）下，以下阶段绘制曲线：

- work。
- rep rest。
- interval。
- group rest。

`paused` 阶段不绘制曲线，显示静止暂停画面。

每个非暂停阶段：

- 阶段开始时重置 X 轴视窗。
- 清空当前阶段曲线数据。
- X 轴最大值为当前阶段计划时长。

Y 轴：

- 训练开始时 `yMax = 10kg`。
- 整场训练中只增不减。
- 如果当前读数超过 `yMax * 0.7`，则 `yMax += 10kg`。
- 阶段切换不重置 Y 轴。

视觉和统计口径：

- work 阶段显示主曲线，并参与动作表现统计。
- rep rest、interval、group rest 显示弱化曲线，保存采样，但默认不参与动作表现统计。

## 暂停与恢复

支持主动暂停和意外暂停。

暂停期间：

- 拉力计模式（forceDevice）下继续保存采样，标记为 `paused`。
- paused samples 默认不参与训练统计。
- 页面显示静止暂停画面，不绘制曲线。

拉力计模式（forceDevice）下设备断连：

- 自动进入意外暂停。
- 标记发生过意外暂停。
- 恢复前必须重新连接设备。

work 阶段被中断时，无论主动暂停还是意外暂停：

- 丢弃当前 work 阶段数据。
- 当前 rep 不算完成。
- 恢复前先 3 秒倒计时。
- 重新开始该 work 阶段。

非 work 阶段被暂停时：

- 保留该阶段剩余时间。
- 恢复前先 3 秒倒计时。
- 继续剩余倒计时。

上述规则同时适用于拉力计模式（forceDevice）和计时模式（timerOnly）。计时模式虽然没有采样，但 work 被中断后仍重启当前 work，以保持完成口径一致。

恢复倒计时：

- 计入总时间。
- 不计入训练时间。
- 不参与动作统计。

## 训练结束与保存

第一阶段结束原因：

```text
completed
  计划自然完成

stoppedByUser
  用户手动结束

stoppedAfterUnexpectedPause
  意外暂停后用户选择结束
```

训练结束后：

1. 生成摘要。
2. 展示未保存摘要页。
3. 用户手动保存或丢弃。

保存：

```text
保存训练记录
返回训练首页
```

不保存：

```text
先确认
确认后丢弃
返回训练首页
```

取消不保存：

```text
留在摘要页
```

## 训练记录与摘要统计

训练记录保存：

- 训练执行快照。
- 开始和结束时间。
- 测量模式。
- 采样数据，计时模式（timerOnly）无采样。
- 暂停事件明细。
- 摘要统计。
- 计划预计时长。
- 实际总时间。
- 实际训练时间。

时间字段：

```text
plannedDuration
  训练开始时由执行快照静态计算

totalElapsedDuration
  从开始到结束的墙钟时间
  包含暂停、意外暂停、恢复倒计时

activeTrainingDuration
  实际执行训练内容的时间
  不包含暂停、意外暂停、恢复倒计时

pauseDuration
  totalElapsedDuration - activeTrainingDuration
```

摘要基础字段，所有测量模式都显示：

- 总时间。
- 训练时间。
- 暂停时长。
- 包含动作数。
- 按动作统计的完成组数。
- 按动作统计的未完成组数。
- 按动作统计的完成 reps。
- 按动作统计的组间休息时间。

拉力计模式（forceDevice）额外显示：

- 最大力量。
- rep 级力量统计。

计时模式（timerOnly）不显示：

- 当前力量。
- 最大力量。
- 曲线。
- rep peak。

“包含动作数”按本次训练涉及的唯一 action ID 数量统计。

## 统计口径

一次 action step 在某个 cycle 中完整执行一次，算该动作完成 1 组。

```text
ActionExecution
  = 一次 action step 在某个 cycle 中被执行
  = 该动作的一组

RepExecution
  = ActionExecution 内的一次 rep
```

如果同一个动作在计划中出现多次：

- 摘要主视图按唯一 action ID 合并统计。
- 底层数据保留每次 action execution 的计划位置，便于未来展开。

提前结束时：

```text
completedSets
  完整完成 targetReps 的 action execution

partialSets
  已开始但未完整完成 targetReps 的 action execution

completedReps
  完整完成 work 阶段的 rep

interruptedRep
  在 work/rest 中被结束或中断的 rep 位置和已执行时长
```

统计层级：

```text
RepSummary
  setIndex
  repIndex
  completed
  peakForce?        // forceDevice only
  averageForce?     // forceDevice only
  workDuration

ActionExecutionSummary
  actionId
  actionGroupId
  planStepIndex
  cycleIndex
  actionStepIndex
  repSummaries

ActionSummary
  actionId
  actionName
  completedSets
  partialSets
  completedReps
  groupRestSeconds[]
  peakForce?        // forceDevice only

TrainingSummary
  plannedDuration
  totalElapsedDuration
  activeTrainingDuration
  pauseDuration
  uniqueActionCount
  actionSummaries
```

第一阶段不设计、不保存、不展示力竭信号字段。

## 测试建议

至少覆盖：

- 计划保存有效性。
- 动作名称和计划名称唯一性。
- 删除被引用动作后计划变无效。
- 编辑被引用动作时的更新和另存路径。
- 当前计划删除后清空选择。
- 无效当前计划不可开始。
- 训练开始生成只读执行快照。
- 计时模式和拉力计模式开始后不切换。
- 拉力计模式断连进入意外暂停。
- work 暂停后重启当前 work，且当前 rep 不算完成。
- 非 work 暂停后继续剩余时间。
- 恢复倒计时计入总时间但不计入训练时间。
- 手动结束和自然完成都进入未保存摘要。
- 保存和丢弃摘要行为。
- 同一动作多次出现时摘要合并。

