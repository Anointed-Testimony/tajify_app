import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  int _activeTab = 0; // 0: Contact, 1: Community, 2: Club, 3: Group, 4: Chats
  int _activeCategory = 0;
  final List<String> _mainTabs = ['Contact', 'Community', 'Club', 'Group', 'Chats'];
  final List<String> _communityCategories = [
    'Tech', 'Sports', 'Art', 'Music', 'Gaming', 'Business', 'Travel', 'Food',
  ];
  final List<Map<String, String>> _communities = [
    {
      'name': 'Flutter Devs',
      'image': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?auto=format&fit=crop&w=400&q=80',
      'highlight': 'Build beautiful apps with Flutter!'
    },
    {
      'name': 'Football Fans',
      'image': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=400&q=80',
      'highlight': 'All about the beautiful game.'
    },
    {
      'name': 'Art Lovers',
      'image': 'https://images.unsplash.com/photo-1465101046530-73398c7f28ca?auto=format&fit=crop&w=400&q=80',
      'highlight': 'Share and discuss art.'
    },
    {
      'name': 'Music Makers',
      'image': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=400&q=80',
      'highlight': 'For musicians and fans.'
    },
  ];
  final List<Map<String, dynamic>> _communityPosts = [
    {
      'avatar': 'https://randomuser.me/api/portraits/men/32.jpg',
      'name': 'History',
      'handle': '@ManifestH...',
      'time': 'Jul 10',
      'text': "July 10, 1832: Jackson’s Veto and the Beginning of the End for the 2nd National Bank\n\n1/ On this day, President Andrew Jackson shocked  the nation by vetoing the bill to recharter the Second Bank of the United States. It wasn’t just a policy decision—it was a declaration of war",
      'image': 'https://upload.wikimedia.org/wikipedia/commons/4/4d/Andrew_jackson_head.jpg',
      'comments': 32,
      'likes': 130,
      'shares': 499,
      'views': '311K',
    },
    {
      'avatar': 'https://randomuser.me/api/portraits/men/33.jpg',
      'name': 'C and Assembly Developers',
      'handle': '@forloopcodes',
      'time': '13h',
      'text': "my university is teaching prompt engineering instead of cuda or assembly\n\nis this a sign to drop out?",
      'image': null,
      'comments': 12,
      'likes': 80,
      'shares': 20,
      'views': '2K',
    },
  ];

  final List<Map<String, dynamic>> _groups = [
    {
      'avatar': 'https://randomuser.me/api/portraits/men/40.jpg',
      'name': 'Hiking Buddies',
      'desc': 'Find friends for your next adventure.',
      'members': 120,
    },
    {
      'avatar': 'https://randomuser.me/api/portraits/women/41.jpg',
      'name': 'Bookworms',
      'desc': 'Discuss your favorite books.',
      'members': 89,
    },
    {
      'avatar': 'https://randomuser.me/api/portraits/men/42.jpg',
      'name': 'Gamers United',
      'desc': 'All about gaming and eSports.',
      'members': 200,
    },
  ];

  final List<Map<String, dynamic>> _clubs = [
    {
      'avatar': 'https://randomuser.me/api/portraits/women/43.jpg',
      'name': 'Pro Investors',
      'desc': 'Exclusive club for investment tips.',
      'members': 45,
      'paid': true,
    },
    {
      'avatar': 'https://randomuser.me/api/portraits/men/44.jpg',
      'name': 'Startup Founders',
      'desc': 'Network with other founders.',
      'members': 30,
      'paid': true,
    },
    {
      'avatar': 'https://randomuser.me/api/portraits/women/45.jpg',
      'name': 'Fitness Elite',
      'desc': 'Premium fitness coaching.',
      'members': 60,
      'paid': true,
    },
  ];

  final List<Map<String, dynamic>> _chats = [
    {
      'avatar': 'https://randomuser.me/api/portraits/men/50.jpg',
      'name': 'Ada Lovelace',
      'last': 'See you at the event!',
      'time': '09:52pm',
      'unread': 2,
      'read': false,
    },
    {
      'avatar': 'https://randomuser.me/api/portraits/women/51.jpg',
      'name': 'Grace Hopper',
      'last': 'Thanks for the update.',
      'time': '08:31pm',
      'unread': 0,
      'read': true,
    },
    {
      'avatar': 'https://randomuser.me/api/portraits/men/52.jpg',
      'name': 'Alan Turing',
      'last': 'Let\'s catch up soon.',
      'time': '07:12pm',
      'unread': 1,
      'read': false,
    },
    {
      'avatar': 'https://randomuser.me/api/portraits/women/53.jpg',
      'name': 'Joan Clarke',
      'last': 'Sent the files.',
      'time': 'Yesterday',
      'unread': 0,
      'read': true,
    },
    {
      'avatar': 'https://randomuser.me/api/portraits/men/54.jpg',
      'name': 'Dennis Ritchie',
      'last': 'Haha 😂',
      'time': 'Yesterday',
      'unread': 0,
      'read': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: FloatingActionButton(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          elevation: 4,
          onPressed: () {
            context.go('/home');
          },
          child: const Icon(Icons.home, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar (same as HomeScreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Text('Tajify', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.search, color: Colors.white, size: 20), 
                    onPressed: () {}
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 20), 
                    onPressed: () {}
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.message_outlined, color: Colors.white, size: 20), 
                    onPressed: () {}
                  ),
                  // Vertical divider
                  Container(
                    height: 24,
                    width: 1.2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.grey[600],
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20), 
                    onPressed: () {}
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.person_outline, color: Colors.white, size: 20), 
                    onPressed: () {}
                  ),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_mainTabs.length, (i) =>
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _activeTab = i),
                                child: _tabButton(_mainTabs[i], _activeTab == i),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_activeTab == 4) ...[
                        const SizedBox(height: 18),
                        // Chats List (WhatsApp style)
                        Column(
                          children: List.generate(_chats.length, (i) => _chatConversationCard(_chats[i])),
                        ),
                      ] else if (_activeTab == 2) ...[
                        const SizedBox(height: 18),
                        // Club List (Paid Groups)
                        Column(
                          children: List.generate(_clubs.length, (i) => _groupOrClubCard(_clubs[i], isClub: true)),
                        ),
                      ] else if (_activeTab == 3) ...[
                        const SizedBox(height: 18),
                        // Group List
                        Column(
                          children: List.generate(_groups.length, (i) => _groupOrClubCard(_groups[i], isClub: false)),
                        ),
                      ] else if (_activeTab == 1) ...[
                        const SizedBox(height: 16),
                        // Community Category Tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(_communityCategories.length, (i) =>
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => setState(() => _activeCategory = i),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _activeCategory == i ? Colors.amber : const Color(0xFF2A2A2A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    child: Text(
                                      _communityCategories[i],
                                      style: TextStyle(
                                        color: _activeCategory == i ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Community Feed (Twitter/X style)
                        Column(
                          children: List.generate(_communityPosts.length, (i) => _communityPostCard(_communityPosts[i])),
                        ),
                      ] else ...[
                        const SizedBox(height: 24),
                        // Groups Section
                        _sectionCard(
                          title: 'Groups',
                          items: [
                            _chatItem(
                              avatar: 'https://randomuser.me/api/portraits/men/32.jpg',
                              name: 'Friends Forever',
                              message: 'Hahahahah!',
                              time: 'Today, 9:52pm',
                              unread: 4,
                            ),
                            _chatItem(
                              avatar: 'https://randomuser.me/api/portraits/men/33.jpg',
                              name: 'Mera Gang',
                              message: 'Kyuuuuu???',
                              time: 'Yesterday, 12:31pm',
                            ),
                            _chatItem(
                              avatar: 'https://randomuser.me/api/portraits/men/34.jpg',
                              name: 'Hiking',
                              message: 'It\'s not going to happen',
                              time: 'Wednesday, 9:12am',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // People Section
                        _sectionCard(
                          title: 'People',
                          items: [
                            _chatItem(
                              avatar: 'https://randomuser.me/api/portraits/men/35.jpg',
                              name: 'Anil',
                              message: 'April fool\'s day',
                              time: 'Today, 9:52pm',
                              read: true,
                            ),
                            _chatItem(
                              avatar: 'https://randomuser.me/api/portraits/men/36.jpg',
                              name: 'Chuuthiya',
                              message: 'Baag',
                              time: 'Today, 12:19pm',
                              unread: 1,
                            ),
                            _chatItem(
                              avatar: 'https://randomuser.me/api/portraits/women/37.jpg',
                              name: 'Mary ma\'am',
                              message: 'You have to report it...',
                              time: 'Today, 2:40pm',
                            ),
                            _chatItem(
                              avatar: 'https://randomuser.me/api/portraits/men/38.jpg',
                              name: 'Bill Gates',
                              message: 'Nevermind bro',
                              time: 'Yesterday, 12:31pm',
                              read: true,
                            ),
                            _chatItem(
                              avatar: 'https://randomuser.me/api/portraits/women/39.jpg',
                              name: 'Victoria H',
                              message: 'Okay, brother. let\'s see...',
                              time: 'Wednesday, 11:22am',
                              read: true,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Navigation Bar (same as HomeScreen)
            BottomNavigationBar(
              backgroundColor: const Color(0xFF232323),
              selectedItemColor: Colors.amber,
              unselectedItemColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt_outlined),
                  label: 'Connect',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.live_tv_outlined),
                  label: 'Channel',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_outlined),
                  label: 'Market',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.auto_graph_outlined),
                  label: 'Mining',
                ),
              ],
              currentIndex: 0, // Connect tab
              onTap: (int index) {
                if (index == 0) {
                  return;
                } else if (index == 1) {
                  context.go('/channel');
                }
                // Add navigation for other tabs as needed
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool active) {
    return Container(
      decoration: BoxDecoration(
        color: active ? Colors.amber : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        boxShadow: active
            ? [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)]
            : [],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> items}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          ...items,
        ],
      ),
    );
  }

  Widget _chatItem({
    required String avatar,
    required String name,
    required String message,
    required String time,
    int unread = 0,
    bool read = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(avatar),
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (read)
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Icon(Icons.done_all, color: Colors.amber, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _communityCard(Map<String, String> community) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
            ),
            child: Image.network(
              community['image']!,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community['name']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    community['highlight']!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _communityPostCard(Map<String, dynamic> post) {
    bool showMore = false;
    String text = post['text'];
    bool longText = text.length > 120;
    return StatefulBuilder(
      builder: (context, setState) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.only(bottom: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(post['avatar']),
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post['name'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              post['handle'],
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '· ${post['time']}',
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.more_horiz, color: Colors.white54, size: 22),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                if (!longText) {
                  return Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showMore ? text : text.substring(0, 120) + '...',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLines: showMore ? 8 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    GestureDetector(
                      onTap: () => setState(() => showMore = !showMore),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          showMore ? 'Show less' : 'Show more',
                          style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (post['image'] != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  post['image'],
                  width: double.infinity,
                  height: 170,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _iconStatRow(Icons.chat_bubble_outline, post['comments'].toString()),
                const SizedBox(width: 18),
                _iconStatRow(Icons.favorite_border, post['likes'].toString()),
                const SizedBox(width: 18),
                _iconStatRow(Icons.share_outlined, post['shares'].toString()),
                const SizedBox(width: 18),
                _iconStatRow(Icons.remove_red_eye_outlined, post['views'].toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconStatRow(IconData icon, String stat) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 3),
        Text(stat, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }

  Widget _groupOrClubCard(Map<String, dynamic> data, {required bool isClub}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(data['avatar']),
            radius: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isClub)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('PAID', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data['desc'],
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('${data['members']} members', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {},
            child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _chatConversationCard(Map<String, dynamic> chat) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF292929),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(chat['avatar']),
              radius: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        chat['time'],
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat['last'],
                          style: TextStyle(
                            color: chat['unread'] > 0 ? Colors.white : Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat['read'])
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.done_all, color: Colors.amber, size: 16),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (chat['unread'] > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${chat['unread']}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 