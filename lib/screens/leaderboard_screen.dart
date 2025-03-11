import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  final List<Map<String, dynamic>> leaderboard = [
    {'rank': 1, 'name': 'ANANTH', 'points': 950},
    {'rank': 2, 'name': 'AJMIN', 'points': 870},
    {'rank': 3, 'name': 'DIAS', 'points': 830},
    {'rank': 4, 'name': 'JIBIN', 'points': 790},
    {'rank': 5, 'name': 'JEEVAN', 'points': 750},
    {'rank': 6, 'name': 'ARUN', 'points': 720},
    {'rank': 7, 'name': 'RAJATH', 'points': 690},
    {'rank': 8, 'name': 'ADARSH', 'points': 670},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0E0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
        title: Text("Leaderboard"),
      ),
      body: ListView.builder(
        itemCount: leaderboard.length,
        itemBuilder: (context, index) {
          final user = leaderboard[index];
          return Card(
            color: Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple,
                child: Text(
                  user['rank'].toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(user['name'], style: TextStyle(color: Colors.white)),
              trailing: Text(
                "${user['points']} pts",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        },
      ),
    );
  }
}
