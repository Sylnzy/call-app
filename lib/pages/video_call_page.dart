import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/helpers.dart';

class VideoCallPage extends StatefulWidget {
  const VideoCallPage({Key? key}) : super(key: key);

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isCallConnected = true;
  Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  String _duration = '00:00';

  @override
  void initState() {
    super.initState();
    _startCallTimer();
  }

  void _startCallTimer() {
    _stopwatch.start();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration = Helpers.formatDuration(_stopwatch.elapsed);
        });
      }
    });
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen background - would be video stream in a real app
          Container(color: Color(0xFF2C3E50)),

          // Self-view (picture-in-picture)
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              height: 180,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  _isCameraOff
                      ? Center(
                        child: Icon(
                          Icons.videocam_off,
                          size: 40,
                          color: Colors.white60,
                        ),
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(color: Color(0xFF34495E)),
                      ),
            ),
          ),

          // Call info overlay
          Positioned(
            top: 40,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jane Doe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _duration,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),

          // Call controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  onPressed: () {
                    setState(() {
                      _isMuted = !_isMuted;
                    });
                  },
                  backgroundColor: _isMuted ? Colors.red : Colors.white24,
                ),
                _buildCallButton(
                  icon: Icons.call_end,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  backgroundColor: Colors.red,
                  size: 70,
                ),
                _buildCallButton(
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  onPressed: () {
                    setState(() {
                      _isCameraOff = !_isCameraOff;
                    });
                  },
                  backgroundColor: _isCameraOff ? Colors.red : Colors.white24,
                ),
                _buildCallButton(
                  icon: Icons.switch_camera,
                  onPressed: () {
                    // Switch camera logic
                  },
                  backgroundColor: Colors.white24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 56,
  }) {
    return RawMaterialButton(
      onPressed: onPressed,
      elevation: 2.0,
      fillColor: backgroundColor,
      padding: EdgeInsets.all(size / 4),
      shape: CircleBorder(),
      child: Icon(icon, color: Colors.white, size: size / 2),
      constraints: BoxConstraints.tightFor(width: size, height: size),
    );
  }
}
