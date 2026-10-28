import 'package:intl/intl.dart';
import 'application_state.dart';

class ApplicationService {
  static String generateReferenceNumber() {
    final year = DateTime.now().year;
    final sequence = DateTime.now().millisecondsSinceEpoch % 1000000;
    return 'LA-$year-${sequence.toString().padLeft(6, '0')}';
  }

  static String formatSubmissionDateTime() {
    final now = DateTime.now();
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final timeFormat = DateFormat('h:mm a');
    return '${dateFormat.format(now)} • ${timeFormat.format(now)}';
  }

  static String getExpectedProcessingTime() {
    final configured = ApplicationState.loanProcessingTime?.trim();
    if (configured == null || configured.isEmpty)
      return 'Contact Cooperative Admin';
    return '$configured Working Days';
  }
}
