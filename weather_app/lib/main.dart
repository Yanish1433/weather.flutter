import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.grey[850],
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      home: const WeatherScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final String apiKey = 'bd673a2172b621664a62c620e7808e2b';
  final String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  final String oneCallUrl = 'https://api.openweathermap.org/data/2.5/onecall';
  String? city; // Changed to nullable
  String? temperature;
  String? description;
  String? rainChance;
  String? humidity;
  String? windSpeed;
  String? sunrise;
  String? sunset;
  bool isLoading = false;
  String errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  Future<void> fetchWeather(String query) async {
    if (query.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a city name';
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Fetch current weather to get lat and lon
      final weatherUrl = Uri.parse('$baseUrl?q=$query&appid=$apiKey&units=metric');
      final weatherResponse = await http.get(weatherUrl);

      if (weatherResponse.statusCode == 200) {
        final weatherData = jsonDecode(weatherResponse.body);
        final lat = weatherData['coord']['lat'];
        final lon = weatherData['coord']['lon'];
        final timezoneOffset = (weatherData['timezone'] as int?) ?? 0; // In seconds

        // Calculate local time and weekday
        final localTime = DateTime.now().toUtc().add(Duration(seconds: timezoneOffset));
        final weekday = DateFormat('EEEE').format(localTime);
        final formattedTime = DateFormat('hh:mm a').format(localTime);

        setState(() {
          city = '${weatherData['name']}, ${weatherData['sys']['country'] ?? 'Unknown'}';
          temperature = '${(weatherData['main']['temp'] as num?)?.toStringAsFixed(1) ?? 'N/A'}°C';
          description = (weatherData['weather']?[0]['description'] as String?)?.capitalize() ?? 'N/A';
          humidity = '${(weatherData['main']['humidity'] as num?)?.toStringAsFixed(0) ?? 'N/A'}%';
          windSpeed = '${((weatherData['wind']['speed'] as num?)?.toDouble() ?? 0 * 3.6).toStringAsFixed(0)} km/h';

          final sunriseTime = DateTime.fromMillisecondsSinceEpoch(
            (weatherData['sys']['sunrise'] as num?)?.toInt() ?? 0 * 1000,
            isUtc: true,
          ).add(Duration(seconds: timezoneOffset));
          final sunsetTime = DateTime.fromMillisecondsSinceEpoch(
            (weatherData['sys']['sunset'] as num?)?.toInt() ?? 0 * 1000,
            isUtc: true,
          ).add(Duration(seconds: timezoneOffset));
          sunrise = DateFormat('h:mm a').format(sunriseTime);
          sunset = DateFormat('h:mm a').format(sunsetTime);
        });

        // Fetch one call API for rain chance
        final oneCallUrlFinal = Uri.parse('$oneCallUrl?lat=$lat&lon=$lon&exclude=minutely,hourly,daily&appid=$apiKey&units=metric');
        final oneCallResponse = await http.get(oneCallUrlFinal);

        if (oneCallResponse.statusCode == 200) {
          final oneCallData = jsonDecode(oneCallResponse.body);
          setState(() {
            rainChance = '${((oneCallData['daily']?[0]['pop'] as num?)?.toDouble() ?? 0 * 100).toStringAsFixed(0)}%';
          });
        }
      } else {
        setState(() {
          errorMessage = 'City not found or invalid request';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
    setState(() {
      isLoading = false;
    });
  }

  IconData _getWeatherIcon(String? weatherMain) {
    if (weatherMain == null) return Icons.wb_cloudy;
    switch (weatherMain.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.wb_cloudy;
      case 'rain':
        return Icons.water_drop;
      case 'thunderstorm':
        return Icons.thunderstorm;
      default:
        return Icons.wb_cloudy;
    }
  }

  @override
  void initState() {
    super.initState();
    // Removed fetchWeather('Kyiv') to avoid initial API call
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E2E2E), Color(0xFF1A1A1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Enter city name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () => fetchWeather(_searchController.text.trim()),
                    ),
                  ),
                  onSubmitted: (value) => fetchWeather(value.trim()),
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage.isNotEmpty
                        ? Center(
                            child: Text(
                              errorMessage,
                              style: const TextStyle(color: Colors.red, fontSize: 18),
                            ),
                          )
                        : city == null
                            ? const Center(
                                child: Text(
                                  'Search for a city to view weather',
                                  style: TextStyle(color: Colors.white70, fontSize: 18),
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.all(16.0),
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_getWeatherIcon(description), color: Colors.orange, size: 40),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            DateFormat('EEEE, hh:mm a').format(
                                              DateTime.now().toUtc().add(const Duration(seconds: 0)), // Use API timezone offset if available
                                            ),
                                            style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                                          ),
                                          Text(
                                            description!,
                                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          Text(
                                            temperature!,
                                            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          Text(
                                            city!,
                                            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.wb_sunny, color: Color(0xFFFFD700)),
                                            const SizedBox(width: 5),
                                            Text(sunrise!, style: const TextStyle(color: Colors.white)),
                                          ],
                                        ),
                                        Text(
                                          '------  ${(DateTime.now().toUtc().hour)}h ${(DateTime.now().toUtc().minute)}m  ------',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.wb_sunny, color: Color(0xFFFFD700)),
                                            const SizedBox(width: 5),
                                            Text(sunset!, style: const TextStyle(color: Colors.white)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildWeatherCard('Rain', rainChance!, Icons.water_drop),
                                      _buildWeatherCard('Humidity', humidity!, Icons.opacity),
                                      _buildWeatherCard('Wind', windSpeed!, Icons.air),
                                    ],
                                  ),
                                ],
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          Text(title, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}