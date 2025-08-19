
import 'package:flutter/material.dart';


import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/home_screen.dart';
import 'pages/community_screen.dart';
import 'pages/my_reports_screen.dart';
import 'pages/profile_screen.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';


void main() async {
	WidgetsFlutterBinding.ensureInitialized();
	await Firebase.initializeApp(
		options: DefaultFirebaseOptions.currentPlatform,
	);
	runApp(const MyApp());
}

class MyApp extends StatelessWidget {
	const MyApp({super.key});

	@override
	Widget build(BuildContext context) {
			return MaterialApp(
				title: 'Billboard Compliance',
				theme: ThemeData(
					primarySwatch: Colors.blue,
					scaffoldBackgroundColor: Colors.grey[100],
					useMaterial3: true,
				),
				initialRoute: '/login',
						routes: {
							'/login': (context) => const LoginPage(),
							'/signup': (context) => const SignUpPage(),
							'/main': (context) => const MainNavigation(),
						},
				debugShowCheckedModeBanner: false,
			);
	}
}

class MainNavigation extends StatefulWidget {
	const MainNavigation({super.key});

	@override
	State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
	int _selectedIndex = 0;

	static final List<Widget> _pages = <Widget>[
		HomeScreen(),
		CommunityScreen(),
		MyReportsScreen(),
		ProfileScreen(),
	];

	void _onItemTapped(int index) {
		setState(() {
			_selectedIndex = index;
		});
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: SafeArea(child: _pages[_selectedIndex]),
			bottomNavigationBar: BottomNavigationBar(
				type: BottomNavigationBarType.fixed,
				currentIndex: _selectedIndex,
				onTap: _onItemTapped,
				selectedItemColor: Colors.blue[700],
				unselectedItemColor: Colors.grey[600],
				items: const [
					BottomNavigationBarItem(
						icon: Icon(Icons.home),
						label: 'Home',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.groups),
						label: 'Community',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.assignment),
						label: 'My Reports',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.person),
						label: 'Profile',
					),
				],
			),
		);
	}
}
