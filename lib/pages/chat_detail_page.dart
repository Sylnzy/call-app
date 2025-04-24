import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/user_controller.dart';
import '../models/user_model.dart';
import 'profile_view_page.dart';

// Define enum at top level, not inside the class
enum MessageType { text, image, document, audio, video }

class ChatDetailPage extends StatefulWidget {
  final UserModel contact;

  const ChatDetailPage({Key? key, required this.contact}) : super(key: key);

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAttachmentMenuVisible = false;

  @override
  void initState() {
    super.initState();
    // Reset counter pesan yang belum dibaca saat buka halaman chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  Future<void> _markMessagesAsRead() async {
    final userController = Provider.of<UserController>(context, listen: false);
    final currentUser = userController.currentUser;

    if (currentUser == null) return;

    // Membuat ID chat unik
    final users = [currentUser.uid, widget.contact.uid];
    users.sort();
    final chatId = users.join('_');

    // Update status unreadCount menjadi 0 karena semua pesan sudah dibaca
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'unreadCount': 0,
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Method untuk menampilkan menu attachment
  void _showAttachmentMenu() {
    setState(() {
      _isAttachmentMenuVisible = !_isAttachmentMenuVisible;
    });
  }

  // Ambil gambar dari galeri
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isAttachmentMenuVisible = false;
        });

        // Upload dan kirim gambar
        await _uploadAndSendFile(File(image.path), MessageType.image);
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
      _showErrorSnackbar('Gagal memilih gambar: ${e.toString()}');
    }
  }

  // Ambil gambar dari kamera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isAttachmentMenuVisible = false;
        });

        // Upload dan kirim gambar
        await _uploadAndSendFile(File(image.path), MessageType.image);
      }
    } catch (e) {
      print('Error picking image from camera: $e');
      _showErrorSnackbar('Gagal mengambil foto: ${e.toString()}');
    }
  }

  // Pilih file dokumen (PDF, DOC, etc)
  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isAttachmentMenuVisible = false;
        });

        // Upload and send document
        await _uploadAndSendFile(
          File(result.files.single.path!),
          MessageType.document,
        );
      }
    } catch (e) {
      print('Error picking document: $e');
      _showErrorSnackbar('Gagal memilih dokumen: ${e.toString()}');
    }
  }

  // Pilih file video
  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30), // Limit video to 30 seconds
      );

      if (video != null) {
        setState(() {
          _isAttachmentMenuVisible = false;
        });

        // Upload and send video
        await _uploadAndSendFile(File(video.path), MessageType.video);
      }
    } catch (e) {
      print('Error picking video: $e');
      _showErrorSnackbar('Gagal memilih video: ${e.toString()}');
    }
  }

  // Pilih file audio
  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isAttachmentMenuVisible = false;
        });

        // Upload and send audio
        await _uploadAndSendFile(
          File(result.files.single.path!),
          MessageType.audio,
        );
      }
    } catch (e) {
      print('Error picking audio: $e');
      _showErrorSnackbar('Gagal memilih audio: ${e.toString()}');
    }
  }

  // Metode untuk upload file ke Firebase Storage dan mengirimkannya sebagai pesan
  Future<void> _uploadAndSendFile(File file, MessageType type) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final userController = Provider.of<UserController>(context, listen: false);
    final currentUser = userController.currentUser;

    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User tidak ditemukan';
      });
      return;
    }

    try {
      // Mendapatkan chat ID
      final users = [currentUser.uid, widget.contact.uid];
      users.sort();
      final chatId = users.join('_');

      // Membuat nama file yang unik dengan timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${path.basename(file.path)}';

      // Folder path berdasarkan jenis file
      String folderPath = '';
      switch (type) {
        case MessageType.image:
          folderPath = 'chat_images';
          break;
        case MessageType.document:
          folderPath = 'chat_documents';
          break;
        case MessageType.audio:
          folderPath = 'chat_audio';
          break;
        case MessageType.video:
          folderPath = 'chat_videos';
          break;
        default:
          folderPath = 'chat_files';
      }

      // Ref ke Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'chats/$chatId/$folderPath/$fileName',
      );

      // Upload file
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});

      // Mendapatkan download URL
      final fileUrl = await snapshot.ref.getDownloadURL();

      // Persiapan data pesan
      final messageData = {
        'senderId': currentUser.uid,
        'receiverId': widget.contact.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type.toString().split('.').last, // Konversi enum ke string
        'fileUrl': fileUrl,
        'fileName': path.basename(file.path),
        'fileSize': await file.length(), // Ukuran file
      };

      // Tambahkan teks jika ada teks pesan
      if (type == MessageType.text &&
          _messageController.text.trim().isNotEmpty) {
        messageData['text'] = _messageController.text.trim();
      }

      // Tambahkan pesan ke Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update metadata chat dengan pesan terakhir
      String lastMessageText = '';
      switch (type) {
        case MessageType.image:
          lastMessageText = '📷 Photo';
          break;
        case MessageType.document:
          lastMessageText = '📄 Document';
          break;
        case MessageType.audio:
          lastMessageText = '🎵 Audio';
          break;
        case MessageType.video:
          lastMessageText = '🎬 Video';
          break;
        default:
          lastMessageText = '📎 File';
      }

      // Update chat metadata
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'lastMessage': lastMessageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [currentUser.uid, widget.contact.uid],
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Scroll ke bawah untuk melihat pesan baru
      _scrollToBottom();
    } catch (e) {
      print('Error uploading and sending file: $e');
      setState(() {
        _errorMessage = 'Gagal mengirim file: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userController = Provider.of<UserController>(context, listen: false);
    final currentUser = userController.currentUser;

    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create a unique chat ID (combine both user IDs in alphabetical order)
      final users = [currentUser.uid, widget.contact.uid];
      users.sort(); // Sort alphabetically
      final chatId = users.join('_');

      // Add message to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'senderId': currentUser.uid,
            'receiverId': widget.contact.uid,
            'text': _messageController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'text', // Text message type
          });

      // Update chat metadata
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'lastMessage': _messageController.text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [currentUser.uid, widget.contact.uid],
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Clear message input
      _messageController.clear();

      // Scroll to bottom of chat
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _errorMessage = 'Failed to send message: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openProfileView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileViewPage(user: widget.contact),
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> data, bool isMe) {
    final messageType = data['type'] ?? 'text';
    switch (messageType) {
      case 'image':
        return CachedNetworkImage(
          imageUrl: data['fileUrl'],
          placeholder: (context, url) => CircularProgressIndicator(),
          errorWidget: (context, url, error) => Icon(Icons.error),
        );
      case 'document':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.insert_drive_file, size: 40),
            SizedBox(height: 8),
            Text(data['fileName'] ?? 'Document'),
          ],
        );
      case 'audio':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.audiotrack, size: 40),
            SizedBox(height: 8),
            Text(data['fileName'] ?? 'Audio'),
          ],
        );
      case 'video':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.videocam, size: 40),
            SizedBox(height: 8),
            Text(data['fileName'] ?? 'Video'),
          ],
        );
      default:
        return Text(
          data['text'] ?? '',
          style: TextStyle(color: isMe ? Colors.white : null),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userController = Provider.of<UserController>(context);
    final currentUser = userController.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Chat')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Create a unique chat ID (combine both user IDs in alphabetical order)
    final users = [currentUser.uid, widget.contact.uid];
    users.sort(); // Sort alphabetically
    final chatId = users.join('_');

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 30, // Mengurangi ruang untuk tombol back
        title: GestureDetector(
          onTap: _openProfileView,
          child: Row(
            mainAxisSize: MainAxisSize.min, // Penting! Membatasi lebar Row
            children: [
              CircleAvatar(
                radius: 16, // Ukuran lebih kecil
                backgroundImage:
                    widget.contact.photoURL != null
                        ? NetworkImage(widget.contact.photoURL!)
                        : null,
                child:
                    widget.contact.photoURL == null
                        ? Text(
                          widget.contact.username[0].toUpperCase(),
                          style: TextStyle(fontSize: 12), // Font lebih kecil
                        )
                        : null,
              ),
              SizedBox(width: 8),
              Flexible(
                // Flexible memastikan anak tidak melebihi ruang tersedia
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contact.username,
                      style: TextStyle(fontSize: 20), // Font lebih kecil
                      overflow: TextOverflow.ellipsis, // Tambahkan ellipsis
                    ),
                    Text(
                      widget.contact.status.length > 15
                          ? widget.contact.status.substring(0, 15) + '...'
                          : widget.contact.status,
                      style: TextStyle(
                        fontSize: 14, // Font lebih kecil
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Tombol panggilan dengan ukuran yang lebih kecil
          IconButton(
            icon: Icon(Icons.call, size: 22),
            constraints: BoxConstraints(maxWidth: 40),
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.pushNamed(context, '/call', arguments: widget.contact);
            },
          ),
          // Tombol video call dengan ukuran yang lebih kecil
          IconButton(
            icon: Icon(Icons.videocam, size: 22),
            constraints: BoxConstraints(maxWidth: 40),
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/video-call',
                arguments: widget.contact,
              );
            },
          ),
          // Profile view button at the rightmost position
          IconButton(
            icon: Icon(Icons.more_vert_rounded, size: 22),
            constraints: BoxConstraints(maxWidth: 40),
            padding: EdgeInsets.zero,
            onPressed: _openProfileView,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              color: Colors.red.withOpacity(0.1),
              child: Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
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
                          'No messages yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Say hi to start a conversation!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Scroll to bottom when new messages are loaded
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final data = message.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUser.uid;
                    final timestampData = data['timestamp'] as Timestamp?;
                    final time =
                        timestampData != null
                            ? timestampData.toDate()
                            : DateTime.now();
                    final messageType = data['type'] ?? 'text';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment:
                            isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  widget.contact.photoURL != null
                                      ? NetworkImage(widget.contact.photoURL!)
                                      : null,
                              child:
                                  widget.contact.photoURL == null
                                      ? Text(
                                        widget.contact.username[0]
                                            .toUpperCase(),
                                        style: TextStyle(fontSize: 12),
                                      )
                                      : null,
                            ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    isMe
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                          context,
                                        ).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Render message content based on type
                                  _buildMessageContent(data, isMe),

                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment:
                                        isMe
                                            ? MainAxisAlignment.end
                                            : MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              isMe
                                                  ? Colors.white.withOpacity(
                                                    0.7,
                                                  )
                                                  : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                if (_isAttachmentMenuVisible)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.photo),
                        onPressed: _pickImageFromGallery,
                      ),
                      IconButton(
                        icon: Icon(Icons.camera_alt),
                        onPressed: _pickImageFromCamera,
                      ),
                      IconButton(
                        icon: Icon(Icons.insert_drive_file),
                        onPressed: _pickDocument,
                      ),
                      IconButton(
                        icon: Icon(Icons.audiotrack),
                        onPressed: _pickAudio,
                      ),
                      IconButton(
                        icon: Icon(Icons.videocam),
                        onPressed: _pickVideo,
                      ),
                    ],
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file),
                      onPressed: _showAttachmentMenu,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon:
                          _isLoading
                              ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(Icons.send),
                      onPressed: _isLoading ? null : _sendMessage,
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
}
