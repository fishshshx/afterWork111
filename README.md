# 下班后

个人自用的本地优先 Android App：记录下班后的兴趣 / 学习 / 娱乐 / 创作活动。

## 当前阶段

第一阶段：项目初始化、数据库设计、分类管理（已完成）。

## 技术栈

- Flutter 3.x + Dart
- sqflite（本地 SQLite）
- flutter_riverpod（状态管理）
- go_router（路由）
- intl（日期/数字格式化）

## 项目结构

```
lib/
  main.dart              # 入口
  app.dart               # MaterialApp + ProviderScope
  router.dart            # go_router 路由配置
  models/                # 数据模型
  data/
    app_database.dart    # SQLite 数据库帮助类
    daos/                # 数据访问对象
  providers/             # Riverpod Providers
  screens/               # 页面
  widgets/               # 可复用组件
```

## 如何运行

1. 安装 Flutter SDK 与 Android Studio（含 Android SDK + JDK）。
2. 进入项目目录：
   ```bash
   cd after_work
   ```
3. 安装依赖：
   ```bash
   flutter pub get
   ```
4. 连接安卓手机或启动模拟器，然后运行：
   ```bash
   flutter run
   ```
5. 构建 APK：
   ```bash
   flutter build apk --release
   ```

## 第一阶段功能

- 底部 5 个 Tab：今天、计划、记录、打卡、统计。
- 「今天」页右上角进入设置。
- 设置页可进入「分类管理」。
- 分类管理：新增、编辑、删除、拖拽排序；删除时若该分类下存在活动则禁止删除。
- 数据库已包含全部六张表（categories / activities / plans / records / check_in_items / check_in_records），并预置 6 个分类。

## 注意事项

- 当前为单人本地使用，无账号、无云同步、无网络依赖。
- 照片将存储在应用私有目录，导出时打包。
