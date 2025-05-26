import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final webviewUrl = "http://192.168.60.163:5173/";

  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // 启用 JavaScript
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // 允许所有导航请求（包括 HTTP）
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // 处理网络错误（如 SSL 错误）
            print('WebView 错误: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        "FlutterBridge",
        onMessageReceived: onMessageReceived,
      )
      ..loadRequest(Uri.parse(webviewUrl)); // 加载 URL

    // 针对 Android 平台的配置
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void onMessageReceived(JavaScriptMessage javaScriptMessage) {
    final params = jsonDecode(javaScriptMessage.message);
    // 处理来自 Flutter 的消息
    print('收到来自 Flutter 的消息: $params');

    final cbId = params["_cbId"];

    // 2. 确保 params 是 Map 类型
    if (params is! Map) {
      print('错误：接收到的消息不是 JSON 对象');
      if (cbId != null) {
        callJsReject(cbId, {
          "error": "INVALID_FORMAT",
          "message": "期望 JSON 对象，但收到: ${params.runtimeType}",
        });
      }
      return;
    }

    final method = params["name"];
    final args = params["args"];

    // 直接运行， 没有返回值
    if (cbId == null) {
      // todo
    } else {
      // 有返回值， 异步调用
      try {
        callJsResolve(cbId, {
          "args": args,
          "error": "METHOD_NOT_FOUND",
          "message": "未找到方法: $method",
        });
      } catch (e) {
        callJsReject(cbId, {
          "error": "INTERNAL_ERROR",
          "message": "方法执行出错: $e",
        });
      }
    }
  }

  void callJsResolve(String cbId, dynamic params) {
    final jsonParams = jsonEncode(_cleanParams(params));
    print('callJsResolve, cbId: $cbId, params: $jsonParams');
    controller.runJavaScript(
      "window.jsResolve && window.jsResolve('$cbId', $jsonParams)",
    );
  }

  void callJsReject(String cbId, dynamic params) {
    final jsonParams = jsonEncode(_cleanParams(params));
    print('callJsReject, cbId: $cbId, params: $jsonParams');
    controller.runJavaScript(
      "window.jsReject && window.jsReject('$cbId', $jsonParams)",
    );
  }

  // 清理参数，确保可序列化
  dynamic _cleanParams(dynamic value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;

    if (value is List) {
      return value.map((e) => _cleanParams(e)).toList();
    }

    if (value is Map) {
      final cleanMap = <String, dynamic>{};
      value.forEach((key, val) {
        cleanMap[key.toString()] = _cleanParams(val);
      });
      return cleanMap;
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: WebViewWidget(controller: controller));
  }
}
