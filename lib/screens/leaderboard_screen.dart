import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LeaderboardScreen extends StatefulWidget {
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  String _selectedExercise = 'combined'; // default
  final Map<String, String> _exerciseLabels = {
    'combined': 'Total Score',
    'jumping_jack': 'Jumping Jacks',
    'squat': 'Squats',
    'push_up': 'Push Ups',
    'bicep_curl': 'Bicep Curls',
  };

  String getCollectionName(String exercise) {
    switch (exercise) {
      case 'jumping_jack':
        return 'jumping_jacks';
      case 'squat':
        return 'squats';
      case 'push_up':
        return 'push_ups';
      case 'bicep_curl':
        return 'bicep_curls';
      case 'combined':
      default:
        return 'combined_scores';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
        title: Text(
          "Leaderboard",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: Column(
        children: [
          // Exercise selector
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  dropdownColor: Colors.blue,
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  value: _selectedExercise,
                  items:
                      _exerciseLabels.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedExercise = value;
                      });
                    }
                  },
                ),
              ),
            ),
          ),

          // Leaderboard display
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection(getCollectionName(_selectedExercise))
                      .orderBy('score', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Something went wrong",
                      style: TextStyle(color: Colors.black),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 60,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No leaderboard data available.",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                final leaderboard =
                    docs.asMap().entries.map((entry) {
                      int index = entry.key;
                      var doc = entry.value;
                      return {
                        'rank': index + 1,
                        'uid': doc['uid'],
                        'name':
                            (doc['name']?.toString().trim().isNotEmpty ?? false)
                                ? doc['name']
                                : 'Anonymous',
                        'score': doc['score'] ?? 0,
                      };
                    }).toList();

                final currentUserData = leaderboard.firstWhere(
                  (entry) => entry['uid'] == currentUser?.uid,
                  orElse: () => {},
                );

                return CustomScrollView(
                  slivers: [
                    // Top 3 Podium
                    SliverToBoxAdapter(
                      child:
                          leaderboard.length >= 1
                              ? _buildTopThreePodium(leaderboard)
                              : SizedBox.shrink(),
                    ),

                    // User's position
                    SliverToBoxAdapter(
                      child:
                          currentUserData.isNotEmpty
                              ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: _buildUserPositionCard(currentUserData),
                              )
                              : SizedBox.shrink(),
                    ),

                    // Section title
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: 4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              "All Rankings",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Full rankings list
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            // Skip top 3 users in the main list
                            final listIndex = index + 3;
                            if (listIndex >= leaderboard.length) {
                              return null;
                            }

                            final user = leaderboard[listIndex];
                            final isCurrentUser =
                                user['uid'] == currentUser?.uid;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildRankListItem(user, isCurrentUser),
                            );
                          },
                          childCount:
                              leaderboard.length > 3
                                  ? leaderboard.length - 3
                                  : 0,
                        ),
                      ),
                    ),

                    // Bottom padding
                    SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThreePodium(List<Map<String, dynamic>> leaderboard) {
    // Increase container height to accommodate all content
    double podiumContainerHeight = 160; // Increased from 130

    // Calculate podium heights that will fit within the container
    double firstPlaceHeight = 70;
    double secondPlaceHeight = 55;
    double thirdPlaceHeight = 40;

    return SizedBox(
      height: podiumContainerHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (leaderboard.length >= 2)
            Flexible(
              child: _buildPodiumItem(
                leaderboard[1],
                2,
                Colors.grey.shade300,
                secondPlaceHeight,
                leaderboard[1]['uid'] == currentUser?.uid,
              ),
            ),

          // 1st Place
          if (leaderboard.length >= 1)
            Flexible(
              child: _buildPodiumItem(
                leaderboard[0],
                1,
                Colors.amber,
                firstPlaceHeight,
                leaderboard[0]['uid'] == currentUser?.uid,
              ),
            ),

          // 3rd Place
          if (leaderboard.length >= 3)
            Flexible(
              child: _buildPodiumItem(
                leaderboard[2],
                3,
                Colors.brown.shade300,
                thirdPlaceHeight,
                leaderboard[2]['uid'] == currentUser?.uid,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserPositionCard(Map<String, dynamic> userData) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 20,
              child: Text(
                "#${userData['rank']}",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your Position",
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    userData['name'],
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${userData['score']} pts",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankListItem(Map<String, dynamic> user, bool isCurrentUser) {
    return Card(
      elevation: isCurrentUser ? 2 : 0.5,
      color: isCurrentUser ? Colors.blue.withOpacity(0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isCurrentUser
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
          width: isCurrentUser ? 1 : 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: _getRankColor(user['rank']),
          radius: 18,
          child: Text(
            user['rank'].toString(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          user['name'],
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.blue : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "${user['score']} pts",
            style: TextStyle(
              color: isCurrentUser ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumItem(
    Map<String, dynamic> user,
    int position,
    Color color,
    double height,
    bool isCurrentUser,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: position == 1 ? 18 : 16, // Reduced sizes
              backgroundColor: isCurrentUser ? Colors.blue : color,
              child: Icon(
                position == 1
                    ? Icons.emoji_events
                    : (position == 2
                        ? Icons.workspace_premium
                        : Icons.military_tech),
                color: Colors.white,
                size: position == 1 ? 14 : 12,
              ),
            ),
            SizedBox(height: 1), // Reduced spacing
            Container(
              width: 65, // Slightly reduced
              child: Text(
                user['name'].toString(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCurrentUser ? Colors.blue : Colors.black,
                  fontSize: 10,
                ),
              ),
            ),
            SizedBox(height: 1), // Reduced spacing
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ), // Reduced padding
              decoration: BoxDecoration(
                color: isCurrentUser ? Colors.blue : color.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${user['score']} pts",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
            SizedBox(height: 1), // Reduced spacing
            Container(
              width: 40,
              height: height,
              decoration: BoxDecoration(
                color: isCurrentUser ? Colors.blue : color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey.shade400;
    if (rank == 3) return Colors.brown.shade300;
    return Colors.blue.shade300;
  }
}
