import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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

  HttpServer? _localProxyServer;
  StreamSubscription? _proxySubscription;
  
  bool _isLoading = false;
  bool _isPlaying = false;
  String? _currentTitle;
  String? _currentArtist;
  String? _thumbnailUrl;

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

  // Starts a local proxy on localhost to relay YouTube audio bytes to just_audio
  Future<String> _startLocalProxy(String youtubeStreamUrl) async {
    await _stopLocalProxy();

    _localProxyServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = _localProxyServer!.port;

    final client = HttpClient();

    _proxySubscription = _localProxyServer!.listen((HttpRequest req) async {
      try {
        final ytReq = await client.getUrl(Uri.parse(youtubeStreamUrl));
        ytReq.headers.set(
          'User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        );
        ytReq.headers.set('Referer', 'https://www.youtube.com/');

        final ytResponse = await ytReq.close();
        
        req.response.statusCode = ytResponse.statusCode;
        ytResponse.headers.forEach((name, values) {
          for (var value in values) {
            req.response.headers.add(name, value);
          }
        });

        await ytResponse.pipe(req.response);
      } catch (e) {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      }
    });

    return 'http://127.0.0.1:$port/';
  }

  Future<void> _stopLocalProxy() async {
    await _proxySubscription?.cancel();
    _proxySubscription = null;
    await _localProxyServer?.close(force: true);
    _localProxyServer = null;
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

      final audioStream = audioStreams.withHighestBitrate();

      // Route through local proxy
      final proxyUrl = await _startLocalProxy(audioStream.url.toString());

      await _player.stop();
      await _player.setUrl(proxyUrl);
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
    _stopLocalProxy();
    _player.dispose();
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