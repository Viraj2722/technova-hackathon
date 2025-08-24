import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../widgets/app_header.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<Map<String, int>>? _statsFuture;
  Future<List<LeaderboardUser>>? _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _statsFuture = fetchStats();
    _leaderboardFuture = fetchLeaderboard();
  }

  Future<Map<String, int>> fetchStats() async {
    final baseUrl = 'http://192.168.0.103:8000'; // Change to your backend URL
    try {
      final monthResp =
          await http.get(Uri.parse('$baseUrl/reports/count/month'));
      final resolvedResp =
          await http.get(Uri.parse('$baseUrl/reports/count/resolved'));
      final monthCount = jsonDecode(monthResp.body)['count'] ?? 0;
      final resolvedCount = jsonDecode(resolvedResp.body)['count'] ?? 0;
      return {
        'month': monthCount,
        'resolved': resolvedCount,
      };
    } catch (e) {
      print('Error fetching stats: $e');
      return {'month': 0, 'resolved': 0};
    }
  }

  Future<List<LeaderboardUser>> fetchLeaderboard() async {
    final baseUrl = 'http://192.168.0.103:8000'; // Change to your backend URL
    try {
      final response = await http.get(Uri.parse('$baseUrl/leaderboard/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final leaderboardData = data['leaderboard'] as List;
        return leaderboardData
            .map((user) => LeaderboardUser.fromJson(user))
            .toList();
      } else {
        throw Exception('Failed to load leaderboard');
      }
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: AppHeader(),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Community Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: Colors.blue[600],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[600],
          tabs: const [
            Tab(text: 'Stats'),
            Tab(text: 'Leaderboard'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStatsTab(),
              _buildLeaderboardTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    return FutureBuilder<Map<String, int>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final monthCount = snapshot.data?['month'] ?? 0;
        final resolvedCount = snapshot.data?['resolved'] ?? 0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$monthCount',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[600],
                            ),
                          ),
                          Text(
                            'Reports This Month',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$resolvedCount',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[600],
                            ),
                          ),
                          Text(
                            'Total Resolved',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardTab() {
    return FutureBuilder<List<LeaderboardUser>>(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Failed to load leaderboard',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _leaderboardFuture = fetchLeaderboard();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No leaderboard data yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start reporting to see rankings!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _leaderboardFuture = fetchLeaderboard();
            });
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length + 1, // +1 for the header
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildLeaderboardHeader();
              }

              final user = users[index - 1];
              return _buildLeaderboardItem(user, index - 1);
            },
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.amber[100]!, Colors.orange[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.orange[600], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Leaderboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Earn 10 points for each resolved report',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(LeaderboardUser user, int index) {
    Color getBackgroundColor() {
      switch (user.rank) {
        case 1:
          return Colors.amber[50]!;
        case 2:
          return Colors.grey[100]!;
        case 3:
          return Colors.orange[50]!;
        default:
          return Colors.white;
      }
    }

    Color getBorderColor() {
      switch (user.rank) {
        case 1:
          return Colors.amber[200]!;
        case 2:
          return Colors.grey[300]!;
        case 3:
          return Colors.orange[200]!;
        default:
          return Colors.grey[200]!;
      }
    }

    Widget getRankWidget() {
      if (user.rank <= 3) {
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: user.rank == 1
                ? Colors.amber[400]
                : user.rank == 2
                    ? Colors.grey[400]
                    : Colors.orange[400],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${user.rank}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      } else {
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${user.rank}',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor()),
        boxShadow: user.rank <= 3
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          getRankWidget(),
          const SizedBox(width: 16),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getAvatarColor(user.username),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(
                    fontSize: 14, // Made username a little smaller
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.totalReports} reports • ${user.resolvedReports} resolved',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user.points} pts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: user.rank <= 3 ? Colors.orange[700] : Colors.blue[600],
                ),
              ),
              if (user.rank <= 3)
                Icon(
                  Icons.emoji_events,
                  size: 16,
                  color: Colors.orange[600],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String username) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[username.hashCode % colors.length];
  }
}

class LeaderboardUser {
  final String userId;
  final String username;
  final int points;
  final int totalReports;
  final int resolvedReports;
  final int rejectedReports;
  final int rank;

  LeaderboardUser({
    required this.userId,
    required this.username,
    required this.points,
    required this.totalReports,
    required this.resolvedReports,
    required this.rejectedReports,
    required this.rank,
  });

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) {
    return LeaderboardUser(
      userId: json['user_id'] ?? '',
      username: json['username'] ?? 'Unknown User',
      points: json['points'] ?? 0,
      totalReports: json['total_reports'] ?? 0,
      resolvedReports: json['resolved_reports'] ?? 0,
      rejectedReports: json['rejected_reports'] ?? 0,
      rank: json['rank'] ?? 0,
    );
  }
}
