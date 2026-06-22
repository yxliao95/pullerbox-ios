# 训练计划

本文档整理 TrainingPlan 相关的稳定设计口径，面向产品、设计和开发协作使用。用户从哪里进入、训练中如何流转见 `02-user-flow.md`；训练结果如何计算力量指标见 `04-training-metric.md`。

## 成功标准

训练计划应帮助用户把可复用动作组织成一套可执行、可保存、可复现的训练内容。

设计和实现需要保证：

- 用户能清楚理解计划、动作组、动作和自定义倒计时之间的层级关系。
- 用户能创建、编辑、选择、删除训练计划。
- 无效计划保留可见，并给出修复路径。
- 训练开始后，本次训练使用只读执行快照，不受后续编辑影响。
- 保存的训练记录能还原本次执行时的训练内容，并支持后续摘要、详情和趋势分析。

## 核心对象

### TrainingPlan

训练计划是用户可选择并开始执行的训练内容。

它包含：

- `id`
- `name`
- `steps`

`steps` 是计划级步骤序列，步骤可以是：

- 自定义倒计时（customCountdown）
- 动作组（actionGroup）

### ActionGroup

动作组是训练计划内部的循环结构，不是独立库对象。

它包含：

- `id`
- `title`
- `steps`
- `groupRestSeconds`
- `cycles`

动作组的 `steps` 是一个 cycle 的完整内容。`cycles` 决定这组内容重复执行多少轮。

### Action

动作是独立库对象，可被多个训练计划引用。

当前动作以 timed reps 为主，包含：

- 动作名称。
- 目标 reps。
- 每次 rep 的 work 时长。
- rep 间休息时长。

训练计划引用动作 ID，不复制动作内容。开始训练时，系统解析动作引用并生成本次训练的只读执行快照。

### CustomCountdown

自定义倒计时是用户手动添加到训练计划或动作组中的倒计时步骤，例如准备、换手、上镁粉或额外休息。

它包含：

- `id`
- `title`
- `durationSeconds`

自定义倒计时不同于 rep 间休息和组间休息：

- 自定义倒计时来自用户显式添加。
- rep 间休息来自动作参数。
- 组间休息来自动作组参数。

## 层级结构

训练计划的结构可以理解为：

```text
TrainingPlan
  steps
    customCountdown
    actionGroup
      steps
        customCountdown
        action
      cycles
      groupRestSeconds
```

设计重点：

- 计划级步骤和动作组内部步骤要有清楚层级。
- 自定义倒计时和动作要视觉上可区分。
- 循环次数和组间休息属于动作组，不属于单个动作。
- rep 间休息属于动作，不属于动作组。

## 计划编排规则

训练计划和动作组都采用步骤序列模型。

自定义倒计时可以出现在训练计划或动作组步骤的开头、结尾或中间。

连续自定义倒计时不自动合并，应分别展示和执行。这样可以保留用户有意设计的不同阶段，例如“准备 10 秒”后接“上镁粉 5 秒”。

动作组循环规则：

- 动作组内部的 `steps` 是一个 cycle 的完整内容。
- `cycles = N` 表示完整执行 `steps` N 次。
- 动作组内所有步骤每个 cycle 都执行。
- `groupRestSeconds` 只发生在 cycle 之间，不发生在最后一轮之后。
- `groupRestSeconds = 0` 时跳过组间休息阶段。

timed reps 动作执行规则：

- 每个 rep 包含一次 work。
- `restSecondsBetweenReps` 只发生在 rep 之间，不发生在最后一个 rep 之后。
- `restSecondsBetweenReps = 0` 时跳过 rep 间休息阶段。

## 命名和有效性

计划名称必填，并且在训练计划库内唯一。

动作名称必填，并且在动作库内唯一。

动作组标题可选，不要求唯一。

自定义倒计时标题可选，不要求唯一；标题为空时，训练执行中显示为“自定义倒计时”。

编辑过程中允许出现临时无效状态。保存计划和开始训练前，计划必须有效。

计划保存的最小有效规则：

- 至少包含 1 个动作组。
- 至少包含 1 个有效动作引用。
- 每个动作组至少包含 1 个有效动作。
- 动作组 `cycles >= 1`。
- 所有时间、次数字段在允许范围内。

字段范围：

```text
targetReps: 1...200
workSecondsPerRep: 1...600
restSecondsBetweenReps: 0...600
customCountdownSeconds: 1...3600
groupRestSeconds: 0...3600
cycles: 1...100
```

## 引用和影响范围

训练计划引用动作 ID，不复制动作内容。

修改动作会影响引用它的训练计划。保存已被引用动作前，界面需要提醒用户并列出受影响计划。

保存已被引用动作时，用户应有这些路径：

- 保存并更新相关训练计划。
- 保存为新动作。
- 取消。

删除被引用动作时允许删除，但确认前应列出受影响计划。删除后，相关计划保留可见但变为无效。

无效计划规则：

- 保留可见。
- 不可开始训练。
- 可编辑修复。
- 缺失动作位置支持替换动作或移除此步骤。
- 当前计划变无效时，保留当前选择，并在首页显示无效原因和修复入口。

## 当前计划规则

用户可以从训练计划库选择当前计划。

当前计划规则：

- 新建计划保存后，新计划成为当前计划。
- 编辑当前计划保存后，当前计划保持不变。
- 编辑非当前计划保存后，不自动切换当前计划。
- 删除当前计划后，清空当前选择，不自动切换到其他计划。

## 预计时长

预计训练时长来自训练内容的静态计算。

timed reps 动作时长：

```text
actionDuration =
  targetReps * workSecondsPerRep
  + (targetReps - 1) * restSecondsBetweenReps
```

动作组时长：

```text
actionGroupDuration =
  oneCycleDuration * cycles
  + groupRestSeconds * (cycles - 1)
```

训练计划时长：

```text
planDuration = sum(plan.steps)
```

预计训练时长不包含暂停、意外暂停、恢复倒计时和提前结束造成的差异。

## 开始训练和执行快照

开始训练时：

1. 校验当前计划有效。
2. 解析所有动作引用。
3. 生成完整训练执行快照。
4. 根据设备连接状态确定测量模式。
5. 进入计划第一个步骤。

训练开始前没有系统级准备倒计时。如果用户需要准备时间，应在训练计划开头添加自定义倒计时。

训练开始后：

- 执行快照只读。
- 不允许修改计划或动作参数。
- 不允许调整剩余 reps、cycles、work、rest。
- 不允许跳过当前阶段。
- 测量模式固定。

测量模式：

- 已连接拉力计时，进入拉力计模式（forceDevice）。
- 未连接拉力计时，进入计时模式（timerOnly）。
- 计时模式不能中途切换为拉力计模式。
- 拉力计模式断连后进入意外暂停，不降级为计时模式。

## 执行阶段

训练执行中需要支持这些阶段：

- work
- rep rest
- 自定义倒计时（customCountdown）
- group rest
- paused
- resume countdown

work 是主要动作表现阶段。

rep rest、customCountdown 和 group rest 都是倒计时阶段，但来源不同，界面应帮助用户区分：

- rep rest：动作内部自动产生。
- customCountdown：用户显式添加。
- group rest：动作组 cycle 之间自动产生。

## 曲线和统计口径

拉力计模式下，work、rep rest、自定义倒计时和 group rest 阶段可以显示阶段曲线。paused 阶段不绘制曲线，应显示静止暂停画面。

每个非暂停阶段开始时：

- 重置 X 轴视窗。
- 清空当前阶段曲线数据。
- X 轴最大值为当前阶段计划时长。

Y 轴建议：

- 训练开始时 `yMax = 10kg`。
- 整场训练中只增不减。
- 当前读数超过 `yMax * 0.7` 时，`yMax += 10kg`。
- 阶段切换不重置 Y 轴。

统计口径：

- work 阶段显示主曲线，并参与动作表现统计。
- rep rest、自定义倒计时和 group rest 可以显示弱化曲线，默认不参与动作表现统计。
- paused samples 默认不参与训练统计。

## 摘要统计口径

训练记录可保存：

- 训练执行快照。
- 开始和结束时间。
- 测量模式。
- 采样数据。
- 暂停事件。
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

一次 action step 在某个 cycle 中完整执行一次，算该动作完成 1 组。

如果同一个动作在计划中出现多次：

- 摘要主视图按唯一 action ID 合并统计。
- 底层数据保留每次 action execution 的计划位置，便于未来展开。

提前结束时，应能区分：

- 完整完成 target reps 的 action execution。
- 已开始但未完整完成 target reps 的 action execution。
- 完整完成 work 阶段的 reps。
- 被结束或中断的 rep 位置和已执行时长。

## 趋势签名

训练指标趋势需要判断“训练内容是否一致”。计划名称可编辑，不适合作为一致性依据。计划 ID 也不能单独作为依据，因为同一个计划可能被编辑内容。

训练记录需要保存或可重建：

```text
planContentSignature
```

signature 应来自训练计划具体内容，而不是计划名称。

只修改计划名称不应改变 signature。修改动作内容、步骤顺序、work/rest/自定义倒计时/cycles 等训练内容应改变 signature。

UI 不展示 signature 或 hash。

## 设计检查点

- 计划编辑器应清楚表达 TrainingPlan、ActionGroup、Action、自定义倒计时的层级。
- 自定义倒计时、rep rest 和 group rest 都是倒计时，但来源不同，界面文案不应混用。
- 无效计划不隐藏，应可见、不可开始、可修复。
- 删除动作导致计划无效时，应帮助用户定位缺失动作。
- 预计训练时长是计划内容静态计算结果，不应混同于实际总时间。
- 训练开始后使用执行快照，不应受后续编辑影响。
