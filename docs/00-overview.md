# iOS App 开发约定

## 技术栈

语言：Swift
UI：SwiftUI
架构：MVVM + Repository + Service + Store
蓝牙：CoreBluetooth
异步：async/await + AsyncStream
本地存储：SwiftData 或 JSON File Store
图表：Swift Charts
依赖注入：手动 AppContainer
测试：XCTest
最低系统版本：iOS 17+

## 协作开发流程

```bash
# 1. 同步主分支
git checkout main
git pull origin main

# 2. 创建功能分支
git checkout -b feature/new-feat-a

# 3. 开发并提交
git add .
git commit -m "Add report export API"

# 4. 推送分支
git push origin feature/new-feat-a

# 5. 创建 Pull Request

# 6. 根据 review 修改代码
git add .
git commit -m "Handle empty export result"
git push origin feature/new-feat-a

# 7. PR 通过后合并到 main
```
