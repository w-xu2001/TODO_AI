# My Todo AI

一个移动端优先的 Flutter 待办应用，支持自然语言创建任务、AI 解析截止时间、到点提醒、紧凑任务卡展示。

## 功能概览

- 自然语言输入任务（例如“明天上午 9 点开会”）。
- 对接 OpenAI 兼容接口进行任务解析（title + dueAt）。
- 本地 SQLite 持久化任务。
- 本地通知提醒（flutter_local_notifications）。
- 任务按截止时间升序展示。
- 任务卡支持长按进入“延迟删除”状态并可恢复。
- 逾期任务自动切换为橙色系，并显示“已截至”。

## 技术栈

- Flutter 3.x
- Riverpod
- Dio
- sqflite / sqflite_common_ffi
- flutter_local_notifications
- shared_preferences

## 运行环境

- Dart SDK: ^3.11.4
- Flutter SDK: 建议使用稳定版（与项目 lockfile 匹配）

## 快速开始

1. 安装依赖

```bash
flutter pub get
```

2. 运行（Android 示例）

```bash
flutter run -d android
```

3. 运行（iOS 示例）

```bash
flutter run -d ios
```

## AI 接口配置

应用内可在“设置页”配置 Base URL / Path / API Key / 模型参数。也支持用 `--dart-define` 提供默认值。

可用变量（见 `lib/core/config/app_config.dart`）：

- `TODO_AI_BASE_URL`
- `TODO_AI_PARSE_PATH`
- `TODO_AI_API_KEY`
- `TODO_AI_MODEL`
- `TODO_AI_MAX_TOKENS`
- `TODO_AI_TEMPERATURE`
- `TODO_AI_STREAM`

示例：

```bash
flutter run -d android \
	--dart-define=TODO_AI_BASE_URL=https://api.example.com \
	--dart-define=TODO_AI_PARSE_PATH=/v1/chat/completions \
	--dart-define=TODO_AI_API_KEY=YOUR_KEY \
	--dart-define=TODO_AI_MODEL=gpt-5.4-nano-2026-03-17
```

## 项目结构

```text
lib/
	app/
	core/
		config/
		settings/
		theme/
	features/
		home/
		reminder/
		settings/
		todo/
```

## 常用命令

```bash
# 静态检查
flutter analyze

# 运行测试
flutter test

# Android Release
flutter build apk --release

# iOS Release（需 macOS + Xcode）
flutter build ios --release
```

## Git 提交建议

当前仓库采用“移动端优先”策略，`.gitignore` 已忽略：

- `linux/`
- `macos/`
- `windows/`
- `web/`
- `.metadata`

如果你后续要支持桌面/Web，删除对应忽略规则后再提交即可。

## 安全说明

- 不要提交真实 API Key 到仓库。
- 生产环境建议使用服务端中转与密钥托管，不在客户端硬编码密钥。

## License

私有项目可暂不声明；若开源请补充许可证（如 MIT）。
