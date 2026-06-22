# 训练指标

本文档汇总训练指标的产品口径，面向 UI 设计师理解指标含义、选择图表和组织交互使用。

## 成功标准

训练指标应帮助用户理解一次指力训练，尤其是单手负重悬吊中的力量、疲劳和恢复情况。

训练指标重点回答：

- 最大力量达到多少。
- 接近最大力量的状态维持了多久。
- 什么时候开始明显力竭。
- 力竭后还能稳定维持多少力量。
- 从最大力量下降了多少。
- 下降过程用了多久、下降速度多快。
- 休息后平均恢复到最大力量的多少。

## 通用口径

力量指标只来自拉力计模式（forceDevice）下的 work 阶段采样。

有效力量样本需要同时满足：

```text
measurementMode == forceDevice
phaseKind == work
actionId != nil
setIndex != nil
repIndex != nil
```

不参与力量指标计算：

- rep rest。
- 自定义倒计时（customCountdown）。
- group rest。
- paused。
- resume countdown。
- 计时模式（timerOnly）。

无有效数据时，指标为空值（nil），不显示为 0。UI 应用空状态、不可用状态或轻量说明表达原因。

指标计算结果属于训练记录的领域数据。UI 可以读取并展示指标，但不应在界面层重新定义统计口径。

## 时间和连续窗口

所有和时长、连续低于阈值、稳定窗口有关的判断，都只在同一个 work 段内连续计算。rest、自定义倒计时、group rest、pause 和 resume countdown 都会打断连续窗口。

如果设备采样间隔固定，可以按采样间隔累计时长。如果采样间隔不稳定，应优先使用相邻样本时间差：

```text
sampleDuration(i) = nextSample.elapsedSeconds - sample.elapsedSeconds
```

最后一个样本可使用最近的有效采样间隔，或使用采样服务提供的 nominal interval。

设计含义：

- 曲线标注不要跨休息或暂停阶段连接成一个连续检测窗口。
- 力竭、维持、稳定窗口等标注应绑定到具体 work 段。
- 暂停和恢复倒计时会影响总时间，但不应被理解为动作表现本身。

## 分组维度

指标按动作（Action）分组：

```text
actionId
```

同一个动作在同一次训练计划中出现多次时，合并为同一个动作指标组。不同动作分开计算和展示。

设计含义：

- 摘要页适合按动作卡片分组。
- 详情页适合进入单个动作后展示完整曲线和指标。
- 趋势页的比较单位应保持训练内容、动作和指标一致。

## 趋势维度

趋势基本单位：

```text
训练计划内容 + 动作 + 指标
```

工程 key 为：

```text
planContentSignature + actionId + metricId
```

设计含义：

- 只有训练内容一致的记录才适合比较趋势。
- 修改计划名称不影响趋势连续性。
- 修改动作内容、步骤顺序、work/rest/自定义倒计时/cycles 等训练内容后，会形成新的趋势序列。
- UI 不展示 signature 或 hash。
- 指标值为空的记录不参与趋势。
- 有效趋势点少于 2 个时，不展示趋势线，应展示记录不足状态。

训练内容一致性的详细规则见 `03-training-plan.md` 中的趋势签名说明。

## 指标总览

| 指标 | 用户理解 | 主展示建议 | 常用图表 |
| --- | --- | --- | --- |
| 最大力量 | 本动作本次达到的最高力量水平 | kg 数值 | 指标卡、曲线峰值标注、趋势折线 |
| 最大力量维持时长 | 接近最大力量的累计时间 | 秒 | 指标卡、曲线高亮区间、趋势折线 |
| 力竭开始时间 | 明显掉力开始发生在什么时候 | 训练内时间点 | 曲线时间点标注、指标卡 |
| 平均恢复程度 | 计划内休息后恢复到最大力量的平均比例 | 百分比 | 指标卡、恢复事件列表、趋势折线 |
| 力竭后维持力量 | 力竭后最低还能稳定维持的力量 | kg 数值 | 指标卡、曲线稳定窗口标注 |
| 力量下降幅度 | 从最大力量掉到力竭后稳定力量的差距 | 百分比为主，kg 为辅 | 指标卡、对比条、趋势折线 |
| 力量下降速率 | 从高力量掉到稳定低点的速度 | kg/s | 指标卡、趋势折线 |

## 保存记录中的呈现

训练记录会保存或可重建每个动作的指标结果，方向如下：

```text
ActionTrainingMetrics
  actionId
  snapshotActionName
  maxForce
  maxForceHoldDurationSeconds
  fatigueStartElapsedSeconds
  postFatigueSustainedForce
  forceDropAbsolute
  forceDropRatio
  forceDropDurationSeconds
  forceDropRateKgPerSecond
  averageRecoveryRatio
  recoveryEvents[]
```

如需支持曲线标注，可额外使用：

```text
maxForceFirstEntryElapsedSeconds
postFatigueLowestStableWindowStartElapsedSeconds
postFatigueLowestStableWindowEndElapsedSeconds
```

恢复事件结构方向：

```text
RecoveryEvent
  restKind
  restStartedAtElapsedSeconds
  restDurationSeconds
  nextWorkStartedAtElapsedSeconds
  nextWorkPeakForce
  ratioToActionMaxForce
```

设计含义：

- 记录摘要可以读取动作级指标。
- 记录详情可以读取指标、恢复事件和曲线标注时间点。
- 趋势页只使用非空指标值。
- `snapshotActionName` 用于还原本次训练时的动作名称。

计时模式训练仍可保存动作完成结构、完成 reps、完成组数、训练时间和暂停时间，但力量类指标为空，不参与趋势。

## 指标 1：最大力量

概念：

用户在该动作中达到的最高力量水平。为避免单个噪声尖峰误导，使用接近最高值的 P99，而不是原始最大值。

计算方法：

```text
maxForce = P99(action work samples value)
```

应用维度：

- 按动作合并该动作所有 work 样本。
- 只用于拉力计模式。

记录呈现：

```text
maxForce: kg
```

空值规则：

- 没有有效 work 样本时为空。

设计建议：

- 摘要页可作为主指标展示。
- 详情页可在力量曲线上标注峰值水平。
- 趋势页适合用折线图展示长期变化。

## 指标 2：最大力量维持时长

概念：

用户接近本次最大力量的累计时间，反映高强度输出能维持多久。

计算方法：

```text
maxForceHoldThreshold = maxForce * 0.95
maxForceHoldDuration = sum(duration of work samples where value >= maxForceHoldThreshold)
```

这是全程累计时长，不是单次最长连续时长。

应用维度：

- 按动作合并所有 work 样本。
- 依赖最大力量。

记录呈现：

```text
maxForceHoldDurationSeconds: seconds
```

空值规则：

- `maxForce` 为空时为空。
- 有最大力量但没有达到阈值样本时，可以显示为 0 秒。

设计建议：

- 摘要页可显示为秒数。
- 详情页可在曲线上高亮超过 95% 最大力量的片段。
- 趋势页适合用折线图观察高强度维持能力变化。

## 指标 3：力竭开始时间

概念：

用户力量持续明显低于本次最大力量的开始时间，用来定位“从哪里开始掉力”。

计算方法：

```text
fatigueThreshold = maxForce * 0.80
fatigueStart = first point where samples are continuously < fatigueThreshold for 1.0s
```

每个 work 段会先剔除上力期，避免刚开始发力时被误判为力竭。上力期判断口径为：先找到该 work 段内连续 0.3 秒达到该段峰值 80% 的进入点，再从进入点之后开始检测是否连续 1 秒低于本动作最大力量的 80%。

应用维度：

- 按动作检测。
- 只在 work 段内判断连续窗口。
- rest、自定义倒计时、group rest、pause、resume countdown 都会打断连续窗口。

记录呈现：

```text
fatigueStartElapsedSeconds: seconds from training start
```

空值规则：

- `maxForce` 为空时为空。
- 没有任何 work 段满足连续 1 秒低于阈值时为空。

设计建议：

- 摘要页可显示为“第几秒开始明显下降”。
- 详情页适合在曲线上用时间点标注。
- 未检测到力竭时不要显示为 0，可显示为“未检测到明显力竭”一类状态。

## 指标 4：平均恢复程度

概念：

计划内休息后，下一次同动作 work 的峰值恢复到本次最大力量的平均比例。

计算方法：

单次恢复：

```text
nextWorkPeakForce = P99(next work segment samples)
recoveryRatio = nextWorkPeakForce / maxForce
```

摘要指标：

```text
averageRecoveryRatio = mean(all recoveryRatio)
```

应用维度：

- 按动作统计。
- 只统计该动作已经出现过 work 之后的计划内休息。
- 计划内休息包括 rep rest、自定义倒计时、group rest。
- 不包括 manual pause、unexpected pause、resume countdown。
- 不为某个动作第一次出现前的准备、换手或自定义倒计时生成恢复事件。

记录呈现：

```text
averageRecoveryRatio: 0...1
recoveryEvents[]:
  restKind
  restDurationSeconds
  nextWorkPeakForce
  ratioToActionMaxForce
```

空值规则：

- 没有计划内休息时为空。
- 休息后没有下一个 work 段时，不生成恢复事件。
- 休息后的 work 是该动作第一次出现时，不生成恢复事件。
- `maxForce` 为空或小于等于 0 时为空。

设计建议：

- 摘要页可显示为百分比。
- 详情页适合展示恢复事件列表：休息类型、休息时长、下一次峰值、恢复比例。
- 趋势页适合用折线图展示恢复能力变化。

## 指标 5：力竭后维持力量

概念：

明显力竭之后，用户仍能稳定维持的最低力量水平。

计算方法：

从首次力竭后，扫描后续 work 样本，寻找稳定窗口：

```text
stableWindowDuration = 1.0s
stableCondition = CV <= 0.05
postFatigueSustainedForce = min(mean(window samples))
```

其中 `CV = std / mean`，窗口均值需要大于 0。

应用维度：

- 按动作统计。
- 从首次力竭后全程搜索，不限于首次力竭所在 rep。
- 未检测到力竭或没有稳定窗口时为空。

记录呈现：

```text
postFatigueSustainedForce: kg
postFatigueLowestStableWindowStartElapsedSeconds
postFatigueLowestStableWindowEndElapsedSeconds
```

空值规则：

- 未检测到力竭时为空。
- 力竭后没有满足稳定条件的窗口时为空。
- 不使用力竭后中位数兜底，也不放宽稳定窗口条件。

设计建议：

- 详情页可在曲线上标注稳定窗口。
- 可以与最大力量并排展示，帮助用户理解高点和低点。
- 摘要页不必默认展示，除非当前页面要强调疲劳深度。

## 指标 6：力量下降幅度

概念：

最大力量和力竭后稳定力量之间的差值，反映掉力程度。

计算方法：

```text
forceDropAbsolute = max(0, maxForce - postFatigueSustainedForce)
forceDropRatio = forceDropAbsolute / maxForce
```

应用维度：

- 按动作统计。
- 依赖最大力量和力竭后维持力量。

记录呈现：

```text
forceDropAbsolute: kg
forceDropRatio: 0...1
```

空值规则：

- `maxForce` 为空时为空。
- `postFatigueSustainedForce` 为空时为空。
- `maxForce <= 0` 时为空。

设计建议：

- UI 主显百分比，辅显 kg。
- 适合用对比条、差值标注或详情页指标卡表达。
- 趋势页可以用折线图观察疲劳程度是否变轻或变重。

## 指标 7：力量下降速率

概念：

从接近最大力量下降到力竭后稳定低点的速度，反映掉力过程快慢。

计算方法：

```text
dropStartTime = first point continuously >= maxForce * 0.95 for 0.3s
dropEndTime = start time of the stable window that produced postFatigueSustainedForce
forceDropDuration = active plan elapsed time between dropStartTime and dropEndTime
forceDropRateKgPerSecond = forceDropAbsolute / forceDropDuration
```

下降用时排除 manual pause、unexpected pause、resume countdown。

应用维度：

- 按动作统计。
- 依赖最大力量、力竭后维持力量、下降幅度和稳定窗口时间。

记录呈现：

```text
forceDropDurationSeconds: seconds
forceDropRateKgPerSecond: kg/s
```

空值规则：

- 找不到下降开始时间时为空。
- 没有力竭后维持力量或稳定窗口时间时为空。
- 力量下降幅度为空时为空。
- 下降用时小于等于 0 时为空。

设计建议：

- 详情页可作为辅助疲劳指标展示。
- 趋势页适合用折线图，但需要注意用户可能不熟悉 kg/s，应配合简短解释。

## 页面呈现建议

### 训练摘要

按动作分组。每个动作先展示完成情况，再展示力量指标。

默认优先展示：

- 最大力量。
- 最大力量维持时长。
- 力竭开始时间。
- 平均恢复程度。

计时模式训练仍展示完成情况和时间，但不展示空的力量指标网格。

### 训练详情

围绕单个动作展示：

- 力量曲线。
- 最大力量水平。
- 最大力量维持片段。
- 力竭开始点。
- 力竭后稳定窗口。
- 恢复事件列表。
- 7 个指标的完整解释。

图表标注应避免拥挤。默认只突出最能帮助用户理解表现变化的标记。

### 历史趋势

趋势入口可以支持两种视角：

- 按动作看多个指标。
- 按指标看多个动作。

默认趋势：

- 最大力量。
- 最大力量维持时长。
- 力竭开始时间。
- 平均恢复程度。

可选趋势：

- 力竭后维持力量。
- 力量下降幅度。
- 力量下降速率。

有效趋势点少于 2 个时，应展示记录不足状态。

## 空值和异常状态

不要把空值显示为 0。

常见空值原因：

- 本次训练是计时模式。
- 没有有效 work 采样。
- 未检测到力竭。
- 力竭后没有稳定窗口。
- 没有计划内休息或休息后没有下一次同动作 work。
- 趋势点不足。

设计上应优先解释“为什么没有这个指标”，而不是用 0、空白图表或错误状态误导用户。
