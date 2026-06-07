import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/exercise_model.dart';
import '../providers/exercise_provider.dart';
import '../providers/app_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & History'),
      ),
      body: Consumer2<ExerciseProvider, AppProvider>(
        builder: (context, exerciseProvider, appProvider, _) {
          if (exerciseProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B0000)),
            );
          }

          final todayCount = exerciseProvider.getTodayExerciseCount();
          final pushupReps = exerciseProvider.getTotalRepsToday(ExerciseType.pushups);
          final jumpReps = exerciseProvider.getTotalRepsToday(ExerciseType.jumps);
          
          final hasData = exerciseProvider.exercises.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(context, todayCount, pushupReps, jumpReps),
                const SizedBox(height: 24),
                if (hasData) ...[
                  Text(
                    'Exercise Split',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildPieChartCard(context, pushupReps, jumpReps),
                  const SizedBox(height: 24),
                ],
                Text(
                  'Recent Exercise History',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (!hasData)
                  _buildNoDataWidget(context)
                else
                  _buildHistoryList(context, exerciseProvider.exercises),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, int todayCount, int pushups, int jumps) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          context,
          'Total Sessions',
          '$todayCount',
          'Completed today',
          Icons.calendar_today,
          const Color(0xFF8B0000),
        ),
        _buildStatCard(
          context,
          'Pushup Reps',
          '$pushups',
          'Completed today',
          Icons.fitness_center,
          const Color(0xFFE53935),
        ),
        _buildStatCard(
          context,
          'Jump Reps',
          '$jumps',
          'Completed today',
          Icons.directions_run,
          const Color(0xFFFB8C00),
        ),
        _buildStatCard(
          context,
          'Daily Streak',
          todayCount > 0 ? '1 day' : '0 days',
          'Keep it up!',
          Icons.offline_bolt,
          const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color accentColor,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                Icon(icon, color: accentColor, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartCard(BuildContext context, int pushups, int jumps) {
    final hasReps = (pushups + jumps) > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 180,
          child: hasReps
              ? Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 40,
                          sections: [
                            if (pushups > 0)
                              PieChartSectionData(
                                color: const Color(0xFFE53935),
                                value: pushups.toDouble(),
                                title: 'Pushups',
                                radius: 50,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            if (jumps > 0)
                              PieChartSectionData(
                                color: const Color(0xFFFB8C00),
                                value: jumps.toDouble(),
                                title: 'Jumps',
                                radius: 50,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(const Color(0xFFE53935), 'Pushups ($pushups reps)'),
                        const SizedBox(height: 8),
                        _buildLegendItem(const Color(0xFFFB8C00), 'Jumps ($jumps reps)'),
                      ],
                    ),
                  ],
                )
              : const Center(
                  child: Text(
                    'No reps completed today.\nStart an exercise session from your blocked apps list!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildNoDataWidget(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: const Column(
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No history recorded yet.', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Your exercise sessions will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, List<Exercise> exercises) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exercises.length > 15 ? 15 : exercises.length, // Limit to recent 15
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final timeStr = DateFormat('jm').format(exercise.completedAt);
        final dateStr = DateFormat('MMMd').format(exercise.completedAt);
        final typeText = exercise.type.name.toUpperCase();
        final icon = exercise.type == ExerciseType.pushups ? Icons.fitness_center : Icons.directions_run;
        final iconColor = exercise.type == ExerciseType.pushups ? const Color(0xFFE53935) : const Color(0xFFFB8C00);

        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.15),
              child: Icon(icon, color: iconColor),
            ),
            title: Text('$typeText - ${exercise.repsCompleted}/${exercise.repsRequired} Reps'),
            subtitle: Text('Unlocked for ${exercise.unlockDurationMinutes} min'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
        );
      },
    );
  }
}
