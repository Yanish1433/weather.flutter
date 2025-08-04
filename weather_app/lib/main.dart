import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:weather_app/firebase_auth_implementation/firebase_options.dart';
import 'package:weather_app/firebase_auth_implementation/login.dart';
import 'package:weather_app/firebase_auth_implementation/signup.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const WeatherApp());
  } catch (e) {
    print('Firebase initialization failed: $e');
    runApp(const ErrorApp());
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Failed to initialize app. Please check your Firebase configuration.',
            style: TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      ),
    );
  }
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
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const WeatherScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return const WeatherScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final String apiKey = 'bd673a2172b621664a62c620e7808e2b'; // Valid for /weather and /forecast
  final String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  final String forecastUrl = 'https://api.openweathermap.org/data/2.5/forecast';
  String? city;
  String? temperature;
  String? description;
  String? rainChance;
  String? humidity;
  String? windSpeed;
  String? sunrise;
  String? sunset;
  int? timezoneOffset;
  Map<String, dynamic>? weatherData;
  bool isLoading = false;
  String errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  Future<void> fetchWeather(String query) async {
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Please enter a city name';
        isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
      city = null;
      temperature = null;
      description = null;
      rainChance = null;
      humidity = null;
      windSpeed = null;
      sunrise = null;
      sunset = null;
      timezoneOffset = null;
      weatherData = null;
    });

    try {
      final weatherUrl = Uri.parse('$baseUrl?q=$query&appid=$apiKey&units=metric');
      final weatherResponse = await http.get(weatherUrl);
      print('Weather API Response: ${weatherResponse.statusCode} - ${weatherResponse.body}');

      if (weatherResponse.statusCode == 200) {
        final data = jsonDecode(weatherResponse.body);
        final lat = data['coord']?['lat'] as num?;
        final lon = data['coord']?['lon'] as num?;
        final tzOffset = (data['timezone'] as int?) ?? 0;

        if (lat == null || lon == null) {
          if (!mounted) return;
          setState(() {
            errorMessage = 'Invalid coordinates returned for $query';
            isLoading = false;
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          weatherData = data;
          city = '${data['name'] ?? 'Unknown'}, ${data['sys']?['country'] ?? 'Unknown'}';
          temperature = '${(data['main']?['temp'] as num?)?.toStringAsFixed(1) ?? 'N/A'}°C';
          description = (data['weather']?[0]['description'] as String?)?.capitalize() ?? 'N/A';
          humidity = '${(data['main']?['humidity'] as num?)?.toStringAsFixed(0) ?? 'N/A'}%';
          windSpeed = '${((data['wind']?['speed'] as num?)?.toDouble() ?? 0) * 3.6}';
          timezoneOffset = tzOffset;

          final sunriseTime = DateTime.fromMillisecondsSinceEpoch(
            ((data['sys']?['sunrise'] as num?)?.toInt() ?? 0) * 1000,
            isUtc: true,
          ).add(Duration(seconds: tzOffset));
          final sunsetTime = DateTime.fromMillisecondsSinceEpoch(
            ((data['sys']?['sunset'] as num?)?.toInt() ?? 0) * 1000,
            isUtc: true,
          ).add(Duration(seconds: tzOffset));
          sunrise = DateFormat('h:mm a').format(sunriseTime);
          sunset = DateFormat('h:mm a').format(sunsetTime);
        });

        final forecastUrlFinal = Uri.parse('$forecastUrl?q=$query&appid=$apiKey&units=metric');
        final forecastResponse = await http.get(forecastUrlFinal);
        print('Forecast API Response: ${forecastResponse.statusCode} - ${forecastResponse.body}');

        if (forecastResponse.statusCode == 200) {
          final forecastData = jsonDecode(forecastResponse.body);
          if (!mounted) return;
          setState(() {
            rainChance = forecastData['list']?[0]?['pop'] != null
                ? '${(forecastData['list'][0]['pop'] * 100).toStringAsFixed(0)}%'
                : 'N/A';
          });
        } else {
          if (!mounted) return;
          setState(() {
            rainChance = 'N/A';
            errorMessage = 'Failed to fetch forecast: ${forecastResponse.statusCode} - ${forecastResponse.reasonPhrase}';
          });
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            print('Saving to Firestore for user: ${user.uid}');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('weather_searches')
                .add({
                  'city': city,
                  'temperature': temperature,
                  'description': description,
                  'humidity': humidity,
                  'windSpeed': windSpeed,
                  'sunrise': sunrise,
                  'sunset': sunset,
                  'rainChance': rainChance ?? 'N/A',
                  'timestamp': FieldValue.serverTimestamp(),
                });
          } catch (e) {
            if (!mounted) return;
            setState(() {
              errorMessage = 'Error saving to Firestore: $e';
              isLoading = false;
            });
            return;
          }
        }
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = 'City "$query" not found: ${weatherResponse.statusCode} - ${weatherResponse.reasonPhrase}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error fetching weather: $e';
        isLoading = false;
      });
    }
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchWeatherByLocation() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
      city = null;
      temperature = null;
      description = null;
      rainChance = null;
      humidity = null;
      windSpeed = null;
      sunrise = null;
      sunset = null;
      timezoneOffset = null;
      weatherData = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Location services are disabled';
          isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            errorMessage = 'Location permissions denied';
            isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Location permissions permanently denied';
          isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('Location: ${position.latitude}, ${position.longitude}');

      final weatherUrl = Uri.parse('$baseUrl?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric');
      final weatherResponse = await http.get(weatherUrl);
      print('Weather API Response: ${weatherResponse.statusCode} - ${weatherResponse.body}');

      if (weatherResponse.statusCode == 200) {
        final data = jsonDecode(weatherResponse.body);
        final lat = data['coord']?['lat'] as num?;
        final lon = data['coord']?['lon'] as num?;
        final tzOffset = (data['timezone'] as int?) ?? 0;

        if (lat == null || lon == null) {
          if (!mounted) return;
          setState(() {
            errorMessage = 'Invalid coordinates returned for location';
            isLoading = false;
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          weatherData = data;
          city = '${data['name'] ?? 'Unknown'}, ${data['sys']?['country'] ?? 'Unknown'}';
          temperature = '${(data['main']?['temp'] as num?)?.toStringAsFixed(1) ?? 'N/A'}°C';
          description = (data['weather']?[0]['description'] as String?)?.capitalize() ?? 'N/A';
          humidity = '${(data['main']?['humidity'] as num?)?.toStringAsFixed(0) ?? 'N/A'}%';
          windSpeed = '${((data['wind']?['speed'] as num?)?.toDouble() ?? 0) * 3.6}';
          timezoneOffset = tzOffset;

          final sunriseTime = DateTime.fromMillisecondsSinceEpoch(
            ((data['sys']?['sunrise'] as num?)?.toInt() ?? 0) * 1000,
            isUtc: true,
          ).add(Duration(seconds: tzOffset));
          final sunsetTime = DateTime.fromMillisecondsSinceEpoch(
            ((data['sys']?['sunset'] as num?)?.toInt() ?? 0) * 1000,
            isUtc: true,
          ).add(Duration(seconds: tzOffset));
          sunrise = DateFormat('h:mm a').format(sunriseTime);
          sunset = DateFormat('h:mm a').format(sunsetTime);
        });

        final forecastUrlFinal = Uri.parse('$forecastUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric');
        final forecastResponse = await http.get(forecastUrlFinal);
        print('Forecast API Response: ${forecastResponse.statusCode} - ${forecastResponse.body}');

        if (forecastResponse.statusCode == 200) {
          final forecastData = jsonDecode(forecastResponse.body);
          if (!mounted) return;
          setState(() {
            rainChance = forecastData['list']?[0]?['pop'] != null
                ? '${(forecastData['list'][0]['pop'] * 100).toStringAsFixed(0)}%'
                : 'N/A';
          });
        } else {
          if (!mounted) return;
          setState(() {
            rainChance = 'N/A';
            errorMessage = 'Failed to fetch forecast: ${forecastResponse.statusCode} - ${forecastResponse.reasonPhrase}';
          });
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            print('Saving to Firestore for user: ${user.uid}');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('weather_searches')
                .add({
                  'city': city,
                  'temperature': temperature,
                  'description': description,
                  'humidity': humidity,
                  'windSpeed': windSpeed,
                  'sunrise': sunrise,
                  'sunset': sunset,
                  'rainChance': rainChance ?? 'N/A',
                  'timestamp': FieldValue.serverTimestamp(),
                });
          } catch (e) {
            if (!mounted) return;
            setState(() {
              errorMessage = 'Error saving to Firestore: $e';
              isLoading = false;
            });
            return;
          }
        }
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Unable to fetch weather for location: ${weatherResponse.statusCode} - ${weatherResponse.reasonPhrase}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error fetching location weather: $e';
        isLoading = false;
      });
    }
    if (!mounted) return;
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

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
(context, '/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error signing out: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchWeatherByLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
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
                            onPressed: () =>
                                fetchWeather(_searchController.text.trim()),
                          ),
                        ),
                        onSubmitted: (value) => fetchWeather(value.trim()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.white),
                      onPressed: fetchWeatherByLocation,
                      tooltip: 'Use current location',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage.isNotEmpty
                    ? Center(
                        child: Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : city == null
                    ? const Center(
                        child: Text(
                          'Search for a city or use location to view weather',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getWeatherIcon(
                                  weatherData?['weather']?[0]['main'],
                                ),
                                color: Colors.orange,
                                size: 40,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('EEEE, hh:mm a').format(
                                      DateTime.now().toUtc().add(
                                        Duration(seconds: timezoneOffset ?? 0),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  Text(
                                    description ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    temperature ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    city ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[800]?.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.wb_sunny,
                                      color: Color(0xFFFFD700),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      sunrise ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '------  ${DateFormat('h:mm a').format(DateTime.now().toUtc().add(Duration(seconds: timezoneOffset ?? 0)))}  ------',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.wb_sunny,
                                      color: Color(0xFFFFD700),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      sunset ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildWeatherCard(
                                'Rain',
                                rainChance ?? 'N/A',
                                Icons.water_drop,
                              ),
                              _buildWeatherCard(
                                'Humidity',
                                humidity ?? 'N/A',
                                Icons.opacity,
                              ),
                              _buildWeatherCard(
                                'Wind',
                                windSpeed ?? 'N/A',
                                Icons.air,
                              ),
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
        color: Colors.grey[800]?.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          Text(title, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
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