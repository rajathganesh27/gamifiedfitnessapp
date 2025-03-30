import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  @override
  _PhoneLoginScreenState createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      String phoneNumber = _phoneController.text.trim();

      // Ensure the phone number starts with +91 (India)
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+91' + phoneNumber;
      }

      final authService = Provider.of<AuthService>(context, listen: false);

      try {
        await authService.initiatePhoneLogin(
          phoneNumber,
          (PhoneAuthCredential credential) async {
            // Auto-verification completed (usually on Android)
            setState(() {
              _isLoading = false;
            });

            final result = await FirebaseAuth.instance.signInWithCredential(
              credential,
            );
            bool isNewUser = result.additionalUserInfo?.isNewUser ?? false;

            if (isNewUser) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(result.user!.uid)
                  .set({
                    'uid': result.user!.uid,
                    'phone': result.user!.phoneNumber,
                    'createdAt': Timestamp.now(),
                    'level': 'Beginner',
                    'profileCompleted': false,
                  });
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        OTPVerificationScreen(phoneNumber: phoneNumber),
              ),
            );
          },
          (FirebaseAuthException e) {
            // Verification failed
            setState(() {
              _isLoading = false;
              _errorMessage = e.message;
            });
          },
          (String verificationId, int? resendToken) {
            // Code sent to the phone number
            setState(() {
              _isLoading = false;
            });

            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        OTPVerificationScreen(phoneNumber: phoneNumber),
              ),
            );
          },
          (String verificationId) {
            // Auto-retrieval timeout
            setState(() {
              _isLoading = false;
            });
          },
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Phone Login')),
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
                  'Enter your phone number',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (without +91)',
                    hintText: '9876543210',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!RegExp(r'^[6789]\d{9}$').hasMatch(value)) {
                      return 'Enter a valid 10-digit phone number';
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
                  onPressed: _isLoading ? null : _sendOTP,
                  child:
                      _isLoading
                          ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                          : Text('Send OTP'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
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
