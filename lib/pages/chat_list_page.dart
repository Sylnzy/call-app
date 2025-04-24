import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Tambahkan import ini
import '../controllers/user_controller.dart';
import '../models/user_model.dart';
import '../config/routes.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _isLoading = false;
  List<UserModel> _contacts = [];
  List<UserModel> _filteredContacts = [];
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  // Map untuk menyimpan jumlah pesan yang belum dibaca untuk setiap chat
  Map<String, int> _unreadCounts = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final userController = Provider.of<UserController>(
        context,
        listen: false,
      );
      final contacts = await userController.getContacts();

      if (mounted) {
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      }

      // Mendapatkan jumlah pesan yang belum dibaca untuk setiap kontak
      _loadUnreadCounts(userController.currentUser?.uid);
    } catch (e) {
      print('Error loading contacts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi untuk mendapatkan jumlah pesan belum dibaca
  Future<void> _loadUnreadCounts(String? currentUserId) async {
    if (currentUserId == null) return;

    for (var contact in _contacts) {
      // Membuat ID chat yang unik (urutan alfabet dari kedua ID)
      final users = [currentUserId, contact.uid];
      users.sort(); // Urutkan secara alfabetis
      final chatId = users.join('_');

      // Mengambil referensi dokumen chat
      final chatDoc =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get();

      if (chatDoc.exists) {
        final data = chatDoc.data();
        // Mendapatkan jumlah pesan yang belum dibaca
        final unreadCount = data?['unreadCount'] as int? ?? 0;

        if (mounted) {
          setState(() {
            _unreadCounts[contact.uid] = unreadCount;
          });
        }
      }
    }
  }

  // Fungsi untuk menandai pesan sebagai dibaca
  Future<void> _markAsRead(String contactId, String currentUserId) async {
    final users = [currentUserId, contactId];
    users.sort();
    final chatId = users.join('_');

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'unreadCount': 0,
    });

    setState(() {
      _unreadCounts[contactId] = 0;
    });
  }

  void _searchContacts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredContacts = _contacts;
      });
      return;
    }

    final queryLower = query.toLowerCase();
    setState(() {
      _filteredContacts =
          _contacts.where((contact) {
            final nameLower = contact.username.toLowerCase();
            final statusLower = contact.status.toLowerCase();
            final emailLower = contact.email.toLowerCase();

            return nameLower.contains(queryLower) ||
                statusLower.contains(queryLower) ||
                emailLower.contains(queryLower);
          }).toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredContacts = _contacts;
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _showAddContactDialog() {
    final searchController = TextEditingController();
    bool isSearching = false;
    String? errorMessage;
    UserModel? foundUser;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Add Contact'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Username or Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Enter username or email',
                      ),
                    ),
                    SizedBox(height: 16),
                    if (isSearching)
                      Center(child: CircularProgressIndicator())
                    else if (errorMessage != null)
                      Text(errorMessage!, style: TextStyle(color: Colors.red))
                    else if (foundUser != null)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              foundUser!.photoURL != null
                                  ? NetworkImage(foundUser!.photoURL!)
                                  : null,
                          child:
                              foundUser!.photoURL == null
                                  ? Text(foundUser!.username[0].toUpperCase())
                                  : null,
                        ),
                        title: Text(foundUser!.username),
                        subtitle: Text(foundUser!.email),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  if (foundUser != null)
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          isSearching = true;
                          errorMessage = null;
                        });

                        try {
                          final userController = Provider.of<UserController>(
                            context,
                            listen: false,
                          );
                          final success = await userController.addContact(
                            foundUser!.uid,
                          );

                          if (success) {
                            Navigator.pop(context);
                            _loadContacts(); // Refresh contacts list
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Contact added successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            setState(() {
                              errorMessage = 'Failed to add contact';
                              isSearching = false;
                            });
                          }
                        } catch (e) {
                          setState(() {
                            errorMessage = 'Error: $e';
                            isSearching = false;
                          });
                        }
                      },
                      child: Text('Add Contact'),
                    )
                  else
                    ElevatedButton(
                      onPressed:
                          isSearching
                              ? null
                              : () async {
                                setState(() {
                                  isSearching = true;
                                  errorMessage = null;
                                  foundUser = null;
                                });

                                try {
                                  final userController =
                                      Provider.of<UserController>(
                                        context,
                                        listen: false,
                                      );
                                  final user = await userController
                                      .findUserByUsernameOrEmail(
                                        searchController.text.trim(),
                                      );

                                  setState(() {
                                    isSearching = false;
                                    if (user != null) {
                                      if (user.uid ==
                                          userController.currentUser?.uid) {
                                        errorMessage =
                                            'You cannot add yourself as a contact';
                                      } else {
                                        foundUser = user;
                                      }
                                    } else {
                                      errorMessage = 'User not found';
                                    }
                                  });
                                } catch (e) {
                                  setState(() {
                                    errorMessage = 'Error: $e';
                                    isSearching = false;
                                  });
                                }
                              },
                      child: Text('Search'),
                    ),
                ],
              );
            },
          ),
    );
  }

  // Helper function untuk menentukan apakah user sedang online
  bool _isUserOnline(DateTime lastSeen) {
    // Jika terakhir online kurang dari 5 menit yang lalu, dianggap online
    return DateTime.now().difference(lastSeen).inMinutes < 5;
  }

  // Helper function untuk format waktu terakhir online
  String _getTimeFormat(DateTime lastSeen) {
    // Format waktu dalam HH:MM (jam:menit)
    return '${lastSeen.hour.toString().padLeft(2, '0')}:${lastSeen.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final userController = Provider.of<UserController>(context);
    final currentUser = userController.currentUser;

    return Scaffold(
      appBar: AppBar(
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: Colors.white),
                  onChanged: _searchContacts,
                  autofocus: true,
                )
                : Text('Chats'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: _isSearching ? 'Cancel search' : 'Search contacts',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _contacts.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No chats yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.person_add),
                      label: Text('Add Contact'),
                      onPressed: _showAddContactDialog,
                    ),
                  ],
                ),
              )
              : _filteredContacts.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No contacts matching "${_searchController.text}"',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.clear),
                      label: Text('Clear Search'),
                      onPressed: () {
                        _searchController.clear();
                        _searchContacts('');
                      },
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = _filteredContacts[index];
                  final unreadCount = _unreadCounts[contact.uid] ?? 0;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          contact.photoURL != null
                              ? NetworkImage(contact.photoURL!)
                              : null,
                      child:
                          contact.photoURL == null
                              ? Text(contact.username[0].toUpperCase())
                              : null,
                    ),
                    title: Text(contact.username),
                    subtitle: Text(
                      contact.status.length > 30
                          ? contact.status.substring(0, 30) + '...'
                          : contact.status,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      // Tandai pesan sebagai sudah dibaca ketika chat dibuka
                      if (currentUser != null && unreadCount > 0) {
                        _markAsRead(contact.uid, currentUser.uid);
                      }

                      // Navigate to chat screen
                      Navigator.pushNamed(
                        context,
                        AppRoutes.chat,
                        arguments: contact,
                      ).then((_) {
                        // Refresh unread counts when returning from chat
                        if (currentUser != null) {
                          _loadUnreadCounts(currentUser.uid);
                        }
                      });
                    },
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _getTimeFormat(contact.lastSeen),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isUserOnline(contact.lastSeen)
                                ? Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Online',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                )
                                : Text(
                                  'Last seen',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                ),
                            if (unreadCount > 0) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        child: Icon(Icons.person_add),
        tooltip: 'Add Contact',
      ),
    );
  }
}
