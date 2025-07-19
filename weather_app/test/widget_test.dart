import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/main.dart'; // Adjust this import if needed

void main() {
  testWidgets('WeatherApp loads and shows a loading indicator', (WidgetTester tester) async {
    // Build the weather app widget
    await tester.pumpWidget(WeatherApp());

    // Check that CircularProgressIndicator is shown (data loading)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // You could also wait and pump more frames to test later states
    // but it would require mocking network requests
  });
}
