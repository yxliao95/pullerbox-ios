# 训练指标（Training Metrics）工程设计指南

相关文档：

- 路线图：`../plans/training-metrics-roadmap.md`
- UI 设计：`../ui/training-metrics-ui-guide.md`

本文档面向开发工程师和 AI 开发代理，定义训练指标（Training Metrics）的数据范围、分组、算法、空值规则、趋势规则和测试要求。

实现必须遵循 `../01-architecture.md`。

## 架构约束

- 指标结果属于 Domain Model。
- 指标计算逻辑应放在 Domain/Core 的纯计算器中，不依赖 SwiftUI、Store 或 Service。
- ViewModel 负责调用计算器、组织页面状态和保存记录。
- Repository/Store 只负责持久化训练记录和指标结果。

建议新增纯计算器，例如：

```text
Core/Utilities/TrainingMetricsCalculator.swift
```

或按项目后续目录约定放入 Domain 侧的纯逻辑模块。

## 通用数据范围

力量指标只统计满足以下条件的样本：

```text
measurementMode == forceDevice
phaseKind == work
actionId != nil
setIndex != nil
repIndex != nil
```

排除：

- rep rest。
- interval。
- group rest。
- paused。
- resume countdown。
- 计时模式（timerOnly）训练。

无有效力量样本时，力量指标为 `nil`，不要返回 0。

## 指标分组

指标按动作（Action）分组：

```text
actionId
```

同一个动作在计划中出现多次时合并计算，不按计划位置拆分。不同动作分开计算。

记录详情显示训练快照中的动作名称。趋势和汇总可以显示当前动作名称，但分组和算法不得依赖动作名称。

## 趋势 key

趋势基本单位：

```text
planContentSignature + actionId + metricId
```

趋势点必须满足：

- 训练计划内容一致。
- 动作一致。
- 指标一致。
- 指标值非空。

计划名称可编辑，不参与一致性判断。计划 ID 也不能单独作为一致性依据，因为同一个计划可能被编辑内容。

工程需要为训练记录保存或可重建：

```text
planContentSignature
```

signature 应来自训练计划具体内容，而不是名称。只修改计划名称不应改变 signature；修改动作内容、步骤顺序、work/rest/interval/cycles 等训练内容应改变 signature。

UI 不暴露 signature/hash。

## 计时模式规则

计时模式（timerOnly）训练仍保留动作指标结构，但力量类 7 个核心指标全部为 `nil`。

非力量信息仍可保存，例如：

- 完成 reps。
- 完成组数。
- 训练时间。
- 暂停时间。

nil 指标不参与趋势。

## 采样时间和时长

如果设备采样间隔固定，可以用采样间隔累计时长。如果采样间隔不稳定，应优先使用相邻样本时间差。

建议通用规则：

```text
sampleDuration(i) = nextSample.elapsedSeconds - sample.elapsedSeconds
```

最后一个样本可使用最近的有效采样间隔，或由采样服务提供的 nominal interval。

所有连续窗口判断只能在同一个 work 段内进行，rest/interval/group rest/pause/resume countdown 都会打断连续窗口。

## 统计工具函数

建议实现并测试以下纯函数：

```text
quantile(values, q)
median(values)
mean(values)
std(values)
coefficientOfVariation(values)
findFirstContinuousWindow(samples, duration, predicate)
stableWindowMeans(samples, windowDuration, maxCV)
```

`quantile(values, 0.99)` 用作抗噪峰值。

## 核心指标模型

示例模型仅表达字段方向，可按项目风格调整命名：

```swift
struct ActionTrainingMetrics: Codable, Equatable, Identifiable {
    var id: String { actionId }
    let actionId: String
    let snapshotActionName: String

    let maxForce: Double?
    let maxForceHoldDurationSeconds: Double?
    let fatigueStartElapsedSeconds: Double?
    let postFatigueSustainedForce: Double?
    let forceDropAbsolute: Double?
    let forceDropRatio: Double?
    let forceDropDurationSeconds: Double?
    let forceDropRateKgPerSecond: Double?
    let averageRecoveryRatio: Double?
    let recoveryEvents: [RecoveryEvent]
}

struct RecoveryEvent: Codable, Equatable, Identifiable {
    let id: String
    let restKind: TrainingPhaseKind
    let restStartedAtElapsedSeconds: Double
    let restDurationSeconds: Double
    let nextWorkStartedAtElapsedSeconds: Double
    let nextWorkPeakForce: Double
    let ratioToActionMaxForce: Double
}
```

如需支持曲线标注，建议额外保存：

```text
maxForceFirstEntryElapsedSeconds
postFatigueLowestStableWindowStartElapsedSeconds
postFatigueLowestStableWindowEndElapsedSeconds
```

## 指标 1：最大力量

定义：

```text
maxForce = P99(action work samples value)
```

范围：

- 按 `actionId` 合并该动作所有 work 样本。

空值：

- 无 work 样本时为 `nil`。

## 指标 2：最大力量维持时长

定义：

```text
maxForceHoldThreshold = maxForce * 0.95
maxForceHoldDuration = sum(duration of work samples where value >= maxForceHoldThreshold)
```

这是全程累计时长，不是单次最长连续时长。

范围：

- 按 `actionId` 合并该动作所有 work 样本。

空值：

- `maxForce == nil` 时为 `nil`。
- 有 maxForce 但没有达到阈值样本时，可以返回 `0`。

## 指标 3：力竭开始时间

定义：

```text
fatigueThreshold = maxForce * 0.80
```

对每个 work 段按时间顺序检测。每个 work 段先剔除上力期：

```text
repPeakForce = P99(this work segment samples)
enterThreshold = repPeakForce * 0.80
enterPoint = first point where samples are continuously >= enterThreshold for 0.3s
```

从 `enterPoint` 后开始检测力竭：

```text
fatigueStart = first point where samples are continuously < fatigueThreshold for 1.0s
```

全局动作指标取该 action 第一次满足条件的 `fatigueStart`。

规则：

- 只在 work 段内判断连续 0.3s 和 1.0s。
- rest/interval/group rest/pause/resume countdown 打断连续窗口。
- 如果某个 work 段找不到 enterPoint，该 work 段不参与力竭检测。

空值：

- `maxForce == nil` 时为 `nil`。
- 未满足连续 1.0s 低于阈值时为 `nil`。

## 指标 4：力竭后维持力量

定义：

从首次 `fatigueStart` 之后，扫描该 action 后续所有 work 样本，寻找稳定窗口：

```text
stableWindowDuration = 1.0s
stableCondition = CV <= 0.05
windowValue = mean(window samples)
postFatigueSustainedForce = min(windowValue of all stable windows)
```

其中：

```text
CV = std / mean
```

窗口要求 `mean > 0`。

范围：

- 从首次力竭后全程搜索，不限于首次力竭所在 rep。

空值：

- 未检测到力竭时为 `nil`。
- 力竭后没有稳定窗口时为 `nil`。
- 不 fallback 到力竭后 median，不放宽 CV 条件。

## 指标 5：力量下降幅度

定义：

```text
rawDropAbsolute = maxForce - postFatigueSustainedForce
forceDropAbsolute = max(0, rawDropAbsolute)
forceDropRatio = forceDropAbsolute / maxForce
hasEffectiveDrop = rawDropAbsolute > 0
```

百分比相对本动作本次最大力量计算。

空值：

- `maxForce == nil` 时为 `nil`。
- `postFatigueSustainedForce == nil` 时为 `nil`。
- `maxForce <= 0` 时为 `nil`。

UI 主显百分比，辅显 kg。

## 指标 6：力量下降速率

定义：

先确定下降区间：

```text
dropStartTime = first point where action work samples are continuously >= maxForce * 0.95 for 0.3s
dropEndTime = start time of the stable window that produced postFatigueSustainedForce
```

下降用时使用训练流程时间，不是 work 累计时间：

```text
forceDropDuration = active plan elapsed time between dropStartTime and dropEndTime
forceDropRateKgPerSecond = forceDropAbsolute / forceDropDuration
```

时间包含：

- work。
- rep rest。
- interval。
- group rest。

时间排除：

- manual pause。
- unexpected pause。
- resume countdown。

实现上可以通过训练执行时维护的 `activeTrainingDuration` 时间轴计算区间差值，或在指标计算器中根据 phase timeline 重新累计。

空值：

- 无 `dropStartTime` 时为 `nil`。
- 无 `postFatigueSustainedForce` 或其窗口时间时为 `nil`。
- `forceDropAbsolute == nil` 时为 `nil`。
- `forceDropDuration <= 0` 时为 `nil`。

## 指标 7：平均恢复程度

恢复事件是某个动作已经出现过 work 后，计划内休息后的下一个同动作 work 段。

不为动作第一次出现前的准备、换手或 interval 生成恢复事件。

计划内休息包括：

- rep rest。
- interval。
- group rest。

不包括：

- manual pause。
- unexpected pause。
- resume countdown。

单次恢复程度：

```text
nextWorkPeakForce = P99(next work segment samples)
recoveryRatio = nextWorkPeakForce / maxForce
```

摘要指标：

```text
averageRecoveryRatio = mean(all recoveryRatio)
```

空值：

- 没有计划内休息时为 `nil`。
- 休息后没有下一个 work 段时不生成事件。
- 休息后的 work 是该 action 第一次出现时，不生成事件。
- `maxForce == nil || maxForce <= 0` 时为 `nil`。

## 趋势规则

7 个核心指标全部保存，并全部支持趋势。

默认趋势：

- 最大力量。
- 最大力量维持时长。
- 力竭开始时间。
- 平均恢复程度。

可选趋势：

- 力竭后维持力量。
- 力量下降幅度。
- 力量下降速率。

趋势点过滤：

```text
same planContentSignature
same actionId
same metricId
metric value != nil
```

有效点少于 2 个时不展示趋势线。

## 测试建议

建议为指标计算器添加单元测试，至少覆盖：

- 计时模式（timerOnly）指标为空。
- 只统计 work 样本，排除休息和暂停样本。
- 最大力量使用 P99 而非 raw max。
- 最大力量维持时长为累计值。
- 上力期不触发力竭。
- 连续 1.0s 低于 80% 最大力量才触发力竭。
- rest 打断连续低阈值窗口。
- 力竭后稳定窗口 CV <= 5% 才参与计算。
- 无稳定窗口时力竭后维持力量为空。
- 下降用时排除 pause 和 resume countdown。
- 恢复程度只统计计划内休息后的下一个 work。
- 同 actionId 多次出现时合并计算。
- 趋势过滤要求 `planContentSignature + actionId + metricId`。

