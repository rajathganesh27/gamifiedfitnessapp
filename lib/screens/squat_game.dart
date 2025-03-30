import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gamifiedfitnessapp/pose_painter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SquatGame extends StatefulWidget {
  final Stream<bool> isSquattingStream;
  final Function(int) onGameComplete;
  final CameraController? cameraController;
  final List<Pose>? poseResults; // Add pose results to display body points
  final Function(CameraLensDirection) onCameraToggle;

  const SquatGame({
    Key? key,
    required this.isSquattingStream,
    required this.onGameComplete,
    this.cameraController,
    this.poseResults,
    required this.onCameraToggle,
  }) : super(key: key);

  @override
  _SquatGameState createState() => _SquatGameState();
}

class _SquatGameState extends State<SquatGame>
    with SingleTickerProviderStateMixin {
  late AnimationController _ballController;
  double _ballPosition = 0.5; // 0 is top, 1 is bottom
  double _targetPosition = 0.5;
  int _score = 0;
  late StreamSubscription _squatSubscription;
  bool _gameActive = false;
  final List<Obstacle> _obstacles = [];
  Timer? _gameTimer;
  Timer? _obstacleTimer;
  final Random _random = Random();
  bool _gameOver = false;
  int _countdownValue = 3; // Countdown timer starting value
  bool _isCountingDown = false;

  // Ball properties
  final double _ballSize = 50;

  // Reduced obstacle speed significantly
  final double _obstacleSpeed = 1.5; // Very slow speed for obstacles

  @override
  void initState() {
    super.initState();

    // Create animation controller for smooth ball movement
    _ballController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    )..addListener(() {
      setState(() {
        // Update ball position based on animation
        _ballPosition = _ballController.value;
      });
    });

    // Listen to squatting state changes
    _squatSubscription = widget.isSquattingStream.listen((isSquatting) {
      if (!_gameActive) return;

      // Set target position based on squatting state
      if (isSquatting) {
        // Move ball up when squatting
        _targetPosition = 0.2;
      } else {
        // Move ball down when standing
        _targetPosition = 0.8;
      }

      // Start animation to target position
      _ballController.animateTo(
        _targetPosition,
        curve: Curves.easeOut,
        duration: Duration(milliseconds: 300),
      );
    });
  }

  void _toggleCamera() {
    CameraLensDirection newDirection =
        widget.cameraController?.description.lensDirection ==
                CameraLensDirection.back
            ? CameraLensDirection.front
            : CameraLensDirection.back;

    widget.onCameraToggle(newDirection);
  }

  void startGame() {
    // Start the countdown first
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
      _score = 0;
      _obstacles.clear();
      _gameOver = false;
    });

    // Start countdown timer
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
    });

    // Create obstacles periodically (less frequently)
    _obstacleTimer = Timer.periodic(Duration(milliseconds: 3000), (timer) {
      if (!mounted || !_gameActive) {
        timer.cancel();
        return;
      }

      _addObstacle();
    });

    // Game update timer
    _gameTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      if (!mounted || !_gameActive) {
        timer.cancel();
        return;
      }

      _updateGame();
    });
  }

  void _addObstacle() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine if obstacle should be in upper or lower half
    final bool isUpperHalf = _random.nextBool();

    // Make obstacles slightly smaller
    final obstacleHeight = screenHeight * (_random.nextDouble() * 0.15 + 0.15);

    double obstacleY;

    if (isUpperHalf) {
      // Place in upper half (top quarter of screen)
      obstacleY = _random.nextDouble() * (screenHeight * 0.25);
    } else {
      // Place in lower half (bottom quarter of screen)
      obstacleY =
          screenHeight * 0.75 +
          (_random.nextDouble() * (screenHeight * 0.25 - obstacleHeight));
    }

    // Width of obstacles
    final obstacleWidth = 30.0;

    setState(() {
      _obstacles.add(
        Obstacle(
          x: screenWidth,
          y: obstacleY,
          width: obstacleWidth,
          height: obstacleHeight,
        ),
      );
    });
  }

  void _updateGame() {
    if (_gameOver) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final ballX = screenWidth / 2 - _ballSize / 2;
    final ballY = screenHeight * _ballPosition - _ballSize / 2;

    setState(() {
      // Move obstacles very slowly
      for (var i = _obstacles.length - 1; i >= 0; i--) {
        _obstacles[i].x -= _obstacleSpeed; // Reduced speed of obstacles

        // Remove obstacles that are off screen
        if (_obstacles[i].x < -_obstacles[i].width) {
          _obstacles.removeAt(i);
          // Add point for passing obstacle
          _score++;
          continue;
        }

        // Check collision
        if (_obstacles[i].x < ballX + _ballSize &&
            _obstacles[i].x + _obstacles[i].width > ballX &&
            _obstacles[i].y < ballY + _ballSize &&
            _obstacles[i].y + _obstacles[i].height > ballY) {
          _gameOver = true;
          Future.delayed(Duration(seconds: 2), () {
            endGame();
          });
          break;
        }
      }
    });
  }

  void endGame() async {
    _gameActive = false;
    _obstacleTimer?.cancel();
    _gameTimer?.cancel();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;

        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        final displayName = userDoc.data()?['name'] ?? 'Anonymous';

        final leaderboardCollection = FirebaseFirestore.instance.collection(
          'leaderboard',
        );

        // ✅ Update bicep_curl leaderboard
        await leaderboardCollection.doc('bicep_curl_$uid').set({
          'uid': uid,
          'name': displayName,
          'exercise': 'bicep_curl',
          'score': FieldValue.increment(_score),
          'timestamp': Timestamp.now(),
        }, SetOptions(merge: true));

        // ✅ Update combined leaderboard
        await leaderboardCollection.doc('combined_$uid').set({
          'uid': uid,
          'name': displayName,
          'exercise': 'combined',
          'score': FieldValue.increment(_score),
          'timestamp': Timestamp.now(),
        }, SetOptions(merge: true));

        // ✅ Fetch updated combined score
        final combinedDoc =
            await leaderboardCollection.doc('combined_$uid').get();
        final combinedScore = (combinedDoc.data()?['score'] ?? 0) as int;

        // ✅ Map score to level label
        final newLevelLabel = _getLevelLabel(combinedScore);

        // ✅ Save level label to users collection
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'level': newLevelLabel,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error saving score to leaderboard: $e");
    }

    widget.onGameComplete(_score);
  }

  String _getLevelLabel(int score) {
    if (score < 200) return 'Beginner';
    if (score < 400) return 'Intermediate';
    if (score < 600) return 'Advanced';
    if (score < 1000) return 'Pro';
    return 'Elite';
  }

  @override
  void dispose() {
    _ballController.dispose();
    _squatSubscription.cancel();
    _obstacleTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera background (shows user's body)
        if (widget.cameraController != null &&
            widget.cameraController!.value.isInitialized)
          Positioned.fill(child: CameraPreview(widget.cameraController!)),

        // Dark overlay to see game elements better
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),

        // Pose skeleton visualization
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

        // Obstacles
        ..._obstacles.map(
          (obstacle) => Positioned(
            left: obstacle.x,
            top: obstacle.y,
            width: obstacle.width,
            height: obstacle.height,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.7),
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        // Ball
        Positioned(
          left: MediaQuery.of(context).size.width / 2 - _ballSize / 2,
          top:
              MediaQuery.of(context).size.height * _ballPosition -
              _ballSize / 2,
          child: Container(
            width: _ballSize,
            height: _ballSize,
            decoration: BoxDecoration(
              color: Colors.yellow,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.orange, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),

        // Score
        Positioned(
          top: 40,
          right: 20,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Score: $_score',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Countdown timer display
        if (_isCountingDown)
          Center(
            child: Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
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

        // Game over message
        if (_gameOver)
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Game Over!\nScore: $_score',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Instructions
        if (!_gameActive && !_isCountingDown)
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
                'Squat to move the ball up and down to avoid the green obstacles.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),

        // Play button
        if (!_gameActive && !_gameOver && !_isCountingDown)
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
                'Play',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

        // Back button when game is active or during countdown
        Positioned(
          top: 40,
          left: 20,
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
            onPressed: endGame,
          ),
        ),

        // Camera toggle button
        Positioned(
          top: 40,
          left: 70,
          child: IconButton(
            icon: Icon(
              widget.cameraController?.description.lensDirection ==
                      CameraLensDirection.back
                  ? Icons.camera_front
                  : Icons.camera_rear,
              color: Colors.white,
              size: 30,
            ),
            onPressed: _toggleCamera,
          ),
        ),
      ],
    );
  }
}

// Class to represent obstacles
class Obstacle {
  double x;
  double y;
  final double width;
  final double height;

  Obstacle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}
