import 'package:flutter/material.dart';

/// Panel allowing QA engineers to connect to the debug HTTP server.
class DebugServerPanel extends StatefulWidget {
  const DebugServerPanel({
    super.key,
    required this.onConnect,
    required this.onDisconnect,
    required this.remoteConnected,
    required this.errorText,
  });

  final ValueNotifier<bool> remoteConnected;
  final ValueNotifier<String?> errorText;
  final void Function(Uri baseUri, String token) onConnect;
  final VoidCallback onDisconnect;

  @override
  State<DebugServerPanel> createState() => _DebugServerPanelState();
}

class _DebugServerPanelState extends State<DebugServerPanel> {
  final _urlController =
      TextEditingController(text: 'http://127.0.0.1:8787');
  final _tokenController =
      TextEditingController(text: 'beatbox-debug');

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.remoteConnected,
      builder: (context, connected, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HTTP Debug Server',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    helperText: 'Example: http://127.0.0.1:8787',
                  ),
                  keyboardType: TextInputType.url,
                  enabled: !connected,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(
                    labelText: 'Token',
                    helperText: 'Passed via query/header for SSE + params',
                  ),
                  textInputAction: TextInputAction.done,
                  enabled: !connected,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: connected ? widget.onDisconnect : _handleConnect,
                    icon: Icon(connected ? Icons.link_off : Icons.link),
                    label: Text(connected ? 'Disconnect' : 'Connect'),
                  ),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<String?>(
                  valueListenable: widget.errorText,
                  builder: (context, error, __) => error == null
                      ? const SizedBox.shrink()
                      : Text(
                          error,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleConnect() {
    try {
      final uri = Uri.parse(_urlController.text.trim());
      final token = _tokenController.text.trim();
      widget.onConnect(uri, token);
    } on FormatException catch (error) {
      widget.errorText.value = 'Invalid URL: $error';
    }
  }
}
