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

