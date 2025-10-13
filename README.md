# Aivora-ai
An open-source, modern-design AI chat app

---项目目录结构：
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   └── router/
├── data/
│   ├── models/
│   ├── repositories/
│   └── services/
├── domain/
│   ├── entities/
│   └── repositories/
├── presentation/
│   ├── providers/
│   ├── pages/
│   │   ├── auth/
│   │   ├── chat/
│   │   └── settings/
│   └── widgets/
└── shared/
    ├── extensions/
    └── widgets/


---运行时依赖（dependencies）

flutter_riverpod：现代、类型安全的状态管理。支持 Provider/AsyncValue/StateNotifier，热重载友好，解耦强、可测试。

go_router：官方团队维护的路由库，声明式路由、深链接、重定向与守卫（redirect）开箱即用。

dio：强大的 HTTP 客户端，请求/响应拦截器、取消、超时、FormData、文件上传下载等。

cupertino_icons：iOS 风格图标集，搭配 Cupertino 风格组件使用。

shared_preferences：轻量级本地 KV 存储，适用于小体量配置/偏好（如 token、主题、语言等）。

json_annotation：搭配 json_serializable 做 JSON 模型注解（@JsonSerializable() 等）。

intl：本地化与国际化（日期、数字、货币格式化等）。

uuid：生成唯一 ID（v4 随机、v5 命名空间等）。




---开发依赖（dev_dependencies）

flutter_lints：官方推荐的 Lints 规则，统一代码风格与质量。

build_runner：Dart 代码生成框架的驱动器（运行构建任务/监听）。

json_serializable：结合 json_annotation 自动生成 fromJson/toJson 代码，减少样板代码。


你现在是一个顶级前端架构师，这是一个空的项目，我希望你能够用它生成一个flutter项目
项目名称为Aivora-ai
项目描述为An open-source, modern-design AI chat app。
它是一个基于flutter的跨平台AI聊天应用，用户可以在移动端和Web端使用。
主要功能包括：
1. 用户注册和登录
2. ai聊天功能，包括发送和接收消息,选择ai模型等
3. drawer页面，包括用户信息和设置



生成步骤：
1. 初始化flutter项目
2. 添加必要的依赖包，如flutter_bloc,http,等
3. 设计项目架构，包括状态管理、网络请求、路由等
4. 实现项目功能以及基础页面，如登录注册、聊天功能页面、个人中心等
- 登录注册页面：包括用户注册和登录功能。
- 聊天功能页面：登录之后直接显示的页面，页面顶部显示当前的ai模型名称，同时可以通过顶部左侧的按钮唤醒drawer导航。包括用户与ai的聊天功能，用户可以发送消息并接收ai的回复。
-drawer页面：通过drawer导航唤醒，包括一些基础的功能选择以及设置按键



技术选型：
项目技术栈为flutter,dart，以及flutter项目常见、专业的包。
UI 框架：Flutter 自带 Material / Cupertino（推荐）
路由：go_router
状态管理：Riverpod
网络请求：dio



