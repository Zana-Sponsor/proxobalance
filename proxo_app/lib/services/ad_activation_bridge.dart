/// Optional foreground delivery hook. Returning false preserves the existing
/// system-notification fallback when the in-app notice cannot be verified.
abstract final class AdActivationBridge {
  static Future<bool> Function(Map<String, dynamic>)? onForeground;
}
