import 'dart:async';
import 'dart:io';

/// Retries a future-returning operation on transient network failures
/// (GLOBAL_READINESS §1.T — "automatic retry", scoped to real network
/// errors only, not validation/business-logic exceptions).
Future<T> withRetry<T>(
    Future<T> Function() operation, {
      int maxAttempts = 3,
      Duration initialDelay = const Duration(milliseconds: 500),
    }) async {
  var attempt = 0;
  var delay = initialDelay;

  while (true) {
    attempt++;
    try {
      return await operation();
    } catch (e) {
      final isNetworkError = e is SocketException ||
          e is TimeoutException ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('failed host lookup');

      if (!isNetworkError || attempt >= maxAttempts) {
        rethrow;
      }
      await Future.delayed(delay);
      delay *= 2;
    }
  }
}