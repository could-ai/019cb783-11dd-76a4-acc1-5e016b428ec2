import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum HAConnectionState { disconnected, connecting, authenticating, connected, error }

class HomeAssistantService with ChangeNotifier {
  WebSocketChannel? _channel;
  HAConnectionState _connectionState = HAConnectionState.disconnected;
  final FlutterTts _flutterTts = FlutterTts();
  
  String? _url;
  String? _token;
  final List<String> _logs = [];
  int _idCounter = 1;

  HAConnectionState get connectionState => _connectionState;
  List<String> get logs => _logs;

  HomeAssistantService() {
    _loadSettings();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("pl-PL");
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _url = prefs.getString('ha_url');
    _token = prefs.getString('ha_token');
    if (_url != null && _token != null) {
      connect();
    }
  }

  Future<void> saveSettings(String url, String token) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Ensure URL has correct format for WebSocket
    String cleanUrl = url.replaceAll('http://', '').replaceAll('https://', '');
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    
    await prefs.setString('ha_url', cleanUrl);
    await prefs.setString('ha_token', token);
    _url = cleanUrl;
    _token = token;
    connect();
  }

  void connect() {
    if (_url == null || _token == null) return;

    _updateState(HAConnectionState.connecting);
    _addLog("Łączenie z $_url...");

    try {
      // Determine scheme (ws or wss)
      // Assuming ws for local IP, wss for domains usually, but let's default to ws for IP
      final scheme = _url!.contains('192.168') || _url!.contains('.local') ? 'ws' : 'wss';
      final wsUrl = Uri.parse('$scheme://$_url/api/websocket');

      _channel = WebSocketChannel.connect(wsUrl);
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) {
          _updateState(HAConnectionState.error);
          _addLog("Błąd połączenia: $error");
        },
        onDone: () {
          _updateState(HAConnectionState.disconnected);
          _addLog("Rozłączono.");
        },
      );
    } catch (e) {
      _updateState(HAConnectionState.error);
      _addLog("Błąd krytyczny: $e");
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _updateState(HAConnectionState.disconnected);
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      if (type == 'auth_required') {
        _updateState(HAConnectionState.authenticating);
        _addLog("Wymagana autoryzacja...");
        _sendAuth();
      } else if (type == 'auth_ok') {
        _updateState(HAConnectionState.connected);
        _addLog("Zalogowano pomyślnie!");
        _subscribeToEvents();
      } else if (type == 'auth_invalid') {
        _updateState(HAConnectionState.error);
        _addLog("Błąd logowania: ${data['message']}");
        disconnect();
      } else if (type == 'event') {
        _handleEvent(data['event']);
      }
    } catch (e) {
      print("Error parsing message: $e");
    }
  }

  void _sendAuth() {
    final authMessage = {
      'type': 'auth',
      'access_token': _token
    };
    _channel?.sink.add(jsonEncode(authMessage));
  }

  void _subscribeToEvents() {
    // Subscribe to a custom event type that we will use for TTS
    // Users can trigger this from HA automations
    final subscribeMessage = {
      'id': _idCounter++,
      'type': 'subscribe_events',
      'event_type': 'android_speaker_tts' 
    };
    _channel?.sink.add(jsonEncode(subscribeMessage));
    _addLog("Nasłuchiwanie zdarzeń 'android_speaker_tts'...");
  }

  void _handleEvent(Map<dynamic, dynamic> event) {
    final data = event['data'];
    if (data != null && data['message'] != null) {
      String message = data['message'];
      _addLog("Otrzymano polecenie głosowe: $message");
      _speak(message);
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _updateState(HAConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  void _addLog(String log) {
    final time = DateTime.now().toString().split('.').first;
    _logs.insert(0, "[$time] $log");
    if (_logs.length > 50) _logs.removeLast();
    notifyListeners();
  }
}
