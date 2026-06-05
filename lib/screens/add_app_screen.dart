import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class AddAppScreen extends StatefulWidget {
  const AddAppScreen({Key? key}) : super(key: key);

  @override
  State<AddAppScreen> createState() => _AddAppScreenState();
}

class _AddAppScreenState extends State<AddAppScreen> {
  late TextEditingController _appNameController;
  late TextEditingController _packageNameController;
  int _dailyLimitMinutes = 30;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _appNameController = TextEditingController();
    _packageNameController = TextEditingController();
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _packageNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add App to Blocklist'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _appNameController,
              label: 'App Name',
              hint: 'e.g., Instagram',
              icon: Icons.app_shortcut,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _packageNameController,
              label: 'Package Name',
              hint: 'e.g., com.instagram.android',
              icon: Icons.code,
            ),
            const SizedBox(height: 24),
            _buildDailyLimitSlider(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyLimitSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Limit',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '$_dailyLimitMinutes minutes',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: const Color(0xFF8B0000),
                      ),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _dailyLimitMinutes.toDouble(),
                  min: 5,
                  max: 480,
                  divisions: 95,
                  label: '$_dailyLimitMinutes min',
                  activeColor: const Color(0xFF8B0000),
                  onChanged: (value) {
                    setState(() => _dailyLimitMinutes = value.toInt());
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '5 min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '480 min (8 hours)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _isLoading ? null : _addApp,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: const Text('Add App'),
          ),
        ),
      ],
    );
  }

  Future<void> _addApp() async {
    final appName = _appNameController.text.trim();
    final packageName = _packageNameController.text.trim();

    if (appName.isEmpty) {
      _showErrorDialog('Please enter app name');
      return;
    }

    if (packageName.isEmpty) {
      _showErrorDialog('Please enter package name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AppProvider>().addApp(
            packageName,
            appName,
            _dailyLimitMinutes,
          );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$appName added to blocklist'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorDialog('Error adding app: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
