import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'screens/artist_pick_screen.dart';
import 'screens/full_player_screen.dart';
import 'screens/home_screen.dart';
import 'screens/language_screen.dart';
import 'screens/library_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/signup_screen.dart';
import 'services/api_service.dart';
import 'state/auth_state.dart';
import 'state/library_state.dart';
import 'state/player_state.dart';
import 'widgets/app_backdrop.dart';
import 'widgets/mini_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.melody.music.channel.audio',
    androidNotificationChannelName: 'Tamil Music Playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
    notificationColor: const Color(0xFF1DB954),
  );
  runApp(const MelodyFlutterApp());
}

class MelodyFlutterApp extends StatelessWidget {
  const MelodyFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState(api)..init()),
        ChangeNotifierProvider(create: (_) => LibraryState(api)..init()),
        ChangeNotifierProvider(create: (_) => PlayerState()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tamil Music',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF1DB954),
            secondary: Color(0xFF1ED760),
            surface: Color(0xFF181818),
            surfaceContainerHighest: Color(0xFF232323),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          tabBarTheme: const TabBarThemeData(
            labelColor: Color(0xFF1DB954),
            unselectedLabelColor: Colors.white70,
            indicatorColor: Color(0xFF1DB954),
            dividerColor: Color(0xFF282828),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            labelStyle: const TextStyle(color: Colors.white70),
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIconColor: Colors.white70,
            suffixIconColor: Colors.white70,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF181818),
            selectedItemColor: Color(0xFF1DB954),
            unselectedItemColor: Colors.white60,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
            bodyLarge: TextStyle(color: Colors.white),
            titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        routes: {
          '/': (_) => const _AuthGate(),
          '/login': (_) => const LoginScreen(),
          '/signup': (_) => const SignupScreen(),
          '/language': (_) => const LanguageScreen(),
          '/artist-pick': (_) => const ArtistPickScreen(),
          '/full-player': (_) => const FullPlayerScreen(),
          '/profile': (_) => const _ProfileStandalone(),
        },
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (!auth.isReady) {
      return const Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: AppBackdrop()),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SplashLogo(),
                  SizedBox(height: 30),
                  CircularProgressIndicator(color: Color(0xFF1DB954)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (!auth.onboardingComplete) {
      return const LanguageScreen();
    }

    return const _MainTabs();
  }
}

class _MainTabs extends StatefulWidget {
  const _MainTabs();

  @override
  State<_MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<_MainTabs> {
  int currentIndex = 0;

  static const tabs = [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: tabs),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiniPlayer(onTap: () => Navigator.pushNamed(context, '/full-player')),
            BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (i) => setState(() => currentIndex = i),
              backgroundColor: const Color(0xFF181818),
              selectedItemColor: const Color(0xFF1DB954),
              unselectedItemColor: Colors.white70,
              selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              showSelectedLabels: true,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
                BottomNavigationBarItem(icon: Icon(Icons.library_music_outlined), activeIcon: Icon(Icons.library_music), label: 'Library'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStandalone extends StatelessWidget {
  const _ProfileStandalone();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: ProfileScreen());
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0x1A1DB954),
        borderRadius: BorderRadius.circular(70),
      ),
      child: Center(
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/icon.png',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
