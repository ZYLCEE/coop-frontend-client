class ApplicationState {
  static String? loanProcessingTime;
  static bool _hasPendingApplication = false;

  static bool get hasPendingApplication => _hasPendingApplication;

  static void setPendingApplication(bool value) {
    _hasPendingApplication = value;
  }

  static void clearPendingApplication() {
    _hasPendingApplication = false;
  }
}
