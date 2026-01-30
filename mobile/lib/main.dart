import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// TODO: Replace with your Supabase credentials
const supabaseUrl = 'YOUR_SUPABASE_URL';
const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

// TODO: Replace with your server URL (use your computer's IP for real device testing)
// For emulator use: http://10.0.2.2:3001
// For real device use your computer's local IP: http://192.168.x.x:3001
const notificationApiUrl = 'http://localhost:3001/api/send-notification';

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Push Notification Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const NotificationHomePage(),
    );
  }
}

class NotificationHomePage extends StatefulWidget {
  const NotificationHomePage({super.key});

  @override
  State<NotificationHomePage> createState() => _NotificationHomePageState();
}

class _NotificationHomePageState extends State<NotificationHomePage> {
  String _fcmToken = '';
  String _statusMessage = 'Initializing...';
  final List<String> _notifications = [];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      // Request permission (required for iOS)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        setState(() => _statusMessage = 'Permission granted');

        // Get FCM token
        final token = await messaging.getToken();
        if (token != null) {
          setState(() => _fcmToken = token);
          await _saveTokenToSupabase(token);
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) async {
          setState(() => _fcmToken = newToken);
          await _saveTokenToSupabase(newToken);
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          if (notification != null) {
            setState(() {
              _notifications.insert(
                0,
                '${notification.title}: ${notification.body}',
              );
            });

            // Show a snackbar
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${notification.title}'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        });

        // Handle notification tap (when app was in background)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final notification = message.notification;
          if (notification != null) {
            setState(() {
              _notifications.insert(
                0,
                '[Tapped] ${notification.title}: ${notification.body}',
              );
            });
          }
        });

        setState(() => _statusMessage = 'Ready to receive notifications');
      } else {
        setState(() => _statusMessage = 'Permission denied');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    try {
      final supabase = Supabase.instance.client;
      final platform = Platform.isIOS ? 'ios' : 'android';

      log('Saving token to Supabase...');
      log('Token: ${token.substring(0, 20)}...');

      // First, check if token already exists
      final existing = await supabase
          .from('fcm_tokens')
          .select('id')
          .eq('token', token)
          .maybeSingle();

      if (existing != null) {
        // Update existing token
        await supabase.from('fcm_tokens').update({
          'platform': platform,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('token', token);
        log('Token updated in Supabase');
      } else {
        // Insert new token
        await supabase.from('fcm_tokens').insert({
          'token': token,
          'platform': platform,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        log('Token inserted in Supabase');
      }

      setState(() => _statusMessage = 'Token saved to Supabase');

      // Check if this is first install and send welcome notification
      final prefs = await SharedPreferences.getInstance();
      final isFirstInstall = prefs.getBool('first_install') ?? true;

      if (isFirstInstall) {
        await _sendWelcomeNotification(token);
        await prefs.setBool('first_install', false);
      }
    } catch (e, stackTrace) {
      log('Failed to save token: $e');
      log('Stack trace: $stackTrace');
      setState(() => _statusMessage = 'Failed to save token: $e');
    }
  }

  Future<void> _sendWelcomeNotification(String token) async {
    try {
      final response = await http.post(
        Uri.parse(notificationApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tokens': [token],
          'title': 'Welcome!',
          'body': 'Thanks for installing the app. You will now receive notifications.',
        }),
      );

      if (response.statusCode == 200) {
        log('Welcome notification sent successfully');
        setState(() => _statusMessage = 'Welcome notification sent!');
      } else {
        log('Failed to send welcome notification: ${response.body}');
      }
    } catch (e) {
      log('Error sending welcome notification: $e');
      // Don't update status - this is optional and shouldn't block the user
    }
  }

  @override
  Widget build(BuildContext context) {
    log("Status Message - $_statusMessage");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Push Notifications'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // FCM Token card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FCM Token',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _fcmToken.isEmpty ? 'Loading...' : _fcmToken,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notifications list
            Text(
              'Received Notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(
                      child: Text('No notifications yet'),
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.notifications),
                            title: Text(_notifications[index]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
