
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/download_service.dart';
import '../state/auth_state.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';
import '../widgets/app_backdrop.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DownloadService _downloadService = DownloadService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _autoOffController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _showEditNameModal = false;
  bool _showAutoOffModal = false;
  bool _showPasswordModal = false;
  int _downloadCount = 0;
  List<String> _languages = [];
  String _audioQuality = 'High (320 kbps)';

  static const List<String> availableLanguages = [
    'Tamil', 'Hindi', 'English', 'Telugu', 'Kannada', 'Malayalam', 'Punjabi', 'Bengali', 'Marathi', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadStats();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _autoOffController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloads = await _downloadService.getDownloads();
      final languages = prefs.getStringList('preferredLanguages') ?? const [];
      final autoOff = prefs.getString('autoOffMinutes');
      final autoNext = prefs.getString('autoPlayNextEnabled');
      final quality = prefs.getString('audioQuality') ?? 'High (320 kbps)';

      if (!mounted) return;
      setState(() {
        _downloadCount = downloads.length;
        _languages = languages;
        _audioQuality = quality;
      });

      final player = context.read<PlayerState>();
      if (autoOff != null) {
        final minutes = int.tryParse(autoOff);
        if (minutes != null && minutes > 0) {
          player.setSleepTimer(minutes);
        }
      }
      if (autoNext != null) {
        player.setAutoPlayNextEnabled(autoNext == 'true');
      }
    } catch (_) {}
  }

  Future<void> _handleClearCache() async {
    final auth = context.read<AuthState>();
    final messenger = ScaffoldMessenger.of(context);
    await auth.clearAppCache();
    messenger.showSnackBar(const SnackBar(content: Text('App cache cleared successfully')));
  }

  Future<void> _handleLogout() async {
    final nav = Navigator.of(context);
    final auth = context.read<AuthState>();
    await auth.logout();
    nav.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _saveEditedName() async {
    final nextName = _nameController.text.trim();
    if (nextName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    final auth = context.read<AuthState>();
    final messenger = ScaffoldMessenger.of(context);
    await auth.updateUserName(nextName);
    if (!mounted) return;
    setState(() => _showEditNameModal = false);
    messenger.showSnackBar(const SnackBar(content: Text('Profile name updated')));
  }

  Future<void> _setAutoOffMinutes(int? minutes) async {
    final player = context.read<PlayerState>();
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    if (minutes == null) {
      await prefs.remove('autoOffMinutes');
      player.clearSleepTimer();
      messenger.showSnackBar(const SnackBar(content: Text('Auto Off is turned off')));
      return;
    }

    await prefs.setString('autoOffMinutes', minutes.toString());
    player.setSleepTimer(minutes);
    messenger.showSnackBar(SnackBar(content: Text('Music will stop after $minutes minutes')));
  }

  Future<void> _saveCustomAutoOff() async {
    final minutes = int.tryParse(_autoOffController.text.trim());
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid minutes')));
      return;
    }
    await _setAutoOffMinutes(minutes);
    if (!mounted) return;
    setState(() => _showAutoOffModal = false);
  }

  Future<void> _toggleAutoPlayNext() async {
    final player = context.read<PlayerState>();
    final nextValue = !player.autoPlayNextEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('autoPlayNextEnabled', nextValue.toString());
    player.setAutoPlayNextEnabled(nextValue);
  }

  Future<void> _setAudioQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audioQuality', quality);
    setState(() => _audioQuality = quality);
  }

  void _openEditNameModal() {
    final auth = context.read<AuthState>();
    _nameController.text = (auth.user?['name'] ?? '').toString();
    setState(() => _showEditNameModal = true);
  }

  void _openAutoOffModal() {
    final current = context.read<PlayerState>().sleepTimerMinutes;
    _autoOffController.text = current?.toString() ?? '';
    setState(() => _showAutoOffModal = true);
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all password fields')));
      return;
    }
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password must be at least 6 characters')));
      return;
    }
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match')));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthState>();
    try {
      await auth.changePassword(currentPassword, newPassword);
      if (!mounted) return;
      setState(() => _showPasswordModal = false);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      messenger.showSnackBar(const SnackBar(content: Text('Password updated')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  void _openLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Music Languages', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableLanguages.map((lang) {
                    final lower = lang.toLowerCase();
                    final isSel = _languages.contains(lower);
                    return FilterChip(
                      selected: isSel,
                      label: Text(lang, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.w600)),
                      selectedColor: const Color(0xFF1DB954),
                      backgroundColor: const Color(0xFF2A2A2A),
                      onSelected: (selected) async {
                        final next = List<String>.from(_languages);
                        if (selected) {
                          next.add(lower);
                        } else {
                          next.remove(lower);
                        }
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setStringList('preferredLanguages', next);
                        setState(() => _languages = next);
                        setModalState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final library = context.watch<LibraryState>();
    final player = context.watch<PlayerState>();
    final email = (auth.user?['email'] ?? '').toString();
    final displayName = (auth.user?['name'] ?? '').toString().trim();
    final initial = (displayName.isNotEmpty ? displayName : email).isNotEmpty
        ? (displayName.isNotEmpty ? displayName : email)[0].toUpperCase()
        : '?';

    return Stack(
      children: [
        const Positioned.fill(child: AppBackdrop()),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Screen Header (Aligned properly below status bar)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person, color: Color(0xFF1DB954), size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 24),

                // User Profile Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Color(0xFF1DB954), Color(0xFF1ED760)]),
                        ),
                        child: Center(
                          child: Text(initial, style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName.isNotEmpty ? displayName : 'Music Enthusiast',
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _openEditNameModal,
                                  child: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Melody Premium', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Quick Stats Row
                Row(
                  children: [
                    _buildStatCard(Icons.favorite, '${library.likedSongs.length}', 'Liked Songs', const Color(0xFFFF6B6B)),
                    const SizedBox(width: 12),
                    _buildStatCard(Icons.download_done, '$_downloadCount', 'Downloads', const Color(0xFF1DB954)),
                    const SizedBox(width: 12),
                    _buildStatCard(Icons.history, '${library.recentlyPlayed.length}', 'Recent', const Color(0xFF00B894)),
                  ],
                ),

                const SizedBox(height: 28),

                // Settings Section Header
                const Text('Playback & Audio', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 12),

                // Audio Streaming Quality Selector
                _buildTile(
                  icon: Icons.high_quality,
                  title: 'Streaming Audio Quality',
                  subtitle: _audioQuality,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        title: const Text('Select Audio Quality', style: TextStyle(color: Colors.white)),
                        children: ['High (320 kbps)', 'Normal (160 kbps)', 'Data Saver (96 kbps)'].map((q) {
                          return SimpleDialogOption(
                            onPressed: () {
                              _setAudioQuality(q);
                              Navigator.pop(ctx);
                            },
                            child: Text(q, style: TextStyle(color: _audioQuality == q ? const Color(0xFF1DB954) : Colors.white70, fontWeight: _audioQuality == q ? FontWeight.bold : FontWeight.normal)),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),

                // Sleep Timer (Auto Off)
                _buildTile(
                  icon: Icons.timer_outlined,
                  title: 'Sleep Timer (Auto Off)',
                  subtitle: player.sleepTimerMinutes == null ? 'Off' : 'Stops in ${player.sleepTimerMinutes} mins',
                  trailing: Text(player.sleepTimerMinutes == null ? 'Off' : '${player.sleepTimerMinutes}m', style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold)),
                  onTap: _openAutoOffModal,
                ),

                // Auto Play Next Track
                _buildTile(
                  icon: Icons.skip_next_outlined,
                  title: 'Autoplay Similar Songs',
                  subtitle: 'Keep playing when queue finishes',
                  trailing: Switch(
                    value: player.autoPlayNextEnabled,
                    activeTrackColor: const Color(0xFF1DB954),
                    onChanged: (_) => _toggleAutoPlayNext(),
                  ),
                  onTap: _toggleAutoPlayNext,
                ),

                const SizedBox(height: 24),
                const Text('Preferences & Storage', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 12),

                // Preferred Languages Tile
                _buildTile(
                  icon: Icons.language,
                  title: 'Music Languages',
                  subtitle: _languages.isEmpty ? 'All languages' : _languages.join(', ').toUpperCase(),
                  onTap: _openLanguagePicker,
                ),

                // Downloaded Songs Manager
                _buildTile(
                  icon: Icons.download_for_offline_outlined,
                  title: 'Offline Songs Manager',
                  subtitle: '$_downloadCount songs saved for offline playback',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You have $_downloadCount offline songs')));
                  },
                ),

                // Clear Cache
                _buildTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear Cache & Temp Files',
                  subtitle: 'Free up storage space',
                  onTap: _handleClearCache,
                ),

                const SizedBox(height: 24),
                const Text('Account & Security', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 12),

                // Change Password
                _buildTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update account password',
                  onTap: () => setState(() => _showPasswordModal = true),
                ),

                // Logout Button
                _buildTile(
                  icon: Icons.logout,
                  title: 'Log Out',
                  subtitle: 'Signed in as $email',
                  titleColor: Colors.redAccent,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        title: const Text('Log Out?', style: TextStyle(color: Colors.white)),
                        content: const Text('Are you sure you want to log out of Tamil Music?', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleLogout();
                            },
                            child: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),
                const Center(
                  child: Text('Tamil Music v2.0.0+4', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),

        // Modals
        if (_showEditNameModal) _buildModalShell(_buildEditNameForm()),
        if (_showAutoOffModal) _buildModalShell(_buildAutoOffForm(player)),
        if (_showPasswordModal) _buildModalShell(_buildPasswordForm()),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(count, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color titleColor = Colors.white,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: titleColor == Colors.redAccent ? Colors.redAccent.withValues(alpha: 0.12) : const Color(0xFF282828),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: titleColor == Colors.redAccent ? Colors.redAccent : const Color(0xFF1DB954), size: 20),
        ),
        title: Text(title, style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
      ),
    );
  }

  Widget _buildModalShell(Widget content) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildEditNameForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Edit Profile Name', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter name',
            filled: true,
            fillColor: const Color(0xFF282828),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => setState(() => _showEditNameModal = false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954)),
              onPressed: _saveEditedName,
              child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoOffForm(PlayerState player) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sleep Timer (Auto Off)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [15, 30, 45, 60].map((mins) {
            return ActionChip(
              backgroundColor: const Color(0xFF282828),
              label: Text('$mins mins', style: const TextStyle(color: Color(0xFF1DB954))),
              onPressed: () {
                _setAutoOffMinutes(mins);
                setState(() => _showAutoOffModal = false);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _autoOffController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Or enter custom minutes',
            filled: true,
            fillColor: const Color(0xFF282828),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                _setAutoOffMinutes(null);
                setState(() => _showAutoOffModal = false);
              },
              child: const Text('Turn Off', style: TextStyle(color: Colors.redAccent)),
            ),
            Row(
              children: [
                TextButton(onPressed: () => setState(() => _showAutoOffModal = false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954)),
                  onPressed: _saveCustomAutoOff,
                  child: const Text('Set Timer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Change Password', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        TextField(
          controller: _currentPasswordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Current password',
            filled: true,
            fillColor: const Color(0xFF282828),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'New password',
            filled: true,
            fillColor: const Color(0xFF282828),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Confirm new password',
            filled: true,
            fillColor: const Color(0xFF282828),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => setState(() => _showPasswordModal = false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954)),
              onPressed: _changePassword,
              child: const Text('Update', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}
