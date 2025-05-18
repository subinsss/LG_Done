import 'package:firebase_analytics/firebase_analytics.dart';

Future<void> logGoogleAnalyticsEvent(String eventName, Map<String, Object> eventParams) async {
  await FirebaseAnalytics.instance.logEvent(
    name: eventName,
    parameters: eventParams,
  );
}
