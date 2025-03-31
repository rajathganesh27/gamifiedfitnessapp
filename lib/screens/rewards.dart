import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RewardsScreen extends StatefulWidget {
  @override
  _RewardsScreenState createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> userAchievements = {};

  @override
  void initState() {
    super.initState();
    _loadUserAchievements();
  }

  Future<void> _loadUserAchievements() async {
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('user_achievements')
            .doc(uid)
            .get();

        if (doc.exists) {
          setState(() {
            userAchievements = doc.data() as Map<String, dynamic>;
          });
        } else {
          // Create default achievements if none exist
          userAchievements = {
            'pushups': {'level': 1, 'count': 0, 'target': 20},
            'squats': {'level': 1, 'count': 0, 'target': 20},
            'jumpingjacks': {'level': 1, 'count': 0, 'target': 30},
            'bicepcurls': {'level': 1, 'count': 0, 'target': 15},
          };

          // Save default achievements to Firestore
          await FirebaseFirestore.instance
              .collection('user_achievements')
              .doc(uid)
              .set(userAchievements);
        }
      }
    } catch (e) {
      print('Error loading achievements: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "My Achievements",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: BackButton(color: Colors.black),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blue))
          : _buildRewardsContent(),
    );
  }

  Widget _buildRewardsContent() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildHeader(),
        SizedBox(height: 24),
        _buildExerciseBadges(
          "Push Ups",
          "pushups",
          Icons.fitness_center,
          Colors.blue,
          ["Bronze", "Silver", "Gold"],
          [20, 50, 100],
        ),
        SizedBox(height: 24),
        _buildExerciseBadges(
          "Squats",
          "squats",
          Icons.accessibility_new,
          Colors.green,
          ["Bronze", "Silver", "Gold"],
          [20, 50, 100],
        ),
        SizedBox(height: 24),
        _buildExerciseBadges(
          "Jumping Jacks",
          "jumpingjacks",
          Icons.directions_run,
          Colors.orange,
          ["Bronze", "Silver", "Gold"],
          [30, 75, 150],
        ),
        SizedBox(height: 24),
        _buildExerciseBadges(
          "Bicep Curls",
          "bicepcurls",
          Icons.fitness_center,
          Colors.purple,
          ["Bronze", "Silver", "Gold"],
          [15, 40, 80],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    // Calculate total unlocked badges
    int totalBadges = 0;
    int unlockedBadges = 0;

    userAchievements.forEach((exercise, data) {
      totalBadges += 3; // 3 badges per exercise
      unlockedBadges += (data['level'] as int) - 1;
    });

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Progress",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "$unlockedBadges of $totalBadges badges unlocked",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: totalBadges > 0 ? unlockedBadges / totalBadges : 0,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseBadges(
    String title,
    String exerciseKey,
    IconData icon,
    Color color,
    List<String> badgeLevels,
    List<int> targetCounts,
  ) {
    final exerciseData = userAchievements[exerciseKey] ??
        {'level': 1, 'count': 0, 'target': targetCounts[0]};

    final currentLevel = exerciseData['level'] as int;
    final currentCount = exerciseData['count'] as int;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Level $currentLevel • ${currentCount} completed",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(3, (index) {
              bool isUnlocked = currentLevel > index + 1;
              bool isCurrent = currentLevel == index + 1;

              return _buildBadge(
                badgeLevels[index],
                targetCounts[index],
                color,
                isUnlocked,
                isCurrent,
                currentCount,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(
    String level,
    int target,
    Color color,
    bool isUnlocked,
    bool isCurrent,
    int currentCount,
  ) {
    final progress = isCurrent ? (currentCount / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? color
                    : isCurrent
                        ? Colors.grey.shade200
                        : Colors.grey.shade100,
                shape: BoxShape.circle,
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: isUnlocked
                  ? Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 40,
                    )
                  : isCurrent
                      ? CircularProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          strokeWidth: 6,
                        )
                      : Icon(
                          Icons.lock,
                          color: Colors.grey.shade400,
                          size: 30,
                        ),
            ),
            if (isUnlocked)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 12),
        Text(
          level,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isUnlocked ? color : Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "$target reps",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}