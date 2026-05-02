// main_shell.dart — backward-compatible alias for ParentShell.
// Existing imports that reference MainShell continue to work.
export 'parent_shell.dart';

import 'package:flutter/material.dart';
import 'parent_shell.dart';

/// Alias so that `MainShell` references in legacy code resolve correctly.

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) => const ParentShell();
}
