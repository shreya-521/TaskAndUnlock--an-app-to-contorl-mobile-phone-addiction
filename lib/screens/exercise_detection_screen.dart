import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/exercise_detection_service.dart';
import '../services/notification_service.dart';
import '../models/exercise_model.dart';
import '../providers/exercise_provider.dart';
import '../providers/timer_provider.dart';

class ExerciseDetectionScreen extends StatefulWidget {
  final ExerciseType exerciseType;
  final int targetReps;
  final int appId;
  final String appName;

  const ExerciseDetectionScreen({
    Key? key,
    required this.exerciseType,
    required this.targetReps,
    required this.appId,
    required this.appName,
  }) : super(key: key);

  @override
  State<ExerciseDetectionScreen> createState() =>
      _ExerciseDetectionScreenState();
}

class _ExerciseDetectionScreenState extends State<ExerciseDetectionScreen> {
  static const _platform = MethodChannel('com.taskandunlock.app/blocker');

  late CameraController _cameraController;
  late ExerciseDetectionService _detectionService;
  late NotificationService _notificationService;

  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  int _currentReps = 0;
  bool _isSessionActive = true;

  @override
  void initState() {
    super.initState();
    _detectionService = ExerciseDetectionService();
    _notificationService = NotificationService();
    _initializeCamera();
    _initializeServices();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low, // 480p for efficiency
        enableAudio: false,
      );

      await _cameraController.initialize();
      if (!mounted) return;

      setState(() => _isCameraInitialized = true);
      _startPoseDetection();
    } catch (e) {
      print('Error initializing camera: $e');
      _showError('Camera initialization failed');
    }
  }

  Future<void> _initializeServices() async {
    await _detectionService.initialize();
    await _notificationService.initialize();
    await _notificationService.showExerciseStartedNotification(
      widget.exerciseType.toString().split('.').last,
    );
  }

  void _startPoseDetection() {
    _cameraController.startImageStream((image) {
      if (!_isDetecting && _isSessionActive) {
        _isDetecting = true;
        _detectPose(image);
      }
    });
  }

  Future<void> _detectPose(CameraImage image) async {
    try {
      final pose = await _detectionService.detectPoseFromImage(image);

      if (pose != null && mounted) {
        final updatedReps = await _detectionService.detectExercise(
          pose,
          widget.exerciseType,
        );

        setState(() => _currentReps = updatedReps);

        // Check if target reached
        if (_currentReps >= widget.targetReps && _isSessionActive) {
          await _completeExercise();
        }
      }
    } catch (e) {
      print('Error detecting pose: $e');
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _completeExercise() async {
    _isSessionActive = false;

    try {
      // Record exercise
      final exercise = Exercise(
        type: widget.exerciseType,
        repsRequired: widget.targetReps,
        repsCompleted: _currentReps,
        completedAt: DateTime.now(),
        unlockedUntil: DateTime.now().add(const Duration(minutes: 5)),
        unlockDurationMinutes: 5,
      );

      if (mounted) {
        await context.read<ExerciseProvider>().addExercise(exercise);
        await context.read<TimerProvider>().unlockApp(widget.appId, 5);
      }

      // Show success
      await _notificationService.showExerciseCompletedNotification(
        widget.appName,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('✅ Exercise Completed!'),
          content: Text(
            '${widget.exerciseType.toString().split('.').last}: $_currentReps/${widget.targetReps} reps\n\n${widget.appName} is unlocked for 5 minutes!',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error completing exercise: $e');
      _showError('Error saving exercise');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _detectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        try {
          await _platform.invokeMethod('goToHomeScreen');
        } catch (e) {
          print('Error redirecting to home: $e');
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.exerciseType.toString().split('.').last.toUpperCase()} Detection'),
        ),
        body: Stack(
          children: [
            // Camera preview
            if (_isCameraInitialized)
              CameraPreview(_cameraController)
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF8B0000),
                ),
              ),

          // Overlay with rep counter
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Reps Detected',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_currentReps / ${widget.targetReps}',
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: _currentReps >= widget.targetReps
                                      ? Colors.green
                                      : const Color(0xFF8B0000),
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom instructions
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    widget.exerciseType == ExerciseType.pushups
                        ? 'Do pushups slowly and clearly'
                        : 'Jump clearly within the frame',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                        ),
                        onPressed: () async {
                          try {
                            await _platform.invokeMethod('goToHomeScreen');
                          } catch (e) {
                            print('Error redirecting to home screen: $e');
                          }
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      if (!_isSessionActive)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check),
                          label: const Text('Done'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
