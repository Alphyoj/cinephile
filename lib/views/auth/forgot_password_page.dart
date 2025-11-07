import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/utils/validators.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text('Reset password', style: TextStyle(color: AppColors.text, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: CustomTextField(hint: 'Enter your email', controller: _email, keyboardType: TextInputType.emailAddress, validator: Validators.validateEmail),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: authVM.busy ? null : () async {
                  if (_formKey.currentState!.validate()) {
                    await authVM.sendResetEmail(_email.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent')));
                    Navigator.pop(context);
                  }
                },
                child: const Text('Send reset email'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
