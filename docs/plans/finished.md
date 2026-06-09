# 已确定范围

本文档记录已经进入稳定文档口径的范围和产品决策。根目录文档只保留稳定说明，版本、阶段和范围信息放在 `plans/` 目录维护。

## 用户流程

计划训练闭环已经确定为核心流程：

1. 维护动作库。
2. 创建、编辑或选择训练计划。
3. 从训练首页开始训练。
4. 按计划执行训练。
5. 训练结束后查看未保存摘要。
6. 保存或丢弃训练结果。
7. 返回训练首页。

训练开始时根据设备连接状态确定测量模式：

- 已连接拉力计：进入拉力计模式（forceDevice）。
- 未连接拉力计：进入计时模式（timerOnly）。

训练执行中已经确定支持的阶段：

- work。
- rep rest。
- 自定义倒计时（customCountdown）。
- group rest。
- paused。
- resume countdown。

训练结束原因已经确定包括：

- completed：计划自然完成。
- stoppedByUser：用户手动结束。
- stoppedAfterUnexpectedPause：意外暂停后用户选择结束。

## 训练摘要

所有测量模式都展示完成情况和时间相关摘要，包括总时间、训练时间、暂停时长、包含动作数、按动作统计的完成组数、未完成组数、完成 reps 和组间休息时间。

拉力计模式额外展示力量采样、最大力量、rep 级力量统计，以及可用于训练指标计算的动作表现数据。

计时模式不展示当前力量、最大力量、曲线、rep peak 和力量类训练指标。

## 训练指标

训练指标已经确定按动作（Action）分组。同一动作在同一次训练计划中出现多次时合并计算，不同动作分开计算和展示。

已经确定的核心指标包括：

1. 最大力量（maxForce）。
2. 最大力量维持时长（maxForceHoldDuration）。
3. 力竭开始时间（fatigueStart）。
4. 平均恢复程度（averageRecoveryRatio）。
5. 力竭后维持力量（postFatigueSustainedForce）。
6. 力量下降幅度（forceDrop）。
7. 力量下降速率（forceDropRate）。

趋势比较单位已经确定为：

```text
planContentSignature + actionId + metricId
```

趋势点必须满足训练计划内容一致、动作一致、指标一致，并且指标值非空。
