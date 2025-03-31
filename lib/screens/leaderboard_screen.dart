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
      backgroundColor: const Color(0xFF0E0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text("Leaderboard", style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // 🔽 Dropdown menu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF1C1C1E),
              decoration: InputDecoration(
                labelText: "Select Exercise",
                labelStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              value: _selectedExercise,
              items:
                  _exerciseLabels.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: const TextStyle(color: Colors.white),
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

          // 🔁 Leaderboard display
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection(getCollectionName(_selectedExercise))
                      .orderBy('score', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      "Something went wrong",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No leaderboard data available.",
                      style: TextStyle(color: Colors.white),
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

                return Column(
                  children: [
                    if (currentUserData.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Your Rank: #${currentUserData['rank']}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "${currentUserData['score']} pts",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: leaderboard.length,
                        itemBuilder: (context, index) {
                          final user = leaderboard[index];
                          final isCurrentUser = user['uid'] == currentUser?.uid;

                          return Card(
                            color:
                                isCurrentUser
                                    ? Colors.purple.withOpacity(0.3)
                                    : const Color(0xFF1C1C1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    isCurrentUser ? Colors.purple : Colors.grey,
                                child: Text(
                                  user['rank'].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                user['name'],
                                style: TextStyle(
                                  color:
                                      isCurrentUser
                                          ? Colors.purpleAccent
                                          : Colors.white,
                                  fontWeight:
                                      isCurrentUser
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              trailing: Text(
                                "${user['score']} pts",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
