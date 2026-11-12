import 'dart:math';

import 'package:intl/intl.dart';
import 'application_state.dart';

class ApplicationService {
  static String generateReferenceNumber() {
    final year = DateTime.now().year;
    final random = Random.secure();
    final sequence = List.generate(12, (_) => random.nextInt(10)).join();
    return 'LA-$year-$sequence';
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
