import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config_service.dart';
import 'camera_list_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ipController.text = context.read<ConfigService>().backendHost;
  }

  void _connect() {
    if (_formKey.currentState?.validate() ?? false) {
      final configService = context.read<ConfigService>();
      final newIp = _ipController.text.trim();
      configService.updateBackendAddress(newIp); // Update the host IP

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CameraListPage()),
      );
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Backend')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Backend Server Address',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'Backend Host IP Address',
                    hintText: 'e.g., 192.168.1.100',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.computer),
                  ),
                  keyboardType: TextInputType.url, // Allows dots and numbers
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the backend IP address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Connect'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: _connect,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
