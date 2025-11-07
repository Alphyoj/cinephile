import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../core/utils/validators.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // App Logo / Title
                const SizedBox(height: 40),
                Text(
                  'CINEPHILE',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dive deep into movie plots & twists',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 30),

                // Email field
                CustomTextField(
                  hint: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 12),

                // Password field
                CustomTextField(
                  hint: 'Password',
                  controller: _password,
                  obscure: true,
                  validator: Validators.validatePassword,
                  showPasswordToggle: true,
                ),
                const SizedBox(height: 14),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordPage(),
                      ),
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: authVM.busy
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              final ok = await authVM.signIn(
                                _email.text.trim(),
                                _password.text.trim(),
                              );
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      authVM.error ?? 'Login failed',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    child: authVM.busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Divider
                Row(
                  children: const [
                    Expanded(child: Divider(color: AppColors.surface)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'OR',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.surface)),
                  ],
                ),
                const SizedBox(height: 12),

                // Google Sign-In button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.surface),
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.text,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Image.asset('lib/assets/google.png', height: 20),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 15),
                    ),
                    onPressed: authVM.busy
                        ? null
                        : () async {
                            final ok = await authVM.signInWithGoogle();
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    authVM.error ?? 'Google sign-in failed',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                ),

                const SizedBox(height: 24),

                // Signup text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "New to Cinephile? ",
                      style: TextStyle(color: AppColors.muted),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignupPage(),
                        ),
                      ),
                      child: const Text(
                        'Sign up now',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
