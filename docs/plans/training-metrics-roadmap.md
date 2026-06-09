# 训练指标（Training Metrics）路线图

状态：active

相关文档：

- UI 设计：`../ui/training-metrics-ui-guide.md`
- 工程设计：`../engineering/training-metrics-engineering-guide.md`

本文档记录训练指标（Training Metrics）的版本范围和指标清单。具体展示方式见 UI 文档，具体算法和数据口径见工程文档。

训练指标（Training Metrics）的第一版范围不等同于计划训练（Planned Training）的第一阶段排期。若某个入口依赖尚未完成的记录详情或历史趋势，应等对应特性进入开发阶段后再接入。

## 第一版目标

第一版训练指标围绕指力训练，尤其是单手负重悬吊。目标是帮助用户理解最大力量、力量维持、力竭、下降和恢复。

## 第一版核心指标

1. 最大力量（maxForce）：本次训练中某个动作达到的最高力量水平。
2. 最大力量维持时长（maxForceHoldDuration）：接近本次最大力量的累计时间。
3. 力竭开始时间（fatigueStart）：力量持续明显低于本次最大力量的开始时间。
4. 平均恢复程度（averageRecoveryRatio）：计划内休息后，下一次锻炼恢复到本次最大力量的平均比例。
5. 力竭后维持力量（postFatigueSustainedForce）：明显力竭后最低还能稳定维持的力量。
6. 力量下降幅度（forceDrop）：本次最大力量与力竭后维持力量之间的差值。
7. 力量下降速率（forceDropRate）：从最大力量区间下降到力竭后稳定低点的速度。

## 第一版展示范围

- 训练摘要。
- 单次训练详情。
- 历史趋势。

摘要默认优先展示：

- 最大力量。
- 最大力量维持时长。
- 力竭开始时间。
- 平均恢复程度。

详情和趋势可展示全部 7 个核心指标。

## 第一版工程范围

- 指标按动作（Action）分组。
- 同一动作在同一训练中出现多次时合并计算。
- 计时模式（timerOnly）训练保留动作完成结构，但力量指标为空。
- 趋势基于 `planContentSignature + actionId + metricId`。
- 指标值为空的记录不参与趋势。

## 后续待设计

- 更多力量和疲劳指标。
- 更细粒度的趋势对比。
- 个性化阈值。
- 训练内容变化后的趋势合并策略。
