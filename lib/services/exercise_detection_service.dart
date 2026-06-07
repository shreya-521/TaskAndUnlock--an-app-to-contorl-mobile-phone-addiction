import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/exercise_model.dart';

class ExerciseDetectionService {
  PoseDetector? _poseDetector;
  int _currentReps = 0;
  bool _wasDown = false;
  bool _wasUp = false;

  Future<void> initialize() async {
    _poseDetector ??= PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );
  }

  Future<Pose?> detectPoseFromImage(CameraImage image) async {
    if (_poseDetector == null) return null;

    final inputImage = _convertCameraImage(image);
    if (inputImage == null) return null;

    final poses = await _poseDetector!.processImage(inputImage);
    return poses.isNotEmpty ? poses.first : null;
  }

  Future<int> detectExercise(Pose pose, ExerciseType type) async {
    switch (type) {
      case ExerciseType.pushups:
        return _detectPushup(pose);
      case ExerciseType.jumps:
        return _detectJump(pose);
    }
  }

  int _detectPushup(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null) {
      return _currentReps;
    }

    final shoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    final elbowY = (leftElbow.y + rightElbow.y) / 2;
    final isDown = elbowY > shoulderY + 40;

    if (isDown) {
      _wasDown = true;
    } else if (_wasDown && !_wasUp) {
      _wasUp = true;
    } else if (_wasDown && _wasUp && !isDown) {
      _currentReps++;
      _wasDown = false;
      _wasUp = false;
    }

    return _currentReps;
  }

  int _detectJump(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftHip == null ||
        rightHip == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return _currentReps;
    }

    final hipY = (leftHip.y + rightHip.y) / 2;
    final ankleY = (leftAnkle.y + rightAnkle.y) / 2;
    final isAirborne = ankleY < hipY - 80;

    if (isAirborne) {
      _wasUp = true;
    } else if (_wasUp) {
      _currentReps++;
      _wasUp = false;
    }

    return _currentReps;
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final rotation = InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void dispose() {
    _poseDetector?.close();
    _poseDetector = null;
  }
}
