import 'package:flutter/material.dart';
import '../screens/settings/subscription_screen.dart';
import '../services/plan_limits.dart';

/// Shows an upgrade dialog for a [FreeTierLimitException], or falls back
/// to a plain error snackbar for anything else. Returns true if the user
/// tapped Upgrade (caller can decide whether to retry after that).
Future<bool> showUpgradePromptIfLimitReached(BuildContext context, Object error) async {
  if (error is! FreeTierLimitException) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
    return false;
  }

  final upgrade = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Free plan limit reached'),
      content: Text(error.message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upgrade')),
      ],
    ),
  );

  if (upgrade == true && context.mounted) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
  }
  return upgrade == true;
}