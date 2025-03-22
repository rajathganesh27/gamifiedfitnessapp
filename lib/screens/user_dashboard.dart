import 'package:flutter/material.dart';
import 'package:gamifiedfitnessapp/model/exercise_dart_model.dart';
import 'package:gamifiedfitnessapp/screens/leaderboard_screen.dart';
import 'package:gamifiedfitnessapp/screens/profile_screen.dart';
import 'package:gamifiedfitnessapp/screens/detection_screen.dart';
import 'package:camera/camera.dart';

class UserDashboard extends StatefulWidget {
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  List<CameraDescription> _cameras = [];

  final List<ExerciseDataModel> workouts = [
    ExerciseDataModel(
      title: 'Push Ups',
      image: 'pushup.gif',
      color: Color(0xff005F9C),
      type: ExerciseType.PushUps,
    ),
    ExerciseDataModel(
      title: 'Squats',
      image: 'squat.gif',
      color: Color(0xffDF5089),
      type: ExerciseType.Squats,
    ),
    ExerciseDataModel(
      title: 'Plank to Downward Dog',
      image: 'plank.gif',
      color: Color(0xffFD8636),
      type: ExerciseType.DownwardDogPlank,
    ),
    ExerciseDataModel(
      title: 'Jumping Jack',
      image: 'jumping.gif',
      color: Color(0xff000000),
      type: ExerciseType.JumpingJack,
    ),
  ];

  @override
  void initState() {
    super.initState();
    loadCameras();
  }

  Future<void> loadCameras() async {
    _cameras = await availableCameras();
    setState(() {}); // Rebuild when cameras are loaded
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0E0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Workouts",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Games",
              style: TextStyle(
                fontSize: 18,
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  final workout = workouts[index];
                  return Card(
                    color: Color(0xFF1C1C1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/${workout.image}',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  workout.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "Live AI Detection",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed:
                                _cameras.isEmpty
                                    ? null
                                    : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => DetectionScreen(
                                                exerciseDataModel: workout,
                                                cameras: _cameras,
                                              ),
                                        ),
                                      );
                                    },
                            child: Text("Start"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFFFD700),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: Color(0xFF1C1C1E),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.leaderboard, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LeaderboardScreen()),
                );
              },
            ),
            Text(
              "FitQuest",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(Icons.person, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
