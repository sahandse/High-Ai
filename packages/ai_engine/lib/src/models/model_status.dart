/// Lifecycle state of the on-device model, as shown in Settings → Models.
enum ModelStatus {
  notInstalled,
  downloading,

  /// A download was paused by the user — the partial file is kept on disk
  /// and downloading can resume from where it left off.
  paused,
  verifying,
  ready,
  loading,
  loaded,
  error,
}
