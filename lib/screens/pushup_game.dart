import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gamifiedfitnessapp/pose_painter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushUpGame extends StatefulWidget {
  final Stream<bool> isLoweredStream;
  final Function(int) onGameComplete;
  final CameraController? cameraController;
  final List<Pose>? poseResults;
  final Function(CameraLensDirection) onCameraToggle;

  const PushUpGame({
    Key? key,
    required this.isLoweredStream,
    required this.onGameComplete,
    this.cameraController,
    this.poseResults,
    required this.onCameraToggle,
  }) : super(key: key);

  @override
  _PushUpGameState createState() => _PushUpGameState();
}

class _PushUpGameState extends State<PushUpGame>
    with SingleTickerProviderStateMixin {
  late AnimationController _platformController;
  double _platformPosition = 0.5; // 0 is top, 1 is bottom
  double _targetPosition = 0.5;
  int _score = 0;
  late StreamSubscription _pushupSubscription;
  bool _gameActive = false;
  final List<Coin> _coins = [];
  final List<Obstacle> _obstacles = [];
  Timer? _gameTimer;
  Timer? _coinTimer;
  Timer? _obstacleTimer;
  final Random _random = Random();
  bool _gameOver = false;
  int _countdownValue = 3; // Countdown timer starting value
  bool _isCountingDown = false;

  // Camera direction tracking
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;

  // Platform properties
  final double _platformWidth = 80;
  final double _platformHeight = 20;

  // Game speed (pixels per frame)
  final double _gameSpeed = 2.0;

  // Theme color
  final Color _themeColor = Colors.red;

  @override
  void initState() {
    super.initState();

    // Get initial camera direction if available
    if (widget.cameraController != null) {
      _currentLensDirection =
          widget.cameraController!.description.lensDirection;
    }

    // Create animation controller for smooth platform movement
    _platformController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    )..addListener(() {
      setState(() {
        // Update platform position based on animation
        _platformPosition = _platformController.value;
      });
    });

    // Listen to pushup state changes - improved responsiveness
    _pushupSubscription = widget.isLoweredStream.listen((isLowered) {
      if (!_gameActive) return;

      // Set target position based on pushup state
      if (isLowered) {
        // Move platform down when in lowered position
        _targetPosition = 0.8;
      } else {
        // Move platform up when in raised position
        _targetPosition = 0.2;
      }

      // Start animation to target position with faster response
      _platformController.animateTo(
        _targetPosition,
        curve: Curves.easeOut,
        duration: Duration(milliseconds: 200),
      );
    });
  }

  void _toggleCamera() {
    // Toggle between front and back cameras
    CameraLensDirection newDirection =
        _currentLensDirection == CameraLensDirection.back
            ? CameraLensDirection.front
            : CameraLensDirection.back;

    setState(() {
      _currentLensDirection = newDirection;
    });

    // Call the parent's camera toggle function
    widget.onCameraToggle(newDirection);
  }

  void startGame() {
    // Start the countdown first
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
      _score = 0;
      _coins.clear();
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

    // Create coins periodically
    _coinTimer = Timer.periodic(Duration(milliseconds: 2000), (timer) {
      if (!mounted || !_gameActive) {
        timer.cancel();
        return;
      }

      _addCoin();
    });

    // Create obstacles periodically
    _obstacleTimer = Timer.periodic(Duration(milliseconds: 4000), (timer) {
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

  void _addCoin() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Randomize coin vertical position
    final coinY =
        _random.nextDouble() * (screenHeight * 0.6) + (screenHeight * 0.2);

    // Size of coins
    final coinSize = 30.0;

    setState(() {
      _coins.add(Coin(x: screenWidth, y: coinY, size: coinSize));
    });
  }

  void _addObstacle() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Create obstacle in a challenging location
    final obstacleHeight = screenHeight * (_random.nextDouble() * 0.15 + 0.1);

    double obstacleY;

    // Decide if obstacle should be in upper or lower part
    bool isUpper = _random.nextBool();
    if (isUpper) {
      // Upper obstacle
      obstacleY = screenHeight * 0.1;
    } else {
      // Lower obstacle
      obstacleY = screenHeight * 0.7;
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
    final platformX = screenWidth / 4;
    final platformY = screenHeight * _platformPosition;

    setState(() {
      // Move coins
      for (var i = _coins.length - 1; i >= 0; i--) {
        _coins[i].x -= _gameSpeed;

        // Remove coins that are off screen
        if (_coins[i].x < -_coins[i].size) {
          _coins.removeAt(i);
          continue;
        }

        // Improved collision detection with platform - use center points
        final coinCenterX = _coins[i].x + _coins[i].size / 2;
        final coinCenterY = _coins[i].y + _coins[i].size / 2;
        final platformCenterX = platformX + _platformWidth / 2;
        final platformCenterY = platformY + _platformHeight / 2;

        // Calculate distance between centers
        final distance = sqrt(
          pow(coinCenterX - platformCenterX, 2) +
              pow(coinCenterY - platformCenterY, 2),
        );

        // If distance is less than sum of half widths, collision occurred
        if (distance < (_coins[i].size / 2 + _platformWidth / 2)) {
          // Coin collected
          _score += 1;
          _coins.removeAt(i);
        }
      }

      // Move obstacles with improved collision detection
      for (var i = _obstacles.length - 1; i >= 0; i--) {
        _obstacles[i].x -= _gameSpeed;

        // Remove obstacles that are off screen
        if (_obstacles[i].x < -_obstacles[i].width) {
          _obstacles.removeAt(i);
          continue;
        }

        // Better collision detection with buffer zone
        if (_obstacles[i].x < platformX + _platformWidth &&
            _obstacles[i].x + _obstacles[i].width > platformX &&
            _obstacles[i].y < platformY + _platformHeight &&
            _obstacles[i].y + _obstacles[i].height > platformY) {
          _gameOver = true;
          // Play game over sound or vibration here if needed
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
    _coinTimer?.cancel();
    _obstacleTimer?.cancel();
    _gameTimer?.cancel();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;

        // 🔄 Fetch name from 'users' collection
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final displayName = userDoc.data()?['name'] ?? 'Anonymous';

        final leaderboardCollection = FirebaseFirestore.instance.collection(
          'leaderboard',
        );

        // ✅ 1. Save to exercise-specific leaderboard (push_up)
        await leaderboardCollection.doc('push_up_$uid').set({
          'uid': uid,
          'name': displayName,
          'exercise': 'push_up',
          'score': FieldValue.increment(_score),
          'timestamp': Timestamp.now(),
        }, SetOptions(merge: true));

        // ✅ 2. Also update combined leaderboard
        await leaderboardCollection.doc('combined_$uid').set({
          'uid': uid,
          'name': displayName,
          'exercise': 'combined',
          'score': FieldValue.increment(_score),
          'timestamp': Timestamp.now(),
        }, SetOptions(merge: true));

        final combinedDoc =
            await leaderboardCollection.doc('combined_$uid').get();
        final combinedScore = (combinedDoc.data()?['score'] ?? 0) as int;

        // 🧠 Map score to level string
        final levelName = determineLevel(combinedScore);

        // ✅ Update level in 'users' collection with name
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'level': levelName,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error saving score to leaderboard: $e");
    }

    widget.onGameComplete(_score);
  }

  String determineLevel(int score) {
    if (score < 200) return 'Beginner';
    if (score < 400) return 'Intermediate';
    if (score < 600) return 'Advanced';
    if (score < 1000) return 'Pro';
    return 'Elite';
  }

  @override
  void dispose() {
    _platformController.dispose();
    _pushupSubscription.cancel();
    _coinTimer?.cancel();
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
                isFrontCamera:
                    _currentLensDirection == CameraLensDirection.front,
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
                color: _themeColor.withOpacity(0.7),
                border: Border.all(color: _themeColor, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        // Coins
        ..._coins.map(
          (coin) => Positioned(
            left: coin.x,
            top: coin.y,
            width: coin.size,
            height: coin.size,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange[800]!, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(Icons.star, color: Colors.orange[800], size: 16),
              ),
            ),
          ),
        ),

        // Platform (controlled by pushups)
        Positioned(
          left: MediaQuery.of(context).size.width / 4,
          top:
              MediaQuery.of(context).size.height * _platformPosition -
              _platformHeight / 2,
          width: _platformWidth,
          height: _platformHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.fitness_center, color: Colors.white, size: 16),
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
              color: _themeColor,
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
                color: _themeColor.withOpacity(0.8),
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
                color: _themeColor.withOpacity(0.8),
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
                'Do pushups to move the platform up and down. Collect coins and avoid obstacles!',
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
                backgroundColor: _themeColor,
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

        // Back button
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
              _currentLensDirection == CameraLensDirection.back
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

// Class to represent coins
class Coin {
  double x;
  double y;
  final double size;

  Coin({required this.x, required this.y, required this.size});
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
