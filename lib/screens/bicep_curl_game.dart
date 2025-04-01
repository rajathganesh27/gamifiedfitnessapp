import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gamifiedfitnessapp/pose_painter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BicepCurlGame extends StatefulWidget {
  final Stream<bool> isCurlingStream;
  final Function(int) onGameComplete;
  final CameraController? cameraController;
  final List<Pose>? poseResults;
  final Function(CameraLensDirection) onCameraToggle;

  const BicepCurlGame({
    Key? key,
    required this.isCurlingStream,
    required this.onGameComplete,
    this.cameraController,
    this.poseResults,
    required this.onCameraToggle,
  }) : super(key: key);

  @override
  _BicepCurlGameState createState() => _BicepCurlGameState();
}

class _BicepCurlGameState extends State<BicepCurlGame>
    with SingleTickerProviderStateMixin {
  late AnimationController _weightController;
  double _weightPosition = 0.5; // 0 is top, 1 is bottom
  double _targetPosition = 0.5;
  int _score = 0;
  late StreamSubscription _curlSubscription;
  bool _gameActive = false;
  final List<Obstacle> _obstacles = [];
  Timer? _gameTimer;
  Timer? _obstacleTimer;
  final Random _random = Random();
  bool _gameOver = false;
  int _countdownValue = 3; // Countdown timer starting value
  bool _isCountingDown = false;

  // Weight properties
  final double _weightSize = 50;

  // Obstacle speed
  final double _obstacleSpeed = 1.5; // Very slow speed for obstacles

  @override
  void initState() {
    super.initState();

    // Create animation controller for smooth weight movement
    _weightController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    )..addListener(() {
      setState(() {
        // Update weight position based on animation
        _weightPosition = _weightController.value;
      });
    });

    // Listen to curling state changes
    _curlSubscription = widget.isCurlingStream.listen((isCurling) {
      if (!_gameActive) return;

      // Set target position based on curling state
      if (isCurling) {
        // Move weight up when curling
        _targetPosition = 0.2;
      } else {
        // Move weight down when not curling
        _targetPosition = 0.8;
      }

      // Start animation to target position
      _weightController.animateTo(
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
    final weightX = screenWidth / 2 - _weightSize / 2;
    final weightY = screenHeight * _weightPosition - _weightSize / 2;

    setState(() {
      // Move obstacles
      for (var i = _obstacles.length - 1; i >= 0; i--) {
        _obstacles[i].x -= _obstacleSpeed;

        // Remove obstacles that are off screen
        if (_obstacles[i].x < -_obstacles[i].width) {
          _obstacles.removeAt(i);
          // Add point for passing obstacle
          _score++;
          continue;
        }

        // Check collision
        if (_obstacles[i].x < weightX + _weightSize &&
            _obstacles[i].x + _obstacles[i].width > weightX &&
            _obstacles[i].y < weightY + _weightSize &&
            _obstacles[i].y + _obstacles[i].height > weightY) {
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

        final bicepCurlCollection = FirebaseFirestore.instance.collection(
          'bicep_curls',
        );
        final combinedCollection = FirebaseFirestore.instance.collection(
          'combined_scores',
        );

        // ✅ Save bicep curl score
        await bicepCurlCollection.doc(uid).set({
          'uid': uid,
          'name': displayName,
          'score': FieldValue.increment(_score),
          'timestamp': Timestamp.now(),
        }, SetOptions(merge: true));

        // ✅ Update combined score
        await combinedCollection.doc(uid).set({
          'uid': uid,
          'name': displayName,
          'score': FieldValue.increment(_score),
          'timestamp': Timestamp.now(),
        }, SetOptions(merge: true));

        // ✅ Fetch combined score
        final combinedDoc = await combinedCollection.doc(uid).get();
        final combinedScore = (combinedDoc.data()?['score'] ?? 0) as int;

        // ✅ Determine new level
        final newLevelLabel = _getLevelLabel(combinedScore);

        // ✅ Update level in 'users'
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'level': newLevelLabel,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error saving bicep curl score: $e");
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
    _weightController.dispose();
    _curlSubscription.cancel();
    _obstacleTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera background (shows user's body)
          if (widget.cameraController != null &&
              widget.cameraController!.value.isInitialized)
            Positioned(
              top: 0.0,
              left: 0.0,
              width: size.width,
              height: size.height,
              child: AspectRatio(
                aspectRatio: widget.cameraController!.value.aspectRatio,
                child: CameraPreview(widget.cameraController!),
              ),
            ),

          // Dark overlay to see game elements better
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

          // Pose skeleton visualization
          if (widget.poseResults != null &&
              widget.poseResults!.isNotEmpty &&
              widget.cameraController != null)
            Positioned(
              top: 0.0,
              left: 0.0,
              width: size.width,
              height: size.height,
              child: CustomPaint(
                painter: PosePainter(
                  Size(
                    widget.cameraController!.value.previewSize!.height,
                    widget.cameraController!.value.previewSize!.width,
                  ),
                  widget.poseResults!,
                  isFrontCamera:
                      widget.cameraController!.description.lensDirection ==
                      CameraLensDirection.front,
                ),
              ),
            ),

          // Top header with game title - Matching detection screen style
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: 60, bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    "Bicep Curl Game",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_gameActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Score: $_score",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                ],
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

          // Weight (using same styling as ball in squat game)
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - _weightSize / 2,
            top:
                MediaQuery.of(context).size.height * _weightPosition -
                _weightSize / 2,
            child: Container(
              width: _weightSize,
              height: _weightSize,
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
              // Add dumbbell icon inside the ball
              child: Icon(
                Icons.fitness_center,
                color: Colors.orange[800],
                size: 26,
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

          // Instructions (only visible before game starts)
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
                  'Do bicep curls to move the weight up and down to avoid the green obstacles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),

          // Bottom controls (similar to detection screen)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Camera toggle button
                  FloatingActionButton(
                    backgroundColor: Colors.white.withOpacity(0.3),
                    child: Icon(
                      widget.cameraController?.description.lensDirection ==
                              CameraLensDirection.back
                          ? Icons.camera_front
                          : Icons.camera_rear,
                      color: Colors.white,
                    ),
                    onPressed: _toggleCamera,
                  ),

                  // Play button or Back button
                  if (!_gameActive && !_isCountingDown)
                    ElevatedButton(
                      onPressed: startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        "Start Game",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: endGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        "Exit Game",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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
