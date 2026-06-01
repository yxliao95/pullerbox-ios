# iOS App 架构规范

## 项目背景

本项目是一个基于蓝牙拉力计的 iOS 训练工具 App。

核心能力：

- 扫描和连接蓝牙拉力计。
- 实时读取拉力数据。展示当前拉力、峰值和训练状态。
- 保存和查看训练记录。
- 项目规模较小，采用轻量架构，避免过度设计。

## 架构模式

SwiftUI + MVVM + Repository + Service + CoreBluetooth

调用链如下：

```text
View
  ↓
ViewModel
  ↓ depends on
RepositoryProtocol
  ↓ input / output
Model
  ↑ implemented by
Repository
  ↓ uses
Service / Store
  ↓
CoreBluetooth / Local Storage / System API
```

## 核心原则

表现层：

- `View` 只负责界面展示和用户交互。例如按钮点击、列表展示、图表渲染、页面跳转等。View 不直接访问蓝牙、数据库、文件系统或系统 API。
- `ViewModel` 负责页面状态管理、用户操作处理、数据转换和业务流程编排。例如开始训练、结束训练、连接设备、处理错误状态、将采样数据转换为图表数据等。
- `ViewModel` 只依赖 `RepositoryProtocol`，而不关心数据来自蓝牙、本地存储还是系统 API。

业务层：

- `RepositoryProtocol` 描述业务层需要的数据访问能力。负责向 `ViewModel` 提供稳定的数据访问接口，并屏蔽底层数据来源。
- `Model` 负责表达领域对象，例如训练记录、拉力采样点、设备信息、训练摘要等。`Model` 应尽量保持纯粹，不依赖 SwiftUI、CoreBluetooth 或本地存储实现。只表达业务含义，不绑定具体技术实现。

数据层：

- `Repository` 是 `RepositoryProtocol` 的具体实现，负责组合具体的数据来源。它可以调用 BluetoothManager、TrainingSessionStore、AppSettingsStore 等底层组件，并将底层数据转换为领域模型。
- `Service` 负责具体技术实现。它通常不包含页面业务逻辑，而是封装某一类底层能力。例如 CoreBluetooth 扫描、连接、订阅特征值、解析蓝牙原始数据等。
- `Store` 负责本地数据读写，例如训练记录、用户设置、设备缓存等。它属于数据层组件，和 `Service` 类似，都是 `Repository` 的底层依赖。

## 目录结构示例

```text
ProjectName
├── App
│   ├── ProjectNameApp.swift
│   └── AppContainer.swift
│
├── Features
│   ├── Training
│   │   ├── TrainingView.swift
│   │   └── TrainingViewModel.swift
│   │
│   └── Settings
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
│
├── Domain
│   ├── Models
│   │   ├── ForceSample.swift
│   │   ├── TrainingSession.swift
│   │   └── BluetoothDevice.swift
│   │
│   └── Repositories
│       ├── ForceDeviceRepositoryProtocol.swift
│       └── TrainingSessionRepositoryProtocol.swift
│
├── Data
│   ├── Repositories
│   │   ├── ForceDeviceRepository.swift
│   │   └── TrainingSessionRepository.swift
│   │
│   ├── Services
│   │   └── Bluetooth
│   │       ├── BluetoothManager.swift
│   │       ├── ForceMeterParser.swift
│   │       └── BluetoothError.swift
│   │
│   └── Stores
│       ├── TrainingSessionStore.swift
│       └── AppSettingsStore.swift
│
├── SharedUI
│
├── Core
│   ├── Extensions
│   ├── Utilities
│   └── Constants
│
└── Tests
    ├── ViewModelTests
    └── XXXTests
```
