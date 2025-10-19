import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/biometric_service.dart';
import 'package:local_auth/local_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BiometricService _biometricService = BiometricService.instance;
  List<BiometricType> _availableBiometrics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBiometricInfo();
  }

  Future<void> _loadBiometricInfo() async {
    setState(() => _isLoading = true);
    _availableBiometrics = await _biometricService.getAvailableBiometrics();
    setState(() => _isLoading = false);
  }

  Future<void> _toggleBiometric(AuthProvider authProvider, bool currentValue) async {
    if (currentValue) {
      // Disable biometric
      final success = await authProvider.disableBiometric();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication disabled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Enable biometric - need to verify password
      await _showPasswordDialog(authProvider);
    }
  }

  Future<void> _showPasswordDialog(AuthProvider authProvider) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Biometric Login'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please enter your password to enable biometric authentication',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final success = await authProvider.enableBiometric(
        passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Biometric authentication enabled'
                  : authProvider.errorMessage ?? 'Failed to enable biometric',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }

    passwordController.dispose();
  }

  String _getBiometricTypeDisplay() {
    if (_availableBiometrics.isEmpty) return 'None';
    return _biometricService.getBiometricTypeName(_availableBiometrics);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final currentUser = authProvider.currentUser;
          if (currentUser == null) {
            return const Center(child: Text('Not logged in'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Account Section
              _buildSectionTitle('Account Information'),
              _buildInfoCard(
                icon: Icons.person_outline,
                title: 'Display Name',
                subtitle: currentUser.displayName,
              ),
              const SizedBox(height: 8),
              _buildInfoCard(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: currentUser.email,
              ),

              const SizedBox(height: 32),

              // Security Section
              _buildSectionTitle('Security'),
              
              // Biometric Authentication Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.fingerprint,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                      title: const Text(
                        'Biometric Login',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        authProvider.biometricAvailable
                            ? 'Use ${_getBiometricTypeDisplay()} to sign in'
                            : 'Not available on this device',
                      ),
                      trailing: authProvider.biometricAvailable
                          ? Switch(
                              value: currentUser.biometricEnabled,
                              onChanged: _isLoading
                                  ? null
                                  : (value) => _toggleBiometric(
                                        authProvider,
                                        currentUser.biometricEnabled,
                                      ),
                              activeColor: const Color(0xFF6C63FF),
                            )
                          : null,
                    ),
                    if (authProvider.biometricAvailable)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          currentUser.biometricEnabled
                              ? '✓ Biometric authentication is enabled. You can sign in quickly using ${_getBiometricTypeDisplay()}.'
                              : 'Enable biometric authentication to sign in quickly without entering your password.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Device Information Section
              _buildSectionTitle('Device Information'),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.phone_android,
                          color: Colors.blue,
                        ),
                      ),
                      title: const Text(
                        'Biometric Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_getBiometricTypeDisplay()),
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.green,
                        ),
                      ),
                      title: const Text(
                        'Device Supported',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        authProvider.biometricAvailable ? 'Yes' : 'No',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Exit
              _buildSectionTitle('Exit'),
              Card(
                elevation: 2,
                color: Colors.red[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Colors.red,
                    ),
                  ),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: const Text('Sign out of your account'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _handleSignOut(authProvider),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6C63FF),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignOut(AuthProvider authProvider) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await authProvider.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

