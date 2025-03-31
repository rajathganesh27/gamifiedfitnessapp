import 'package:flutter/material.dart';
import 'package:gamifiedfitnessapp/model/exercise_dart_model.dart';
import 'package:gamifiedfitnessapp/screens/leaderboard_screen.dart';
import 'package:gamifiedfitnessapp/screens/profile_screen.dart';
import 'package:gamifiedfitnessapp/screens/detection_screen.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class UserDashboard extends StatefulWidget {
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> with SingleTickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  TabController? _tabController;
  int _selectedIndex = 0;
  
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

  // Dummy exercise data for the chart
  final List<FlSpot> weightData = [
    FlSpot(0, 87),
    FlSpot(1, 85),
    FlSpot(2, 86),
    FlSpot(3, 84),
    FlSpot(4, 86),
    FlSpot(5, 85),
    FlSpot(6, 87),
  ];

  final Map<String, dynamic> exerciseStats = {
    'currentWeight': 87,
    'goalWeight': 95,
    'progress': 23,
    'calories': 2600,
    'protein': 180,
    'carbs': 260,
    'fat': 80,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    loadCameras();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> loadCameras() async {
    _cameras = await availableCameras();
    setState(() {}); // Rebuild when cameras are loaded
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Handle navigation
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LeaderboardScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    }
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
                _buildWeightDataCard(),
                SizedBox(height: 20),
                _buildNutritionCards(),
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
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen()),
            );
          },
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              size: 26,
              color: Colors.black87,
            ),
          ),
        ),
        Icon(Icons.notifications_none_outlined, size: 26),
      ],
    );
  }

  Widget _buildWeightDataCard() {
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
              Text(
                "Weight data",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.white),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWeightDataColumn(
                "${exerciseStats['currentWeight']}",
                "kg",
                "Current",
              ),
              _buildWeightDataColumn(
                "${exerciseStats['goalWeight']}",
                "kg",
                "Goal",
              ),
              _buildWeightDataColumn(
                "${exerciseStats['progress']}",
                "%",
                "Progress",
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildTabBar(),
          SizedBox(height: 20),
          Container(
            height: 100,
            child: _buildWeightChart(),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Mon", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              Text("Tue", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              Text("Wed", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              Text("Thu", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              Text("Fri", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              Text("Sat", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              Text("Sun", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightDataColumn(String value, String unit, String label) {
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
                text: " $unit",
                style: GoogleFonts.poppins(
                  fontSize: 16,
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

  Widget _buildWeightChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: weightData,
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
        minY: 80,
        maxY: 90,
      ),
    );
  }

  Widget _buildNutritionCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            Text(
              "Weekly",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildNutritionCard(
                "Calories",
                "${exerciseStats['calories']}",
                "cal",
                Colors.white,
                Icons.local_fire_department_outlined,
                Colors.amber,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildNutritionCard(
                "Protein",
                "${exerciseStats['protein']}",
                "g",
                Colors.black,
                Icons.fastfood_outlined,
                Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildNutritionCard(
                "Carbs",
                "${exerciseStats['carbs']}",
                "g",
                Colors.blue,
                Icons.pie_chart_outline,
                Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildNutritionCard(
                "Fat",
                "${exerciseStats['fat']}",
                "g",
                Colors.blue.shade100,
                Icons.water_drop_outlined,
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNutritionCard(
    String title,
    String value,
    String unit,
    Color bgColor,
    IconData icon,
    Color iconColor,
  ) {
    final textColor = bgColor == Colors.black ? Colors.white : Colors.black;
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: bgColor,
                  size: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          RichText(
            text: TextSpan(
              text: value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              children: [
                TextSpan(
                  text: " $unit",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
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
                      Text(
                        "Last: Today, 10:30 AM",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
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
                          );
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