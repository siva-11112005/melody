import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/download_service.dart';
import '../state/auth_state.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DownloadService _downloadService = DownloadService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _autoOffController = TextEditingController();

  bool _showEditNameModal = false;
  bool _showAutoOffModal = false;
  int _downloadCount = 0;
  List<String> _languages = [];
  List<String> _favoriteArtists = [];

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
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloads = await _downloadService.getDownloads();
      final languages = prefs.getStringList('preferredLanguages') ?? const [];
      final artistsRaw = prefs.getString('favoriteArtists');
      final autoOff = prefs.getString('autoOffMinutes');
      final autoNext = prefs.getString('autoPlayNextEnabled');

      if (!mounted) return;
      setState(() {
        _downloadCount = downloads.length;
        _languages = languages;
        _favoriteArtists = artistsRaw == null
            ? const []
            : (jsonDecode(artistsRaw) as List).map((e) => e.toString()).toList();
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
    await context.read<AuthState>().clearAppCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
  }

  Future<void> _handleLogout() async {
    await context.read<AuthState>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _saveEditedName() async {
    final nextName = _nameController.text.trim();
    if (nextName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    await context.read<AuthState>().updateUserName(nextName);
    if (!mounted) return;
    setState(() => _showEditNameModal = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated')));
  }

  Future<void> _setAutoOffMinutes(int? minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final player = context.read<PlayerState>();
    if (minutes == null) {
      await prefs.remove('autoOffMinutes');
      player.clearSleepTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto Off is turned off')));
      return;
    }

    await prefs.setString('autoOffMinutes', minutes.toString());
    player.setSleepTimer(minutes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Music will stop after $minutes minutes')));
  }

  Future<void> _saveCustomAutoOff() async {
    final minutes = int.tryParse(_autoOffController.text.trim());
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter minutes only')));
      return;
    }
    await _setAutoOffMinutes(minutes);
    if (!mounted) return;
    setState(() => _showAutoOffModal = false);
  }

  Future<void> _toggleAutoPlayNext() async {
    final prefs = await SharedPreferences.getInstance();
    final player = context.read<PlayerState>();
    final nextValue = !player.autoPlayNextEnabled;
    await prefs.setString('autoPlayNextEnabled', nextValue.toString());
    player.setAutoPlayNextEnabled(nextValue);
  }

  void _openAutoOffModal() {
    final current = context.read<PlayerState>().sleepTimerMinutes;
    _autoOffController.text = current?.toString() ?? '';
    setState(() => _showAutoOffModal = true);
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
        Container(color: const Color(0xFF121212)),
        SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Text('Tamil Music', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayName.isNotEmpty ? displayName : 'Music Lover',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _openEditNameModal,
                          child: const Icon(Icons.create_outlined, size: 18, color: Color(0xFF1DB954)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(color: Color(0xFF888888), fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statCard('${library.likedSongs.length}', 'Liked'),
                    _statCard('$_downloadCount', 'Downloads'),
                    _statCard('${library.recentlyPlayed.length}', 'Played'),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 20, top: 25, bottom: 12),
                child: Text('Your Preferences', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (_languages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text('Languages', style: TextStyle(color: Colors.white, fontSize: 15)),
                      ),
                      Flexible(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: _languages.map((language) => _chip(language)).toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/language'),
                        child: const Icon(Icons.create_outlined, color: Color(0xFF1DB954), size: 18),
                      ),
                    ],
                  ),
                ),
              if (_favoriteArtists.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text('Favorite Artists', style: TextStyle(color: Colors.white, fontSize: 15)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/artist-pick'),
                        child: const Icon(Icons.create_outlined, color: Color(0xFFfd79a8), size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _favoriteArtists.map((artist) => _chip(artist)).toList(),
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.only(left: 20, top: 25, bottom: 12),
                child: Text('Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _menuItem(
                icon: Icons.delete_outline,
                label: 'Clear Cache',
                onTap: _handleClearCache,
              ),
              _menuItem(
                icon: Icons.bedtime_outlined,
                label: player.sleepTimerMinutes != null ? 'Auto Off: ${player.sleepTimerMinutes} min' : 'Auto Off (Custom Time)',
                onTap: _openAutoOffModal,
              ),
              _menuItem(
                icon: Icons.bedtime,
                label: player.sleepTimerMinutes != null ? 'Turn Off Auto Off' : 'Auto Off is Off',
                iconColor: player.sleepTimerMinutes != null ? const Color(0xFF1DB954) : const Color(0xFFb3b3b3),
                onTap: () => _setAutoOffMinutes(null),
              ),
              _menuItem(
                icon: player.autoPlayNextEnabled ? Icons.play_arrow : Icons.play_arrow_outlined,
                label: player.autoPlayNextEnabled ? 'Auto Play Next: On' : 'Auto Play Next: Off',
                iconColor: player.autoPlayNextEnabled ? const Color(0xFF1DB954) : const Color(0xFFb3b3b3),
                onTap: _toggleAutoPlayNext,
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
              _menuItem(
                icon: Icons.logout,
                label: 'Logout',
                iconColor: const Color(0xFFe74c3c),
                textColor: const Color(0xFFe74c3c),
                onTap: _handleLogout,
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
        if (_showEditNameModal) _editNameModal(),
        if (_showAutoOffModal) _autoOffModal(),
      ],
    );
  }

  void _openEditNameModal() {
    _nameController.text = (context.read<AuthState>().user?['name'] ?? '').toString();
    setState(() => _showEditNameModal = true);
  }

  Widget _editNameModal() {
    return Positioned.fill(
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
                      onTap: _saveEditedName,
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
    );
  }

  Widget _autoOffModal() {
    return Positioned.fill(
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
                const Text('Set Auto Off', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3a3a3a)),
                  ),
                  child: TextField(
                    controller: _autoOffController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Minutes only (e.g. 45)',
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
                      onTap: () => setState(() => _showAutoOffModal = false),
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
                      onTap: _saveCustomAutoOff,
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
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 13)),
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
