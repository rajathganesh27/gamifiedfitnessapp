import 'package:flutter/material.dart';
import 'package:gamifiedfitnessapp/model/exercise_dart_model.dart';
import 'package:gamifiedfitnessapp/screens/leaderboard_screen.dart';
import 'package:gamifiedfitnessapp/screens/profile_screen.dart';
import 'package:gamifiedfitnessapp/screens/detection_screen.dart';
import 'package:camera/camera.dart';
import 'package:gamifiedfitnessapp/screens/rewards.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserDashboard extends StatefulWidget {
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> with SingleTickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  TabController? _tabController;
  int _selectedIndex = 0;

  // Pedometer variables
  late Stream<StepCount> _stepCountStream;
  late Stream<PedestrianStatus> _pedestrianStatusStream;
  String _status = '?', _steps = '0';
  List<FlSpot> _stepsData = List.generate(7, (index) => FlSpot(index.toDouble(), 0));

  // Firebase variables
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;
  Map<String, dynamic> _weeklyStepData = {};
  bool _isLoadingData = true;

  // Local storage for today's step count
  int _localStepCount = 0;
  String _todayDate = '';

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
      title: 'Jumping Jack',
      image: 'jumping.gif',
      color: Color(0xff000000),
      type: ExerciseType.JumpingJack,
    ),
    ExerciseDataModel(
      title: 'Bicep Curl',
      image: 'curl.gif',
      color: Color(0xff000000),
      type: ExerciseType.BicepCurl,
    ),
  ];

  final Map<String, dynamic> exerciseStats = {
    'dailyStepGoal': 10000,
    'weeklyStepGoal': 70000,
    'progress': 0,
    'calories': 2600,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    loadCameras();
    _initializeUser();

    // Set up a timer to check if we need to perform midnight sync
    _setupMidnightSync();
  }

  void _setupMidnightSync() {
    // Get current time
    DateTime now = DateTime.now();

    // Calculate time until next midnight
    DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);
    Duration timeUntilMidnight = nextMidnight.difference(now);

    // Set up a delayed sync at midnight
    Future.delayed(timeUntilMidnight, () {
      _performMidnightSync();
      // Set up the next day's sync
      _setupMidnightSync();
    });
  }

  Future<void> _performMidnightSync() async {
    // Ensure we have the final data for today saved to Firebase
    await _saveStepsToFirebase(_localStepCount);

    // Reset local step count for the new day
    setState(() {
      _localStepCount = 0;
      _steps = "0";
      exerciseStats['progress'] = 0;
      _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    });

    // Save the reset to local storage
    await _saveLocalStepCount(0);

    // Reload weekly data to show the new day
    await _loadUserStepData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    // Get current user ID
    User? user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;

      // Load local step count first
      await _loadLocalStepCount();

      // Then load data from Firebase
      await _loadUserStepData();

      // Initialize pedometer after loading data
      initPedometer();
    }
  }

  Future<void> _loadLocalStepCount() async {
    final prefs = await SharedPreferences.getInstance();
    final localDate = prefs.getString('localStepDate') ?? '';

    // If we have step data for today, load it
    if (localDate == _todayDate) {
      setState(() {
        _localStepCount = prefs.getInt('localStepCount') ?? 0;
        _steps = _localStepCount.toString();
        _updateProgressBar(_localStepCount);
      });
    } else {
      // If it's a new day, reset the counter
      await _saveLocalStepCount(0);
    }
  }

  Future<void> _saveLocalStepCount(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('localStepCount', steps);
    await prefs.setString('localStepDate', _todayDate);
    await prefs.setString('lastSyncTime', DateTime.now().toIso8601String());
  }

  void _updateProgressBar(int steps) {
    int progress = ((steps / exerciseStats['dailyStepGoal']) * 100).toInt();
    if (progress > 100) progress = 100;

    setState(() {
      exerciseStats['progress'] = progress;
    });
  }

  Future<void> loadCameras() async {
    _cameras = await availableCameras();
    setState(() {}); // Rebuild when cameras are loaded
  }

  Future<bool> _checkActivityRecognitionPermission() async {
    bool granted = await Permission.activityRecognition.isGranted;
    if (!granted) {
      granted = await Permission.activityRecognition.request() ==
          PermissionStatus.granted;
    }
    return granted;
  }

  Future<void> initPedometer() async {
    bool granted = await _checkActivityRecognitionPermission();
    if (!granted) {
      // Show permission denied message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity recognition permission is required for step tracking')),
      );
      return;
    }

    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;
    _pedestrianStatusStream.listen(onPedestrianStatusChanged)
        .onError(onPedestrianStatusError);

    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(onStepCount).onError(onStepCountError);
  }

  void onStepCount(StepCount event) async {
    int steps = event.steps;

    // Update local step count
    _localStepCount = steps;

    // Update the UI immediately
    setState(() {
      _steps = steps.toString();
      _updateProgressBar(steps);
    });

    // Save locally for immediate persistence
    await _saveLocalStepCount(steps);

    // Update weekly chart with the latest data
    _updateStepsChartWithLocalData();

    // Save to Firebase immediately (removed the time-based check)
    _saveStepsToFirebase(steps);
  }

  void _updateStepsChartWithLocalData() {
    // Make a copy of the weekly data
    List<FlSpot> updatedData = List<FlSpot>.from(_stepsData);

    // Update today's value in the chart
    int todayIndex = DateTime.now().weekday - 1; // Assuming the last spot is today
    if (updatedData.length > todayIndex) {
      updatedData[todayIndex] = FlSpot(todayIndex.toDouble(), _localStepCount.toDouble());
    }

    setState(() {
      _stepsData = updatedData;
    });
  }

  Future<void> _saveStepsToFirebase(int steps) async {
    if (_userId == null) return;

    try {
      // Check if today's record already exists
      DocumentSnapshot stepDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('stepData')
          .doc(_todayDate)
          .get();

      if (stepDoc.exists) {
        // Update existing record
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('stepData')
            .doc(_todayDate)
            .update({
          'steps': steps,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new record
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('stepData')
            .doc(_todayDate)
            .set({
          'date': _todayDate,
          'steps': steps,
          'created': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving steps data: $e');
    }
  }

  Future<void> _loadUserStepData() async {
    if (_userId == null) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      // Get the past 7 days dates, ensuring Monday is the first day
      List<String> lastSevenDays = [];
      DateTime now = DateTime.now();

      // Determine current weekday (1 = Monday, 7 = Sunday)
      int currentWeekday = now.weekday;

      // Start from the beginning of the current week (Monday)
      DateTime startOfWeek = now.subtract(Duration(days: currentWeekday - 1));

      for (int i = 0; i < 7; i++) {
        DateTime date = startOfWeek.add(Duration(days: i));
        lastSevenDays.add(DateFormat('yyyy-MM-dd').format(date));
      }

      // Initialize data map with zeros
      Map<String, dynamic> weekData = {};
      for (String date in lastSevenDays) {
        weekData[date] = 0;
      }

      // Query Firestore for the step data
      QuerySnapshot stepsSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('stepData')
          .where('date', whereIn: lastSevenDays)
          .get();

      // Populate data
      for (var doc in stepsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        weekData[data['date']] = data['steps'];
      }

      // Special case: If today's data exists in Firebase but is less than our local count,
      // use the local count instead (e.g., if app was restarted)
      if (weekData[_todayDate] < _localStepCount) {
        weekData[_todayDate] = _localStepCount;
      } else if (weekData[_todayDate] > _localStepCount && weekData[_todayDate] > 0) {
        // If Firebase has a higher count (maybe from another device), update our local
        _localStepCount = weekData[_todayDate];
        setState(() {
          _steps = _localStepCount.toString();
          _updateProgressBar(_localStepCount);
        });
        await _saveLocalStepCount(_localStepCount);
      }

      // Convert to chart data
      List<FlSpot> chartData = [];
      for (int i = 0; i < lastSevenDays.length; i++) {
        int steps = weekData[lastSevenDays[i]] ?? 0;
        chartData.add(FlSpot(i.toDouble(), steps.toDouble()));
      }

      setState(() {
        _weeklyStepData = weekData;
        _stepsData = chartData;
        _isLoadingData = false;
      });
    } catch (e) {
      print('Error loading step data: $e');
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  void onPedestrianStatusChanged(PedestrianStatus event) {
    setState(() {
      _status = event.status;
    });
  }

  void onPedestrianStatusError(error) {
    setState(() {
      _status = 'Status not available';
    });
  }

  void onStepCountError(error) {
    print('Step count error: $error');
    // Don't reset steps to 0 on error, keep the last known value
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 2) {
      // Leaderboard
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LeaderboardScreen()),
      ).then((_) => _loadUserStepData());
    } else if (index == 3) {
      // Profile
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      ).then((_) => _loadUserStepData());
    } else if (index == 1) {
      // Rewards (new)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RewardsScreen()),
      );
    }
  }


  // Get day name from date
  String _getDayName(int dayOffset) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayOffset];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: 24),
                _buildStepCountCard(),
                SizedBox(height: 20),
               // _buildCaloriesCard(),
                SizedBox(height: 20),
                Text(
                  "Exercises",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                _buildExercisesList(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

 Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Empty space on the left
        SizedBox(width: 40),

        // Profile icon on the right
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen()),
            ).then(
              (_) => _loadUserStepData(),
            ); // Reload data when returning from profile
          },
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person, // Profile icon
              size: 26,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildStepCountCard() {
    // Get step status icon
    IconData statusIcon = Icons.help_outline;
    if (_status == 'walking') {
      statusIcon = Icons.directions_walk;
    } else if (_status == 'stopped') {
      statusIcon = Icons.accessibility_new;
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    "Step Counter",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(statusIcon, color: Colors.white, size: 18),
                ],
              ),
              Text(
                "Auto-updating",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepDataColumn(
                _steps,
                "steps",
                "Today",
              ),
              _buildStepDataColumn(
                "${exerciseStats['dailyStepGoal']}",
                "steps",
                "Goal",
              ),
              _buildStepDataColumn(
                "${exerciseStats['progress']}",
                "%",
                "Progress",
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildTabBar(),
          SizedBox(height: 20),
          _isLoadingData
              ? Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                )
              : Container(
                  height: 100,
                  child: _buildStepsChart(),
                ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              return Text(
                _getDayName(index),
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDataColumn(String value, String unit, String label) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            text: value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: "\n$unit",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTab("All", 0),
          _buildTab("Month", 1),
          _buildTab("Week", 2),
          _buildTab("Day", 3),
        ],
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    bool isSelected = _tabController?.index == index;
    return GestureDetector(
      onTap: () {
        _tabController?.animateTo(index);
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStepsChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _stepsData,
            isCurved: true,
            color: Colors.white,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Colors.blue,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: _stepsData.isEmpty
            ? 10000
            : _stepsData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.2,
      ),
    );
  }

 Widget _buildCaloriesCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Calories",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department_outlined,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: "${exerciseStats['calories']}",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: " cal",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Daily Goal: 2,800 cal",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              Container(
                height: 60,
                width: 60,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: exerciseStats['calories'] / 2800,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        "${((exerciseStats['calories'] / 2800) * 100).toInt()}%",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  } 

  Widget _buildExercisesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        return Container(
          height: 100,
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/${workout.image}',
                    width: 75,
                    height: 75,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        workout.title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 5),
                      FutureBuilder<DocumentSnapshot>(
                        future: _userId != null
                            ? _firestore
                                .collection('users')
                                .doc(_userId)
                                .collection('exerciseHistory')
                                .doc(workout.title.toLowerCase().replaceAll(' ', '_'))
                                .get()
                            : null,
                        builder: (context, snapshot) {
                          String lastTime = "Not started yet";

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            lastTime = "Loading...";
                          } else if (snapshot.hasData && snapshot.data!.exists) {
                            Map<String, dynamic>? data = snapshot.data!.data() as Map<String, dynamic>?;
                            if (data != null && data.containsKey('lastCompleted')) {
                              Timestamp timestamp = data['lastCompleted'] as Timestamp;
                              DateTime dateTime = timestamp.toDate();
                              lastTime = "Last: ${DateFormat('MMM d, h:mm a').format(dateTime)}";
                            }
                          }

                          return Text(
                            lastTime,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _cameras.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetectionScreen(
                                exerciseDataModel: workout,
                                cameras: _cameras,
                              ),
                            ),
                          ).then((_) => setState(() {})); // Refresh after exercise
                        },
                  child: Text(
                    "Start",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 0),
          _buildNavItem(Icons.insert_chart_outlined, 1),
          _buildNavItem(Icons.timeline, 2),
          _buildNavItem(Icons.apps, 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onNavItemTapped(index),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.grey.shade200 : Colors.transparent,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.grey,
          size: 26,
        ),
      ),

    );
  }
}