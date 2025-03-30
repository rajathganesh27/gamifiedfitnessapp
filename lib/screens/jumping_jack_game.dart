import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gamifiedfitnessapp/pose_painter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JumpingJackGame extends StatefulWidget {
  final Stream<Map<PoseLandmarkType, PoseLandmark>> landmarksStream;
  final Function(int) onGameComplete;
  final CameraController? cameraController;
  final List<Pose>? poseResults;
  final Function(CameraLensDirection) onCameraToggle;

  const JumpingJackGame({
    Key? key,
    required this.landmarksStream,
    required this.onGameComplete,
    this.cameraController,
    this.poseResults,
    required this.onCameraToggle,
  }) : super(key: key);

  @override
  _JumpingJackGameState createState() => _JumpingJackGameState();
}

class _JumpingJackGameState extends State<JumpingJackGame> {
  int _score = 0;
  int _jumpingJackCount = 0;
  late StreamSubscription _landmarksSubscription;
  bool _gameActive = false;
  bool _gameOver = false;
  int _countdownValue = 3;
  bool _isCountingDown = false;

  // Goal-based system instead of timed
  int _targetJacks = 20;
  int _currentLevel = 1;
  int _streak = 0;
  double _multiplier = 1.0;

  // Camera direction tracking
  CameraLensDirection _currentLensDirection = CameraLensDirection.front;

  // Jump state tracking
  bool _isInJumpPosition = false;
  bool _wasInRestPosition = true;

  // Progress tracker for visual feedback
  double _jackProgress = 0.0;

  // Time of last valid jumping jack
  DateTime? _lastJackTime;

  // Visual effects
  List<_PointEffect> _pointEffects = [];
  Timer? _effectsTimer;

  @override
  void initState() {
    super.initState();

    // Get initial camera direction if available
    if (widget.cameraController != null) {
      _currentLensDirection =
          widget.cameraController!.description.lensDirection;
    }

    // Listen to pose landmarks to detect jumping jack motion
    _landmarksSubscription = widget.landmarksStream.listen((landmarks) {
      if (!_gameActive) return;

      // Get wrist and ankle positions
      final leftWrist = landmarks[PoseLandmarkType.leftWrist];
      final rightWrist = landmarks[PoseLandmarkType.rightWrist];
      final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
      final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
      final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

      if (leftWrist != null &&
          rightWrist != null &&
          leftAnkle != null &&
          rightAnkle != null &&
          leftShoulder != null &&
          rightShoulder != null) {
        // Calculate horizontal distances
        double wristDistance = (rightWrist.x - leftWrist.x).abs();
        double ankleDistance = (rightAnkle.x - leftAnkle.x).abs();
        double shoulderDistance = (rightShoulder.x - leftShoulder.x).abs();

        // Normalize by shoulder width to account for different distances from camera
        double normalizedWristDistance = wristDistance / shoulderDistance;
        double normalizedAnkleDistance = ankleDistance / shoulderDistance;

        // Check if in jump position (arms and legs spread wide)
        bool currentlyInJumpPosition =
            normalizedWristDistance > 1.5 && normalizedAnkleDistance > 0.5;

        // Check if in rest position (arms down, legs together)
        bool currentlyInRestPosition =
            normalizedWristDistance < 0.8 && normalizedAnkleDistance < 0.3;

        // Update jack progress for visual feedback
        setState(() {
          if (currentlyInJumpPosition) {
            _jackProgress = 1.0;
          } else if (currentlyInRestPosition) {
            _jackProgress = 0.0;
          } else {
            // Intermediate positions
            _jackProgress =
                (normalizedWristDistance - 0.8) /
                0.7; // Scale between 0.8 and 1.5
            _jackProgress = _jackProgress.clamp(0.0, 1.0);
          }
        });

        // Detect a complete jumping jack
        if (currentlyInJumpPosition &&
            !_isInJumpPosition &&
            _wasInRestPosition) {
          // Only count if at least 0.5 seconds have passed since last jumping jack
          // This prevents counting too rapidly
          bool shouldCount = true;
          if (_lastJackTime != null) {
            Duration timeSinceLast = DateTime.now().difference(_lastJackTime!);
            shouldCount = timeSinceLast.inMilliseconds > 400;
          }

          if (shouldCount) {
            _countJumpingJack();
            _lastJackTime = DateTime.now();
          }
        }

        // Update state tracking
        _isInJumpPosition = currentlyInJumpPosition;
        if (currentlyInRestPosition) {
          _wasInRestPosition = true;
        }
      }
    });
  }

  void _toggleCamera() {
    CameraLensDirection newDirection =
        _currentLensDirection == CameraLensDirection.back
            ? CameraLensDirection.front
            : CameraLensDirection.back;

    setState(() {
      _currentLensDirection = newDirection;
    });

    widget.onCameraToggle(newDirection);
  }

  void _countJumpingJack() {
    // Update streak and multiplier
    setState(() {
      _streak++;

      // Cap multiplier at 3x
      if (_streak >= 10) {
        _multiplier = 3.0;
      } else if (_streak >= 5) {
        _multiplier = 2.0;
      } else {
        _multiplier = 1.0;
      }

      // Calculate points
      int points = (10 * _multiplier).round();
      _score += points;
      _jumpingJackCount++;

      // Add point effect
      _pointEffects.add(
        _PointEffect(
          text: '+$points',
          x: MediaQuery.of(context).size.width / 2,
          y: MediaQuery.of(context).size.height / 2,
          color: _multiplier >= 2.0 ? Colors.orange : Colors.white,
        ),
      );

      _wasInRestPosition = false;

      // Check if level is complete
      if (_jumpingJackCount >= _targetJacks) {
        _levelUp();
      }
    });

    // Start point effects timer if not running
    _effectsTimer ??= Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (!mounted || !_gameActive) {
        timer.cancel();
        _effectsTimer = null;
        return;
      }

      setState(() {
        // Update positions and remove old effects
        for (var effect in _pointEffects) {
          effect.y -= 2;
          effect.opacity -= 0.02;
        }
        _pointEffects.removeWhere((effect) => effect.opacity <= 0);
      });
    });
  }

  void _levelUp() {
    setState(() {
      _currentLevel++;
      _targetJacks = (_targetJacks * 1.5).round();

      // Add level up effect
      _pointEffects.add(
        _PointEffect(
          text: 'LEVEL UP!',
          x: MediaQuery.of(context).size.width / 2,
          y: MediaQuery.of(context).size.height / 2,
          color: Colors.yellow,
          scale: 1.5,
          opacity: 1.0,
        ),
      );
    });
  }

  void startGame() {
    // Start countdown
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
      _score = 0;
      _jumpingJackCount = 0;
      _gameOver = false;
      _streak = 0;
      _multiplier = 1.0;
      _currentLevel = 1;
      _targetJacks = 20;
      _pointEffects = [];
    });

    // Countdown timer
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownValue--;
      });

      if (_countdownValue <= 0) {
        timer.cancel();
        _startGameAfterCountdown();
      }
    });
  }

  void _startGameAfterCountdown() {
    setState(() {
      _isCountingDown = false;
      _gameActive = true;
      _lastJackTime = null;
    });
  }

  void _endGame() async {
    setState(() {
      _gameActive = false;
      _gameOver = true;
    });

    _effectsTimer?.cancel();
    _effectsTimer = null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;

        // 🔄 Fetch display name from 'users' collection
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final displayName = userDoc.data()?['name'] ?? 'Anonymous';

        final leaderboardCollection = FirebaseFirestore.instance.collection(
          'leaderboard',
        );

        // ✅ Write to jumping_jack leaderboard
        await leaderboardCollection.doc('jumping_jack_$uid').set({
          'uid': uid,
          'name': displayName,
          'exercise': 'jumping_jack',
          'score': FieldValue.increment(_score),
          'timestamp': Timestamp.now(),
        }, SetOptions(merge: true));

        // ✅ Also update combined leaderboard
        await leaderboardCollection.doc('combined_$uid').set({
          'uid': uid,
          'name': displayName,
          'exercise': 'combined',
          'score': FieldValue.increment(_score),
          'timestamp': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error saving score to leaderboard: $e");
    }

    widget.onGameComplete(_score);
  }

  @override
  void dispose() {
    _landmarksSubscription.cancel();
    _effectsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera background
        if (widget.cameraController != null &&
            widget.cameraController!.value.isInitialized)
          Positioned.fill(child: CameraPreview(widget.cameraController!)),

        // Semi-transparent overlay
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.2))),

        // Pose visualization
        if (widget.poseResults != null &&
            widget.poseResults!.isNotEmpty &&
            widget.cameraController != null)
          Positioned.fill(
            child: CustomPaint(
              painter: PosePainter(
                Size(
                  widget.cameraController!.value.previewSize!.height,
                  widget.cameraController!.value.previewSize!.width,
                ),
                widget.poseResults!,
              ),
            ),
          ),

        // Jumping jack visual guide
        if (_gameActive)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _multiplier >= 2.0
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.purple.withOpacity(0.2),
                  border: Border.all(
                    color: _multiplier >= 2.0 ? Colors.orange : Colors.purple,
                    width: 3,
                  ),
                ),
                child: Icon(
                  _jackProgress > 0.5
                      ? Icons.accessibility
                      : Icons.accessibility_new,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        // Jump progress indicator
        if (_gameActive)
          Positioned(
            top: 230,
            left: 40,
            right: 40,
            child: LinearProgressIndicator(
              value: _jackProgress,
              backgroundColor: Colors.grey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                _multiplier >= 2.0 ? Colors.orange : Colors.purple,
              ),
              minHeight: 10,
            ),
          ),

        // Level progress display
        if (_gameActive)
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 200,
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      'Level $_currentLevel',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _jumpingJackCount / _targetJacks,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.purple,
                        ),
                        minHeight: 10,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '$_jumpingJackCount / $_targetJacks',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Score and streak display
        Positioned(
          top: 40,
          right: 20,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Score: $_score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_streak >= 3)
                  Row(
                    children: [
                      Icon(Icons.whatshot, color: Colors.orange, size: 16),
                      Text(
                        'Streak: $_streak (${_multiplier.toStringAsFixed(1)}x)',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        // Countdown display
        if (_isCountingDown)
          Center(
            child: Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$_countdownValue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Point effects
        ..._pointEffects.map((effect) {
          return Positioned(
            left: effect.x - 50,
            top: effect.y - 25,
            child: Opacity(
              opacity: effect.opacity,
              child: Transform.scale(
                scale: effect.scale,
                child: Text(
                  effect.text,
                  style: TextStyle(
                    color: effect.color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),

        // Game over display
        if (_gameOver)
          Center(
            child: Container(
              padding: EdgeInsets.all(30),
              width: 300,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Game Over!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Final Score: $_score',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Level Reached: $_currentLevel',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Jumping Jacks: $_jumpingJackCount',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    child: Text('Play Again', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),

        // Instructions
        if (!_gameActive && !_isCountingDown && !_gameOver)
          Positioned(
            bottom: 120,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                'Complete jumping jacks to level up! Build a streak to multiply your points. Try to reach the highest level you can!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),

        // Play button
        if (!_gameActive && !_isCountingDown)
          Positioned(
            bottom: 50,
            left: 40,
            right: 40,
            child: ElevatedButton(
              onPressed: startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                _gameOver ? 'Play Again' : 'Start',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

        // Back button
        Positioned(
          top: 40,
          left: 20,
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
            onPressed: () {
              widget.onGameComplete(_score);
            },
          ),
        ),

        // Camera toggle button
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _currentLensDirection == CameraLensDirection.back
                    ? Icons.camera_front
                    : Icons.camera_rear,
                color: Colors.white,
                size: 30,
              ),
              onPressed: _toggleCamera,
            ),
          ),
        ),

        // Quit game button (only during active game)
        if (_gameActive)
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.stop, color: Colors.white, size: 30),
                onPressed: _endGame,
              ),
            ),
          ),
      ],
    );
  }
}

// Helper class for point animations
class _PointEffect {
  final String text;
  double x;
  double y;
  final Color color;
  double opacity;
  final double scale;

  _PointEffect({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
    this.opacity = 1.0,
    this.scale = 1.0,
  });
}
