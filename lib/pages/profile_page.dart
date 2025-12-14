import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cineholmes/screens/login_page.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _currentUser;
  final AuthService _authService = AuthService();
  bool _loading = true;

  // 1. Avatar Asset Yollarının Tanımlanması
  final List<String> _avatarAssets = const [
    'assets/avatars/AAGRBT0C7xk_1765710192725.png',
    'assets/avatars/AAGRBT0C7xk_1765710192730.png',
    'assets/avatars/AAGRBT0C7xk_1765710388485.png',
    'assets/avatars/AAGRBT0C7xk_1765710388489.png',
    'assets/avatars/AAGRBT0C7xk_1765710388506.png',
    'assets/avatars/AAGRBT0C7xk_1765710568040.png',
    'assets/avatars/AAGRBT0C7xk_1765710568053.png',
    'assets/avatars/AAGRBT0C7xk_1765710568056.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    setState(() {
      _currentUser = FirebaseAuth.instance.currentUser;
      _loading = false;
    });
  }

  String get email => _currentUser?.email ?? "Email not found.";

  String get username {
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.isNotEmpty) {
      return _currentUser!.displayName!;
    }
    return _currentUser?.email?.split('@')[0] ?? "User";
  }

  bool get isEmailPasswordUser {
    if (_currentUser == null) return false;
    return _currentUser!.providerData.any(
      (info) => info.providerId == 'password',
    );
  }

  // Profil fotoğrafını Firebase'de güncelleyen metot
  Future<void> _updateProfilePicture(String newAssetPath) async {
    try {
      await _currentUser?.updatePhotoURL(newAssetPath);
      await _loadUserData(); 

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully! ✅',style: TextStyle(color: Colors.white),),backgroundColor: Color.fromARGB(255, 49, 49, 49),behavior: SnackBarBehavior.floating,));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile picture: $e',style: TextStyle(color: Colors.white),),backgroundColor: Color.fromARGB(255, 49, 49, 49),behavior: SnackBarBehavior.floating,));
        
      }
    }
  }

  // Avatar seçimi için diyalog 
  void _showAvatarSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select New Profile Picture"),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: _avatarAssets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, 
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final assetPath = _avatarAssets[index];
              
              return GestureDetector(
                onTap: () async {
                  Navigator.pop(context); 
                  await _updateProfilePicture(assetPath); 
                },
                // ClipOval ve BoxFit.cover kullanılarak resmin tam doldurulması sağlanıyor.
                child: ClipOval(
                  child: Container(
                    // Boyut 90'a çıkarıldı.
                    width: 90,  
                    height: 90, 
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      border: Border.all(color: Colors.black12, width: 1.0)
                    ),
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.cover, // Resmin kutuyu tam doldurması için
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_off,
                  size: 60,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(height: 12),
                Text(
                  "No user is currently logged in.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => LoginPage()),
                      (route) => false,
                    );
                  },
                  child: const Text("Go to Login"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Instagram-style header
            _buildInstagramHeader(isDark),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Profile header
                    _buildProfileHeader(theme, isDark),

                    const SizedBox(height: 24),

                    // Account card
                    _buildAccountCard(theme, isDark),

                    const SizedBox(height: 16),

                    // Security card
                    _buildSecurityCard(theme, isDark),

                    const SizedBox(height: 30),

                    // Logout button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Instagram-style header
  Widget _buildInstagramHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6A0DAD), Color(0xFF9D4EDD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'CineHolmes',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                fontFamily: 'Pacifico',
                color: Colors.white,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Profile header
  Widget _buildProfileHeader(ThemeData theme, bool isDark) {
    final gradientColors = [
      const Color(0xFF6A0DAD),
      const Color(0xFF9D4EDD),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Row(
        children: [
          // Avatar (Dokunma alanı eklendi)
          GestureDetector(
            onTap: _showAvatarSelectionDialog,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 40, // Boyut artırıldı
                // Fotoğrafı yükleme mantığı
                backgroundImage: _currentUser?.photoURL != null 
                    // Eğer photoURL bir Asset yolu ile başlıyorsa (yani bizim kaydettiğimiz avatar ise)
                    ? (_currentUser!.photoURL!.startsWith('assets/') 
                        ? AssetImage(_currentUser!.photoURL!)
                        : NetworkImage(_currentUser!.photoURL!)) // Aksi halde gerçek bir URL'dir
                    : null,
                
                backgroundColor: Colors.white.withOpacity(0.1),
                child: _currentUser?.photoURL == null
                    ? const Icon(Icons.person, size: 34, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name + email + chip
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        isEmailPasswordUser
                            ? 'Email & Password'
                            : 'Social Login',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: Colors.white.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Account card
  Widget _buildAccountCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              "Account",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Divider(
            height: 8,
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),

          // Email Row
          ListTile(
            leading: Icon(
              Icons.email_outlined,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            title: Text(
              "Email",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              email,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.copy,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: email));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Email copied to clipboard.",style: TextStyle(color: Colors.white),),backgroundColor: Color.fromARGB(255, 49, 49, 49),behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ),

          // Username Row
          ListTile(
            leading: Icon(
              Icons.person_outline,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            title: Text(
              "Username",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              username,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.edit,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              onPressed: _showChangeUsernameDialog,
            ),
          ),
        ],
      ),
    );
  }

  // Security card
  Widget _buildSecurityCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              "Security",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Divider(
            height: 8,
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),

          if (isEmailPasswordUser)
            ListTile(
              leading: Icon(
                Icons.lock_outline,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              title: Text(
                "Change Password",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                "Update your account password securely.",
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              onTap: _showChangePasswordDialog,
              trailing: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            )
          else
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              title: Text(
                "Password Managed Externally",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                "You signed in with a social provider. Please manage your password from your Google / Apple / provider account.",
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Logout
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await _authService.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully logged out.')),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => LoginPage(),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Logout Error: $e')));
        }
      }
    }
  }

  // Username dialog
  void _showChangeUsernameDialog() {
    String newUsername = username;
    final controller = TextEditingController(text: username);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Username"),
        content: TextField(
          controller: controller,
          onChanged: (value) {
            newUsername = value;
          },
          decoration: const InputDecoration(hintText: "New Username"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newUsername.isNotEmpty && newUsername != username) {
                
                try {
                  await _currentUser?.updateDisplayName(newUsername);
                  await _loadUserData();

                  if (mounted) {
                    Navigator.pop(context); // İşlem başarılı, dialog'u kapat
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Username Updated ✅')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    // Hata durumunda da dialog'u kapat
                    if (Navigator.of(context).canPop()) {
                       Navigator.pop(context); 
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              } else {
                Navigator.pop(context); // Eğer isim değiştirilmediyse kapat
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // Password dialog (FIXED - GÜVENLİK VE MESSAGING AKIŞI DÜZELTİLDİ)
  void _showChangePasswordDialog() {
    if (!isEmailPasswordUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password cannot be changed for social media accounts.',
          ),
        ),
      );
      return;
    }

    String currentPassword = "";
    String newPassword = "";
    String confirmPassword = "";
    String? errorMessage;
    final formKey = GlobalKey<FormState>();
    final dialogContext = context; // Ana diyalog bağlamını sakla

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Change Password"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hata mesajı gösterimi
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 200, 199, 199),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color.fromARGB(255, 200, 199, 199)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextFormField(
                  obscureText: true,
                  onChanged: (value) {
                    currentPassword = value;
                    // Hata mesajı varsa, yeni girişle temizle
                    if (errorMessage != null) {
                      setState(() => errorMessage = null);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: "Current Password",
                    hintText: "Enter your current password.",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Current password is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  obscureText: true,
                  onChanged: (value) => newPassword = value,
                  decoration: const InputDecoration(
                    labelText: "New Password",
                    hintText: "Enter your new password",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'A new password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be 6 characters minimum';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  obscureText: true,
                  onChanged: (value) => confirmPassword = value,
                  decoration: const InputDecoration(
                    labelText: "Confirm New Password",
                    hintText: "Verify New Password",
                  ),
                  validator: (value) {
                    if (value != newPassword) {
                      return 'Passwords mismatch';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  
                  // 1. Yükleme Ekranını Göster
                  showDialog(
                    context: dialogContext, // Ana diyalog bağlamını kullan
                    barrierDismissible: false,
                    builder: (BuildContext loadingContext) {
                      return Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      );
                    },
                  );

                  try {
                    // 1. Create authentication credential
                    final credential = EmailAuthProvider.credential(
                      email: email,
                      password: currentPassword,
                    );
                    
                    // 2. Reauthenticate with current password - This will throw error if password is wrong
                    await _currentUser?.reauthenticateWithCredential(credential);
                    
                    // 3. If reauthentication successful, update password
                    await _currentUser?.updatePassword(newPassword);

                    // BAŞARILI: Yükleme ve Diyalogları Kapat, SnackBar göster
                    if (mounted) {
                      // Yükleme Ekranını Kapat (rootNavigator: true ile en üstteki diyaloğu kapat)
                      Navigator.of(dialogContext, rootNavigator: true).pop(); 
                      // Şifre Değiştirme Diyaloğunu Kapat
                      Navigator.of(dialogContext, rootNavigator: true).pop(); 
                      
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Password updated successfully! ✅', style: TextStyle(color: Colors.white)),
                          backgroundColor: Color.fromARGB(255, 49, 49, 49),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    // HATA: Authentication failed
                    String newErrorMessage = 'Unknown error';
                    
                    // Hata Kodu Kontrolü ve NET İngilizce Mesaj Ataması
                    if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                      newErrorMessage = 'The current password you entered is incorrect. Your password has NOT been changed.';
                    } else if (e.code == 'weak-password') {
                      newErrorMessage = 'The password you entered is too weak';
                    } else if (e.code == 'requires-recent-login') {
                      newErrorMessage = 'For security reasons, please log out and log in again.';
                    } else {
                      newErrorMessage = 'An error occurred: ${e.message}';
                    }

                    if (mounted) {
                      // 3a. Yükleme Ekranını Kapat (Hata oluşsa bile)
                      Navigator.of(dialogContext, rootNavigator: true).pop(); 
                      
                      // 3b. Diyalog içindeki hata mesajını güncelle (StatefulBuilder sayesinde)
                      setState(() {
                        errorMessage = newErrorMessage;
                      });
                      
                      // 3c. SnackBar göster
                      
                    }
                  } catch (e) {
                    // GENEL HATA:
                    if (mounted) {
                      // Yükleme Ekranını Kapat
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      
                      // Diyalog içindeki hata mesajını güncelle
                      setState(() {
                        errorMessage = 'An unexpected error occurred';
                      });
                      
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: $e', style: const TextStyle(color: Colors.white)),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text("Change"),
            ),
          ],
        ),
      ),
    );
  }
}