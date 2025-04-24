import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';

class ProfileViewPage extends StatelessWidget {
  final UserModel user;

  const ProfileViewPage({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),

            // Profile picture
            Center(
              child: CircleAvatar(
                radius: 70,
                backgroundImage:
                    user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child:
                    user.photoURL == null
                        ? Text(
                          user.username[0].toUpperCase(),
                          style: const TextStyle(fontSize: 50),
                        )
                        : null,
              ),
            ),

            const SizedBox(height: 16),

            // Username
            Text(
              user.username,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            // Email
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  user.email,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Info cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status section
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(user.status, style: const TextStyle(fontSize: 16)),

                      const Divider(height: 32),

                      // Last seen
                      const Text(
                        'Last seen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(user.lastSeen),
                        style: const TextStyle(fontSize: 16),
                      ),

                      const Divider(height: 32),

                      // Member since
                      const Text(
                        'Member since',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM yyyy').format(user.createdAt),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat),
                      label: const Text('Message'),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                      onPressed: () {
                        Navigator.pushNamed(context, '/call', arguments: user);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text('Video Call'),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/video-call',
                      arguments: user,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
