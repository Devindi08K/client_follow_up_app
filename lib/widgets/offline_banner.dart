import 'dart:async';
import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Wraps the whole app and shows a persistent "you're offline" banner
/// (PRODUCT_SPECIFICATION §20 — Offline Behavior).
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> with WidgetsBindingObserver {
  late bool _online;
  late final StreamSubscription<bool> _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _online = ConnectivityService.instance.isOnlineLastKnown;
    _subscription = ConnectivityService.instance.onStatusChanged.listen((online) {
      if (mounted) setState(() => _online = online);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ConnectivityService.instance.checkNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _online
              ? const SizedBox(width: double.infinity)
              : Material(
            color: AppColors.rust,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: const [
                    Icon(Icons.cloud_off_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You're offline. Showing your last synced data.",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}