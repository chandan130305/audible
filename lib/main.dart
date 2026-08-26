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
  late YoutubeExplode _yt;

  bool _isLoading = false;
  String? _currentTitle;
  String? _currentArtist;
  String? _thumbnailUrl;

  @override
  void initState() {
    super.initState();
    _yt = YoutubeExplode();
  }

  Future<void> _playYouTubeAudio(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Search YouTube with a 10-second timeout safeguard
      final searchResult = await _yt.search.search(query).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Search timed out. Check connection.'),
      );

      if (searchResult.isEmpty) {
        throw Exception('No results found for "$query"');
      }

      final video = searchResult.first;

      // 2. Fetch manifest & extract audio-only stream
      final manifest = await _yt.videos.streamsClient.getManifest(video.id).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Stream fetch timed out.'),
      );
      
      final streamInfo = manifest.audioOnly.withHighestBitrate();

      // 3. Reset audio player state before assigning new stream
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(streamInfo.url.toString()).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Audio initialization timed out.'),
      );
      
      _audioPlayer.play();

      setState(() {
        _currentTitle = video.title;
        _currentArtist = video.author;
        _thumbnailUrl = video.thumbnails.highResUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playback failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (value) => _playYouTubeAudio(value),
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
            if (_isLoading)
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Resolving stream from YouTube...', style: TextStyle(color: Colors.grey)),
                ],
              )
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