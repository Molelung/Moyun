import 'package:flutter/material.dart';
import 'package:daily_you/main.dart';
import 'package:daily_you/pages/edit_entry_page.dart';
import 'package:daily_you/pages/home_page.dart';

class MobileScaffold extends StatefulWidget {
  const MobileScaffold({super.key});

  @override
  State<MobileScaffold> createState() => _MobileScaffoldState();
}

class _MobileScaffoldState extends State<MobileScaffold> {
  @override
  void initState() {
    super.initState();
    // 冷启动时通知点击直达写日记：等首帧与导航就绪后消费标志
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      if (consumePendingLogToday()) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              const AddEditEntryPage(entry: null, openCamera: false, images: []),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 整个应用的骨架改为直接渲染 HomePage。
    // 手势导航（上下滑）由 HomePage 自己或者其父容器处理。
    return const Scaffold(
      body: HomePage(),
    );
  }
}
