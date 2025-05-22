import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:medcareapp/providers/auth_provider.dart';
import 'package:medcareapp/models/user.dart';
import 'package:medcareapp/utils/theme.dart';
import 'package:medcareapp/utils/constants.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _avatarController;
  bool _isLoading = false;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _avatarController = TextEditingController(text: widget.user.avatar ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return true; // Empty URL is valid (will use default)

    // Very basic URL validation - should start with http:// or https://
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Future<void> _saveProfile() async {
    // Reset image error
    setState(() {
      _imageError = null;
    });

    // Validate form and image URL
    if (_formKey.currentState!.validate()) {
      final imageUrl = _avatarController.text.trim();
      if (imageUrl.isNotEmpty && !_isValidImageUrl(imageUrl)) {
        setState(() {
          _imageError =
              'Please enter a valid URL starting with http:// or https://';
        });
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        final data = {'username': _usernameController.text.trim()};

        // Only include avatar field if not empty
        if (imageUrl.isNotEmpty) {
          data['avatar'] = imageUrl;
        }

        final success = await authProvider.updateProfile(data);

        if (!mounted) return;

        if (success) {
          Fluttertoast.showToast(
            msg: "Profile updated successfully",
            backgroundColor: AppTheme.successColor,
            textColor: Colors.white,
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.error ?? "Failed to update profile"),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        _avatarController.text.isNotEmpty
            ? _avatarController.text
            : defaultProfileImage;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Avatar preview
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: NetworkImage(avatarUrl),
                    onBackgroundImageError: (_, __) {
                      setState(() {
                        _imageError =
                            'Could not load this image. Please check the URL.';
                      });
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),

              if (_imageError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _imageError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],

              const SizedBox(height: 24),

              // Username field
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Username is required';
                  }
                  if (value.length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Avatar URL field
              TextFormField(
                controller: _avatarController,
                decoration: const InputDecoration(
                  labelText: 'Profile Picture URL',
                  hintText: 'Enter URL for your profile picture',
                  prefixIcon: Icon(Icons.image_outlined),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  // Reset error when text changes
                  if (_imageError != null) {
                    setState(() {
                      _imageError = null;
                    });
                  }
                },
              ),

              const SizedBox(height: 8),
              Text(
                'Leave empty to use the default avatar',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),

              const SizedBox(height: 32),

              // Test Image Button
              if (_avatarController.text.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      // Force UI to update and test the image
                      _imageError = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Test Image URL'),
                ),

              const SizedBox(height: 16),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'Save Profile',
                            style: TextStyle(fontSize: 16),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
