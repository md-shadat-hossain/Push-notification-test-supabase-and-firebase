import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TODO: Replace with your Supabase credentials
const supabaseUrl = 'https://kvuzupuyzpmdljwukmfa.supabase.co';
const supabaseAnonKey = 'sb_publishable_J2o5olE2lLSXvC4anTGcKQ_XjVrsWeP';

// Local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Android notification channel with sound
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
  playSound: true,
);

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _showNotification(message);
}

// Show local notification with sound
Future<void> _showNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  await flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Local Notifications
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // Create Android notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

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

// Notification model
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String sentAt;
  final String status;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    required this.status,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final notification = json['notifications'] as Map<String, dynamic>?;
    return NotificationItem(
      id: notification?['id'] ?? json['id'] ?? '',
      title: notification?['title'] ?? json['title'] ?? '',
      body: notification?['body'] ?? json['body'] ?? '',
      sentAt: notification?['sent_at'] ?? json['sent_at'] ?? '',
      status: json['status'] ?? 'sent',
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
  bool _isSaving = false;
  bool _isLoading = false;
  List<NotificationItem> _notifications = [];

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
          setState(() {
            _fcmToken = token;
            _statusMessage = 'Ready - Click button to register device';
          });
          // Load notifications for this token
          await _loadNotificationsFromSupabase();
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) async {
          setState(() => _fcmToken = newToken);
        });

        // Handle foreground messages - show notification with sound
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          final notification = message.notification;
          if (notification != null) {
            // Show local notification with sound
            await _showNotification(message);

            // Reload notifications from Supabase
            await _loadNotificationsFromSupabase();
          }
        });

        // Handle notification tap (when app was in background)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _loadNotificationsFromSupabase();
        });
      } else {
        setState(() => _statusMessage = 'Permission denied');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  Future<void> _loadNotificationsFromSupabase() async {
    if (_fcmToken.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('notification_recipients')
          .select('''
            id,
            status,
            created_at,
            notifications (
              id,
              title,
              body,
              sent_at
            )
          ''')
          .eq('fcm_token', _fcmToken)
          .order('created_at', ascending: false);

      final List<NotificationItem> notifications = [];
      for (final item in response) {
        if (item['notifications'] != null) {
          notifications.add(NotificationItem.fromJson(item));
        }
      }

      setState(() {
        _notifications = notifications;
        _statusMessage = 'Loaded ${notifications.length} notifications';
      });
    } catch (e) {
      log('Error loading notifications: $e');
      setState(() => _statusMessage = 'Error loading notifications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _statusMessage = 'Saving token...';
    });

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
        setState(() => _statusMessage = 'Device already registered (updated)');
      } else {
        // Insert new token
        await supabase.from('fcm_tokens').insert({
          'token': token,
          'platform': platform,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        log('Token inserted in Supabase');
        setState(() => _statusMessage = 'Device registered successfully!');
      }
    } catch (e, stackTrace) {
      log('Failed to save token: $e');
      log('Stack trace: $stackTrace');
      setState(() => _statusMessage = 'Failed to save token: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
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

            // Buttons Row
            Row(
              children: [
                // Register Device Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _fcmToken.isEmpty || _isSaving
                        ? null
                        : () => _saveTokenToSupabase(_fcmToken),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isSaving ? 'Registering...' : 'Register'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Refresh Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _fcmToken.isEmpty || _isLoading
                        ? null
                        : _loadNotificationsFromSupabase,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_isLoading ? 'Loading...' : 'Refresh'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notifications list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications (${_notifications.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                      ? const Center(
                          child: Text('No notifications yet'),
                        )
                      : ListView.builder(
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notif = _notifications[index];
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  Icons.notifications,
                                  color: notif.status == 'sent'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                title: Text(notif.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(notif.body),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(notif.sentAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
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
