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
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

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

    // 直接运行， 没有返回值
    if (cbId == null) {
    } else {
      // 有返回值， 异步调用
      final method = params["name"];
      final args = params["args"];
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
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      // appBar: AppBar(
      //   // TRY THIS: Try changing the color here to a specific color (to
      //   // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
      //   // change color while the other colors stay the same.
      //   // backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      //   // // Here we take the value from the MyHomePage object that was created by
      //   // // the App.build method, and use it to set our appbar title.
      //   // title: Text(widget.title),
      // ),
      body: WebViewWidget(controller: controller),
      // body: Center(
      //   // Center is a layout widget. It takes a single child and positions it
      //   // in the middle of the parent.
      //   child: Column(
      //     // Column is also a layout widget. It takes a list of children and
      //     // arranges them vertically. By default, it sizes itself to fit its
      //     // children horizontally, and tries to be as tall as its parent.
      //     //
      //     // Column has various properties to control how it sizes itself and
      //     // how it positions its children. Here we use mainAxisAlignment to
      //     // center the children vertically; the main axis here is the vertical
      //     // axis because Columns are vertical (the cross axis would be
      //     // horizontal).
      //     //
      //     // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
      //     // action in the IDE, or press "p" in the console), to see the
      //     // wireframe for each widget.
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     children: <Widget>[
      //       const Text('You have pushed the button this many times:'),
      //       Text(
      //         '$_counter',
      //         style: Theme.of(context).textTheme.headlineMedium,
      //       ),
      //     ],
      //   ),
      // ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _incrementCounter,
      //   tooltip: 'Increment',
      //   child: const Icon(Icons.add),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
