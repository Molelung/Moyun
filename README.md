# 墨云 Moyun

> 极简诗意日记 · 白纸一张，一句诗，一个加号。

墨云（原"诗云"）是一款宣纸风格的极简日记应用。打开即是一张宣纸、一段文字、一个加号——像翻开自己的书。

## 特性

- **宣纸界面**：纸纹背景 + 液态玻璃卡片，恒亮色主题
- **今日卡片**：左右滑动查看当天多篇日记，壹贰叁编号（最新编号最大）
- **关键词搜索**：卡片下方搜索框，按内容/标题检索全部日记
- **时间轴**：竖向时间线浏览全部历史，右侧胶囊快速跳转（今天/一月/三月/一年/选日期）
- **漫游模式**：左上角进入，无限左右滑动随机回味某一天的日记
- **统计**：篇数 / 字数 / 天数 / 日均 + 关键词词云
- **外观设置**：仿宋 / 楷书切换、强调色、主题
- **补充**：日记支持图片、Markdown、多篇/天；应用锁（密码 + 生物识别）
- 支持 Android 10+（minSdk/targetSdk 29），鸿蒙兼容层可用

## 版本策略

- 当前：**v0.1.x**（每次小更新递增小版本，如 0.1.4）
- 功能性更新升中版本：0.2.x
- 达到稳定后进入 1.0.0 正式版

## 构建

```bash
flutter pub get
flutter build apk --release --flavor independent
```

产物：`build/app/outputs/flutter-apk/app-independent-release.apk`

## 发布

每版 APK 发布在 [GitHub Releases](https://github.com/Molelung/Moyun/releases)。

## 许可

本项目基于 [Daily You](https://github.com/Demizo/daily_you) 深度改造而来。
