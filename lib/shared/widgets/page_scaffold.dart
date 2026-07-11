import 'package:flutter/material.dart';

import 'logout_button.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    required this.title,
    required this.children,
    this.actions = const [],
    super.key,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(title),
          actions: [...actions, const LogoutButton()],
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
              ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          sliver: SliverList.separated(
            itemBuilder: (_, index) => children[index],
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: children.length,
          ),
        ),
      ],
    );
  }
}
