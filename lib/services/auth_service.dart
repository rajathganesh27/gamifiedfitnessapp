import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _isAdmin = false;
  String? _verificationId;
  int? _resendToken;

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      await _checkIfAdmin();
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isAdmin => _isAdmin;
  String? get verificationId => _verificationId;

  // 🔹 Check if the logged-in user is an admin (fetch role from Firestore)
  Future<void> _checkIfAdmin() async {
    if (_user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_user!.uid).get();
      _isAdmin = userDoc.exists && (userDoc['role'] == 'admin');
    } else {
      _isAdmin = false;
    }
    notifyListeners();
  }

  // 🔹 Email Sign In
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = result.user;
      await _checkIfAdmin();
      notifyListeners();

      return _isAdmin ? "admin" : "user";
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // 🔹 Register with Email & Store Phone Number in Firestore
  Future<String?> registerWithEmail(
    String email,
    String password,
    String name,
    String phone,
    int age,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email,
        'name': name,
        'phone': phone,
        'age': age,
        'level': 'Beginner', // 👈 initial level
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // 🔹 Initiate Phone Authentication (Send OTP)
  Future<void> initiatePhoneLogin(
    String phoneNumber,
    Function(PhoneAuthCredential) verificationCompleted,
    Function(FirebaseAuthException) verificationFailed,
    Function(String, int?) codeSent,
    Function(String) codeAutoRetrievalTimeout,
  ) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        notifyListeners();
        codeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
    );
  }

  // 🔹 Verify OTP & Store User in Firestore
  Future<String?> verifyOTP(String smsCode) async {
    try {
      if (_verificationId == null) {
        return "Verification ID is null. Restart authentication.";
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      _user = userCredential.user;
      notifyListeners();

      if (_user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(_user!.uid).get();

        if (!userDoc.exists) {
          // Store new user with phone number
          await _firestore.collection('users').doc(_user!.uid).set({
            'phone': _user!.phoneNumber,
            'role': 'user',
            'createdAt': Timestamp.now(),
            'points': 0,
            'badges': [],
            'workouts': [],
          });
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // 🔹 Complete profile information (for OTP users)
  Future<String?> completeProfile(String name) async {
    try {
      if (_user != null) {
        await _firestore.collection('users').doc(_user!.uid).update({
          'name': name,
        });
        return null;
      } else {
        return "User is not authenticated";
      }
    } catch (e) {
      return e.toString();
    }
  }

  // 🔹 Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    _isAdmin = false;
    notifyListeners();
  }
}
