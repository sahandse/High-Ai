/// Lifecycle state of the on-device model, as shown in Settings → Models.
enum ModelStatus {
  notInstalled,
  downloading,
  verifying,
  ready,
  loading,
  loaded,
  error,
}
