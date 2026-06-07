import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/exercise_model.dart';
import '../providers/app_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/timer_provider.dart';
import 'add_app_screen.dart';
import 'exercise_detection_screen.dart';
import 'analytics_screen.dart';
import 'app_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _platform = MethodChannel('com.taskandunlock.app/blocker');
  bool _isAccessibilityEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshApps();
      context.read<ExerciseProvider>().refreshExercises();
      _checkAccessibilityStatus();
      _checkBlockedLaunchIntent();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppProvider>().refreshApps();
      context.read<ExerciseProvider>().refreshExercises();
      _checkAccessibilityStatus();
      _checkBlockedLaunchIntent();
    }
  }

  Future<void> _checkAccessibilityStatus() async {
    try {
      final bool enabled = await _platform.invokeMethod('isAccessibilityServiceEnabled');
      setState(() {
        _isAccessibilityEnabled = enabled;
      });
    } catch (e) {
      print('Error checking accessibility status: $e');
    }
  }

  Future<void> _checkBlockedLaunchIntent() async {
    try {
      final String? packageName = await _platform.invokeMethod('getLaunchBlockedPackage');
      if (packageName != null) {
        final appProvider = context.read<AppProvider>();
        final app = appProvider.getAppByPackage(packageName);
        if (app != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseDetectionScreen(
                exerciseType: ExerciseType.pushups,
                targetReps: Exercise.pushupsReps,
                appId: app.id!,
                appName: app.appName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking launch intent: $e');
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await _platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print('Error opening settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task And Unlock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AppProvider>().refreshApps();
              context.read<ExerciseProvider>().refreshExercises();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B0000),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAppScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add App'),
      ),
      body: Consumer2<AppProvider, ExerciseProvider>(
        builder: (context, appProvider, exerciseProvider, _) {
          if (appProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B0000)),
            );
          }

          if (appProvider.blockedApps.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone_android, size: 72, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No blocked apps yet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add apps to your blocklist and complete exercises to unlock them when you exceed your daily limit.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              if (!_isAccessibilityEnabled) _buildAccessibilityWarningCard(),
              _buildStatsCard(context, appProvider, exerciseProvider),
              const SizedBox(height: 16),
              Text(
                'Blocked Apps',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...appProvider.blockedApps.map(
                (app) => _buildAppCard(context, app),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    AppProvider appProvider,
    ExerciseProvider exerciseProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              context,
              'Active',
              '${appProvider.getActiveBlockedApps()}',
              Icons.block,
            ),
            _buildStatItem(
              context,
              'Exercises Today',
              '${exerciseProvider.getTodayExerciseCount()}',
              Icons.fitness_center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityWarningCard() {
    return Card(
      color: const Color(0xFF8B0000).withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF8B0000), width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Permission Required',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'The app blocker cannot detect or lock background apps unless the Accessibility Service is enabled.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                  foregroundColor: Colors.white,
                ),
                onPressed: _openAccessibilitySettings,
                icon: const Icon(Icons.settings),
                label: const Text('Enable Accessibility Service'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF8B0000)),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAppCard(BuildContext context, app) {
    final timerProvider = context.read<TimerProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF8B0000),
          child: Text(
            app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(app.appName),
        subtitle: Text(
          '${app.dailyLimitMinutes} min/day • ${app.isActive ? "Active" : "Paused"}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'toggle') {
              await context
                  .read<AppProvider>()
                  .toggleAppStatus(app.id!, !app.isActive);
            } else if (value == 'exercise') {
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExerciseDetectionScreen(
                    exerciseType: ExerciseType.pushups,
                    targetReps: Exercise.pushupsReps,
                    appId: app.id!,
                    appName: app.appName,
                  ),
                ),
              );
            } else if (value == 'delete') {
              await context.read<AppProvider>().deleteApp(app.id!);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'exercise',
              child: Text('Start Exercise'),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Text(app.isActive ? 'Pause' : 'Activate'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AppDetailsScreen(appId: app.id!),
            ),
          );
        },
      ),
    );
  }
}
