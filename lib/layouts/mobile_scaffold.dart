import 'package:flutter/material.dart';
import 'package:daily_you/pages/home_page.dart';

class MobileScaffold extends StatelessWidget {
  const MobileScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    // 整个应用的骨架改为直接渲染 HomePage。
    // 手势导航（上下滑）由 HomePage 自己或者其父容器处理。
    return const Scaffold(
      body: HomePage(),
    );
  }
}
