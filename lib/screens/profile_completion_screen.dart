import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'user_dashboard.dart';

class ProfileCompletionScreen extends StatefulWidget {
  @override
  _ProfileCompletionScreenState createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.user;

      if (user != null) {
        try {
          DocumentReference userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid);
          DocumentSnapshot userDoc = await userRef.get();

          if (userDoc.exists) {
            // Update the existing user document
            await userRef.update({
              'name': _nameController.text.trim(),
              'profileCompleted': true, // Marks profile as complete
            });
          } else {
            // Create a new document in case of an issue
            await userRef.set({
              'name': _nameController.text.trim(),
              'phone': user.phoneNumber ?? "",
              'email': user.email ?? "",
              'createdAt': Timestamp.now(),
              'points': 0,
              'badges': [],
              'workouts': [],
              'profileCompleted': true,
            });
          }

          setState(() {
            _isLoading = false;
          });

          // Navigate to the user dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => UserDashboard()),
          );
        } catch (e) {
          setState(() {
            _isLoading = false;
            _errorMessage = "Failed to complete profile. Try again.";
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "User is not authenticated.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Almost Done!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'Please complete your profile to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _completeProfile,
                  child:
                      _isLoading
                          ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                          : Text('Complete Profile'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
