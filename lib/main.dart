import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  late final AudioPlayer _player;
  late final YoutubeExplode _yt;

  bool _isLoading = false;
  bool _isPlaying = false;
  String? _currentTitle;
  String? _currentArtist;
  String? _thumbnailUrl;
  File? _tempAudioFile;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _yt = YoutubeExplode();

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });
  }

  Future<void> _playYouTubeAudio(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final searchResult = await _yt.search.search(query);
      if (searchResult.isEmpty) {
        throw Exception('No results found.');
      }

      final video = searchResult.first;
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) {
        throw Exception('No valid audio stream found.');
      }

      final audioStreamInfo = audioStreams.withHighestBitrate();

      // Clean up previous temporary file if present
      if (_tempAudioFile != null && await _tempAudioFile!.exists()) {
        try {
          await _tempAudioFile!.delete();
        } catch (_) {}
      }

      // Download stream chunks into a local temp file
      final tempDir = await getTemporaryDirectory();
      _tempAudioFile = File('${tempDir.path}/temp_track.m4a');

      final audioStream = _yt.videos.streamsClient.get(audioStreamInfo);
      final fileStream = _tempAudioFile!.openWrite();

      await audioStream.pipe(fileStream);
      await fileStream.close();

      // Load into audio engine via file path
      await _player.stop();
      await _player.setFilePath(_tempAudioFile!.path);
      _player.play();

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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _yt.close();
    _controller.dispose();
    if (_tempAudioFile != null && _tempAudioFile!.existsSync()) {
      _tempAudioFile!.deleteSync();
    }
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
                    onSubmitted: _playYouTubeAudio,
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
              const SizedBox(height: 4),
              Text(
                _currentArtist ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              IconButton(
                iconSize: 56,
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                onPressed: () {
                  if (_isPlaying) {
                    _player.pause();
                  } else {
                    _player.play();
                  }
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