import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.banner,
    this.bottomBar,
    this.padding = const EdgeInsets.all(16),
    this.scrollable = false,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? banner;
  final Widget? bottomBar;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(padding: padding, child: body);
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(title: Text(title!), actions: actions, leading: leading),
      body: Column(
        children: [
          ?banner,
          Expanded(
            child: scrollable ? SingleChildScrollView(child: content) : content,
          ),
        ],
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
