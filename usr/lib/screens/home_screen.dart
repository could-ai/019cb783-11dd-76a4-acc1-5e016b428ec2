import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ha_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final haService = context.watch<HomeAssistantService>();
    
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (haService.connectionState) {
      case HAConnectionState.connected:
        statusColor = Colors.green;
        statusText = "Połączono";
        statusIcon = Icons.check_circle;
        break;
      case HAConnectionState.connecting:
      case HAConnectionState.authenticating:
        statusColor = Colors.orange;
        statusText = "Łączenie...";
        statusIcon = Icons.sync;
        break;
      case HAConnectionState.error:
        statusColor = Colors.red;
        statusText = "Błąd";
        statusIcon = Icons.error;
        break;
      case HAConnectionState.disconnected:
      default:
        statusColor = Colors.grey;
        statusText = "Rozłączono";
        statusIcon = Icons.offline_bolt;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HA Głośnik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: statusColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, color: statusColor, size: 30),
                const SizedBox(width: 10),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (haService.connectionState == HAConnectionState.disconnected)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
                child: const Text("Skonfiguruj połączenie"),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: haService.logs.length,
              itemBuilder: (context, index) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      haService.logs[index],
                      style: const TextStyle(fontSize: 12, fontFamily: 'Monospace'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
