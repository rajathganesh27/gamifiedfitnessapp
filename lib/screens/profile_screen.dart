import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      backgroundColor: Color(0xFF0E0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
        title: Text("User Profile"),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              // TODO: Navigate to Edit Profile Screen
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                "No user data found",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                SizedBox(height: 10),
                Text(
                  userData['name'] ?? "User",
                  style: TextStyle(fontSize: 22, color: Colors.white),
                ),
                Text(
                  userData['email'] ?? "No Email",
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 20),
                ProfileTile(
                  Icons.star,
                  "Level",
                  userData['level'] ?? "Beginner",
                ),
                ProfileTile(
                  Icons.cake,
                  "Age",
                  userData['age']?.toString() ?? "N/A",
                ),
                ProfileTile(
                  Icons.phone,
                  "Phone Number",
                  userData['phone'] ?? "N/A",
                ),
                SizedBox(height: 20),
                // ListTile(
                //   leading: Icon(Icons.settings, color: Colors.white),
                //   title: Text(
                //     "Settings",
                //     style: TextStyle(color: Colors.white),
                //   ),
                //   onTap: () {
                //     // TODO: Implement Settings Navigation
                //   },
                // ),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text("Logout", style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await authService.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title, value;
  ProfileTile(this.icon, this.title, this.value);
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: TextStyle(color: Colors.white)),
      trailing: Text(value, style: TextStyle(color: Colors.white70)),
    );
  }
}
