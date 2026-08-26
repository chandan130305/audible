import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  runApp(const AudibleApp());
}

class AudibleApp extends StatelessWidget {
  const AudibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audible Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepPurple,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();

  bool _isLoading = false;
  String? _currentTitle;
  String? _currentArtist;
  String? _thumbnailUrl;

  Future<void> _playYouTubeAudio(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Search YouTube for query
      final searchResult = await _yt.search.search(query);
      if (searchResult.isEmpty) {
        throw Exception('No results found');
      }

      final video = searchResult.first;

      // 2. Fetch stream manifest and extract highest bitrate audio URL
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final streamInfo = manifest.audioOnly.withHighestBitrate();

      // 3. Pass direct stream URL to just_audio player
      await _audioPlayer.setUrl(streamInfo.url.toString());
      _audioPlayer.play();

      setState(() {
        _currentTitle = video.title;
        _currentArtist = video.author;
        _thumbnailUrl = video.thumbnails.highResUrl;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playback failed: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _yt.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audible Streamer'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Search song or paste YouTube link...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search, size: 30),
                  onPressed: () => _playYouTubeAudio(_controller.text),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Main Display
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_currentTitle != null) ...[
              if (_thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(_thumbnailUrl!, height: 200, fit: BoxFit.cover),
                ),
              const SizedBox(height: 20),
              Text(
                _currentTitle!,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _currentArtist ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Player Controls
              StreamBuilder<PlayerState>(
                stream: _audioPlayer.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final playing = playerState?.playing ?? false;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 48,
                        icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                        onPressed: () {
                          if (playing) {
                            _audioPlayer.pause();
                          } else {
                            _audioPlayer.play();
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ] else
              const Text('Search for a track to play!'),
          ],
        ),
      ),
    );
  }
}