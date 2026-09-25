/// Free-tier limits (PROJECT_MASTER_PLAN §20 — pricing is a hypothesis,
/// these are a starting point and easy to tune in one place).
class PlanLimits {
  static const int freeMaxActiveClients = 5;
  static const int freeMaxActiveRequests = 10;
  static const int freeMaxTemplates = 3;
}

/// Thrown when a free-plan business hits a limit. The UI catches this
/// specifically (rather than a generic Exception) to show an upgrade
/// prompt instead of a plain error message.
class FreeTierLimitException implements Exception {
  final String message;
  final String limitType; // 'clients' | 'requests' | 'templates'
  FreeTierLimitException(this.message, this.limitType);

  @override
  String toString() => message;
}