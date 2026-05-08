import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../state/library_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _showEditNameModal = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final library = context.watch<LibraryState>();
    final email = (auth.user?['email'] ?? '').toString();
    final displayName = (auth.user?['name'] ?? '').toString().trim();
    final initial = (displayName.isNotEmpty ? displayName : email).isNotEmpty
        ? (displayName.isNotEmpty ? displayName : email)[0].toUpperCase()
        : '?';

    return Stack(
      children: [
        Container(color: const Color(0xFF121212)),
        SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top branding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Text('Tamil Music', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Profile header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF8B5CF6),
                      ),
                      child: Center(
                        child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName.isNotEmpty ? displayName : 'Music Lover',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(color: Color(0xFF888888), fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statCard('${library.likedSongs.length}', 'Liked'),
                    _statCard('0', 'Downloads'),
                    _statCard('${library.recentlyPlayed.length}', 'Played'),
                  ],
                ),
              ),

              // Your Preferences
              const Padding(
                padding: EdgeInsets.only(left: 20, top: 25, bottom: 12),
                child: Text('Your Preferences', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _prefRow(
                label: 'Languages',
                trailing: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/language'),
                  child: const Icon(Icons.edit_outlined, color: Color(0xFF1DB954), size: 18),
                ),
              ),
              _prefRow(
                label: 'Favorite Artists',
                trailing: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/artist-pick'),
                  child: const Icon(Icons.edit_outlined, color: Color(0xFFfd79a8), size: 18),
                ),
              ),

              // Settings
              const Padding(
                padding: EdgeInsets.only(left: 20, top: 25, bottom: 12),
                child: Text('Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _menuItem(
                icon: Icons.delete_outline,
                label: 'Clear Cache',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: const Text('Clear Cache', style: TextStyle(color: Colors.white)),
                      content: const Text('This will clear search history and cached data.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await context.read<AuthState>().clearAppCache();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _menuItem(
                icon: Icons.info_outline,
                label: 'About',
                onTap: () {},
              ),
              _menuItem(
                icon: Icons.vpn_key_outlined,
                label: 'Change Password',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password change UI can be connected to your backend auth endpoint.')),
                  );
                },
              ),
              const SizedBox(height: 10),
              _menuItem(
                icon: Icons.logout,
                label: 'Logout',
                iconColor: const Color(0xFFe74c3c),
                textColor: const Color(0xFFe74c3c),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: const Text('Logout', style: TextStyle(color: Colors.white)),
                      content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await context.read<AuthState>().logout();
                            if (!context.mounted) return;
                            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Text('Tamil Music App v1.0.0', style: TextStyle(color: Colors.white.withValues(alpha: 0.27), fontSize: 12)),
                ),
              ),
            ],
          ),
        ),

        // Edit name modal
        if (_showEditNameModal)
          Positioned.fill(
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1f1f1f),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2f2f2f)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Name', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2a2a2a),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF3a3a3a)),
                        ),
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Enter your name',
                            hintStyle: TextStyle(color: Color(0xFF777777)),
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _showEditNameModal = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2a2a2a),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: Color(0xFFDDDDDD), fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () async {
                              final nextName = _nameController.text.trim();
                              if (nextName.isEmpty) return;
                              await context.read<AuthState>().updateUserName(nextName);
                              if (!mounted) return;
                              setState(() => _showEditNameModal = false);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _statCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      constraints: const BoxConstraints(minWidth: 90),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1e1e),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Color(0xFF1DB954), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _prefRow({required String label, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFFb3b3b3),
    Color textColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF222222), width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 16))),
            Icon(Icons.chevron_right, color: iconColor == const Color(0xFFe74c3c) ? const Color(0xFFe74c3c) : const Color(0xFF555555), size: 18),
          ],
        ),
      ),
    );
  }
}
