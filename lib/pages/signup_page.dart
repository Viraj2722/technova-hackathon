import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  Future<void> _showPhoneInputDialog() async {
    final phoneController = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Phone Number'),
          content: TextFormField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Enter your phone number',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _completeGoogleSignUp(''); // Continue with empty phone
              },
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _completeGoogleSignUp(phoneController.text.trim());
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeGoogleSignUp(String phone) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser!;
    await _storeUserDataInSupabase(
      firebaseUid: user.uid,
      email: user.email!,
      username: user.email!.split('@')[0],
      fullName: user.displayName ?? '',
      phone: phone,
      authProvider: 'google',
    );
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }
  Future<void> _storeUserDataInSupabase({
    required String firebaseUid,
    required String email,
    required String username,
    required String fullName,
    required String phone,
    required String authProvider,
  }) async {
    try {
      await supabaseClient.from('users').upsert({
        'firebase_uid': firebaseUid,
        'email': email,
        'username': username,
        'full_name': fullName,
        'phone': phone,
        'auth_provider': authProvider,
        // created_at and updated_at are handled by DB defaults
      });
    } catch (e) {
      print('Error storing user data in Supabase: $e');
    }
  }
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final supabase.SupabaseClient supabaseClient =
      supabase.Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Create user with Firebase Auth
      final userCredential = await firebase_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Update display name in Firebase
      await userCredential.user
          ?.updateDisplayName(_fullNameController.text.trim());

      // Store user data in Supabase table
      await _storeUserDataInSupabase(
        firebaseUid: userCredential.user!.uid,
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        authProvider: 'email',
      );

      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign up failed. Please try again.';
      });
      print('Sign Up Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Sign out any existing user first
      await _googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      await firebase_auth.FirebaseAuth.instance
          .signInWithCredential(credential);

      // Ask for phone input and complete sign up
      if (context.mounted) {
        await _showPhoneInputDialog();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign in failed. Please try again.';
      });
      print('Google Sign In Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Create account',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // ...existing code...
                  TextFormField(
                    controller: _fullNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                _signUp();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Sign Up', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(
                                'https://developers.google.com/identity/images/g-logo.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      label: const Text('Sign up with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).pushReplacementNamed('/login');
                          },
                    child: const Text('Already have an account? Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
