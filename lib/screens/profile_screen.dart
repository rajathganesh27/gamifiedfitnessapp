import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  Map<String, dynamic> userData = {};

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _nameController.text = userData['name'] ?? '';
      _ageController.text = userData['age']?.toString() ?? '';
      _heightController.text = userData['height']?.toString() ?? '';
      _weightController.text = userData['weight']?.toString() ?? '';
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'name': _nameController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()) ?? 0,
      'height': int.tryParse(_heightController.text.trim()) ?? 0,
      'weight': int.tryParse(_weightController.text.trim()) ?? 0,
    });

    setState(() {
      _isEditing = false;
      _isLoading = false;
    });
  }

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
            icon: Icon(
              _isEditing ? Icons.close : Icons.edit,
              color: Colors.white,
            ),
            onPressed:
                _isEditing
                    ? () => setState(() => _isEditing = false)
                    : _startEditing,
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

          userData = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: EdgeInsets.all(16),
            child:
                _isEditing
                    ? _buildEditForm()
                    : _buildProfileView(context, userData, authService),
          );
        },
      ),
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          _buildAvatar(),
          SizedBox(height: 20),
          _buildEditableField("Full Name", _nameController, Icons.person),
          _buildEditableField(
            "Age",
            _ageController,
            Icons.cake,
            isNumber: true,
          ),
          _buildEditableField(
            "Height (cm)",
            _heightController,
            Icons.height,
            isNumber: true,
          ),
          _buildEditableField(
            "Weight (kg)",
            _weightController,
            Icons.monitor_weight,
            isNumber: true,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14),
            ),
            child:
                _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: Colors.white),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white),
          prefixIcon: Icon(icon, color: Colors.white),
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Color(0xFF1E1E24),
        ),
      ),
    );
  }

  Widget _buildProfileView(
    BuildContext context,
    Map<String, dynamic> data,
    AuthService authService,
  ) {
    return Column(
      children: [
        _buildAvatar(),
        SizedBox(height: 10),
        Text(
          data['name'] ?? "User",
          style: TextStyle(fontSize: 22, color: Colors.white),
        ),
        Text(
          data['email'] ?? "No Email",
          style: TextStyle(color: Colors.white70),
        ),
        SizedBox(height: 20),
        ProfileTile(Icons.star, "Level", data['level'] ?? "Beginner"),
        ProfileTile(Icons.cake, "Age", data['age']?.toString() ?? "N/A"),
        ProfileTile(Icons.phone, "Phone", data['phone'] ?? "N/A"),
        ProfileTile(Icons.height, "Height", "${data['height'] ?? 'N/A'} cm"),
        ProfileTile(
          Icons.monitor_weight,
          "Weight",
          "${data['weight'] ?? 'N/A'} kg",
        ),
        SizedBox(height: 20),
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
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.purple,
      child: Icon(Icons.person, size: 50, color: Colors.white),
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
