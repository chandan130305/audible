import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  runApp(const AudibleApp());
}

class AudibleApp extends StatelessWidget {
  const AudibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audible Streamer',
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
  late final AudioPlayer _audioPlayer;
  late final YoutubeExplode _yt;

  bool _isLoading = false;
  String _loadingMessage = 'Searching YouTube...';
  String? _currentTitle;
  String? _currentArtist;
  String? _thumbnailUrl;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _yt = YoutubeExplode();
  }

  Future<void> _playYouTubeAudio(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Searching track...';
    });

    try {
      // 1. Search YouTube
      final searchResult = await _yt.search.search(query);
      if (searchResult.isEmpty) {
        throw Exception('No results found for "$query"');
      }

      final video = searchResult.first;

      setState(() {
        _loadingMessage = 'Buffering audio stream...';
      });

      // 2. Fetch manifest & stream info
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final audioStreams = manifest.audioOnly;
      
      if (audioStreams.isEmpty) {
        throw Exception('No valid audio stream found for this video.');
      }

      final streamInfo = audioStreams.withHighestBitrate();

      // 3. Download stream to local temp file to bypass Windows network block
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_audio.mp3');

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final audioStream = _yt.videos.streamsClient.get(streamInfo);
      final fileStream = tempFile.openWrite();
      await audioStream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      // 4. Load local file into AudioPlayer
      await _audioPlayer.stop();
      await _audioPlayer.setFilePath(tempFile.path);
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
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(_loadingMessage, style: const TextStyle(color: Colors.grey)),
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