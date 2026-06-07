import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/blocked_app_model.dart';
import '../providers/app_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/exercise_provider.dart';

class AppDetailsScreen extends StatefulWidget {
  final int appId;

  const AppDetailsScreen({super.key, required this.appId});

  @override
  State<AppDetailsScreen> createState() => _AppDetailsScreenState();
}

class _AppDetailsScreenState extends State<AppDetailsScreen> {
  int? _localLimit;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Details'),
      ),
      body: Consumer3<AppProvider, TimerProvider, ExerciseProvider>(
        builder: (context, appProvider, timerProvider, exerciseProvider, _) {
          final app = appProvider.getAppById(widget.appId);
          if (app == null) {
            return const Center(
              child: Text('App not found or has been deleted.'),
            );
          }

          _localLimit ??= app.dailyLimitMinutes;

          // Fetch usage stats
          final todayUsage = timerProvider.getDailyUsage(app.packageName);
          final limit = app.dailyLimitMinutes;
          final remaining = (limit - todayUsage).clamp(0, limit);
          final remainingPct = limit > 0 ? remaining / limit : 0.0;

          // Count completed exercises today
          final todayExercisesCount = exerciseProvider.todayExercises
              .where((e) => e.isCompleted)
              .length; // Approximate count

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(context, app, todayUsage, limit),
                const SizedBox(height: 16),
                _buildUsageSection(context, todayUsage, limit, remaining, remainingPct),
                const SizedBox(height: 16),
                _buildLimitControlCard(context, appProvider, app),
                const SizedBox(height: 16),
                _buildStatusToggleCard(context, appProvider, app),
                const SizedBox(height: 16),
                _buildExerciseStatsCard(context, todayExercisesCount),
                const SizedBox(height: 32),
                _buildDeleteButton(context, appProvider, app),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, BlockedApp app, int todayUsage, int limit) {
    final statusColor = app.isActive
        ? (todayUsage >= limit ? Colors.redAccent : Colors.greenAccent)
        : Colors.grey;
    final statusText = app.isActive
        ? (todayUsage >= limit ? 'BLOCKED' : 'MONITORED')
        : 'PAUSED';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFF8B0000),
              child: Text(
                app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.appName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.packageName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.solid,
                      borderWidth: 0.5,
                      borderColor: statusColor,
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageSection(BuildContext context, int todayUsage, int limit, int remaining, double remainingPct) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Usage",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (1.0 - remainingPct).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[800],
              color: remainingPct < 0.15 ? Colors.redAccent : const Color(0xFF8B0000),
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimeDetailItem('Used', '$todayUsage min'),
                _buildTimeDetailItem('Remaining', '$remaining min'),
                _buildTimeDetailItem('Limit', '$limit min'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDetailItem(String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLimitControlCard(BuildContext context, AppProvider appProvider, BlockedApp app) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Lock Limit',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_localLimit minutes',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF8B0000)),
                ),
                if (_localLimit != app.dailyLimitMinutes)
                  ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveLimit(appProvider, app),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B0000),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save'),
                  ),
              ],
            ),
            Slider(
              value: _localLimit!.toDouble(),
              min: 5,
              max: 480,
              divisions: 95,
              activeColor: const Color(0xFF8B0000),
              onChanged: (value) {
                setState(() {
                  _localLimit = value.toInt();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusToggleCard(BuildContext context, AppProvider appProvider, BlockedApp app) {
    return Card(
      child: SwitchListTile(
        title: const Text('Enable Blocking', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('If off, this app will not be blocked when the daily limit is reached.'),
        value: app.isActive,
        activeColor: const Color(0xFF8B0000),
        onChanged: (value) async {
          await appProvider.toggleAppStatus(app.id!, value);
        },
      ),
    );
  }

  Widget _buildExerciseStatsCard(BuildContext context, int exerciseCount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.fitness_center, color: Color(0xFF8B0000), size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exercises Completed Today', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('$exerciseCount sessions', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context, AppProvider appProvider, BlockedApp app) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: () => _confirmDelete(context, appProvider, app),
        icon: const Icon(Icons.delete_forever),
        label: const Text('Remove from Blocklist', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _saveLimit(AppProvider appProvider, BlockedApp app) async {
    setState(() => _isSaving = true);
    try {
      await appProvider.updateDailyLimit(app.id!, _localLimit!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily limit updated successfully.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _confirmDelete(BuildContext context, AppProvider appProvider, BlockedApp app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove App?'),
        content: Text('Are you sure you want to remove ${app.appName} from your blocklist? All history and limits will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await appProvider.deleteApp(app.id!);
              if (context.mounted) {
                Navigator.pop(context); // Close details screen
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
