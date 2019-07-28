import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

enum PlayerState { stopped, playing, paused }

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
          primarySwatch: Colors.deepOrange,
          primaryColorBrightness: Brightness.dark),
      home: MyHomePage(title: 'Flutter Player Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String url;
  int _currentIndex = -1;
  bool isLocal = true;
  Map<String, String> playlist = Map();

  AudioPlayer _audioPlayer;
  AudioPlayerState _audioPlayerState;
  Duration _duration;
  Duration _position;

  PlayerState _playerState = PlayerState.stopped;
  StreamSubscription _durationSubscription;
  StreamSubscription _positionSubscription;
  StreamSubscription _playerCompleteSubscription;
  StreamSubscription _playerErrorSubscription;
  StreamSubscription _playerStateSubscription;

  get _isPlaying => _playerState == PlayerState.playing;

  get _isPaused => _playerState == PlayerState.paused;

  get _durationText =>
      _duration?.toString()?.split('.')?.first?.replaceFirst('0:', '') ??
      '00:00';

  get _positionText =>
      _position?.toString()?.split('.')?.first?.replaceFirst('0:', '') ??
      '00:00';

  get sliderValue => (_position != null &&
          _duration != null &&
          _position.inMilliseconds > 0 &&
          _position.inMilliseconds < _duration.inMilliseconds)
      ? _position.inMilliseconds / _duration.inMilliseconds
      : 0.0;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerErrorSubscription?.cancel();
    _playerStateSubscription?.cancel();
    super.dispose();
  }

  String filePath;

  Future<void> pickAudio() async {
    playlist = await FilePicker.getMultiFilePath(type: FileType.AUDIO);
    if (playlist != null && playlist.isNotEmpty) {
      _playNext();
    }
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);

    _durationSubscription =
        _audioPlayer.onDurationChanged.listen((duration) => setState(() {
              _duration = duration;
            }));

    _positionSubscription =
        _audioPlayer.onAudioPositionChanged.listen((p) => setState(() {
              _position = p;
            }));

    _playerCompleteSubscription =
        _audioPlayer.onPlayerCompletion.listen((event) {
      _playNext();
    });

    _playerErrorSubscription = _audioPlayer.onPlayerError.listen((msg) {
      print('audioPlayer error : $msg');
      setState(() {
        _playerState = PlayerState.stopped;
        _duration = Duration(seconds: 0);
        _position = Duration(seconds: 0);
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _audioPlayerState = state;
      });
    });
  }

  Future<int> _playNext() async {
    if (_currentIndex < playlist.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }
    url = playlist.values.elementAt(_currentIndex);
    return await _play(resume: false);
  }

  Future<int> _playPrevious() async {
    if (_currentIndex > 0) _currentIndex--;
    url = playlist.values.elementAt(_currentIndex);
    return await _play(resume: false);
  }

  Future<int> _play({bool resume = true}) async {
    final playPosition = resume
        ? (_position != null &&
                _duration != null &&
                _position.inMilliseconds > 0 &&
                _position.inMilliseconds < _duration.inMilliseconds)
            ? _position
            : null
        : null;
    final result =
        await _audioPlayer.play(url, isLocal: isLocal, position: playPosition);
    if (result == 1) setState(() => _playerState = PlayerState.playing);
    return result;
  }

  Future<int> _pause() async {
    final result = await _audioPlayer.pause();
    if (result == 1) setState(() => _playerState = PlayerState.paused);
    return result;
  }

  Future<int> _stop() async {
    final result = await _audioPlayer.stop();
    if (result == 1) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration();
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(icon: Icon(Icons.folder_open), onPressed: pickAudio)
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: Colors.blueGrey[50], width: 5.0))),
            height: 480.0,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(playlist.keys.elementAt(index)),
                  onTap: () {
                    url = playlist.values.elementAt(index);
                    _play(resume: false);
                  },
                  selected: url == playlist.values.elementAt(index),
                  trailing: Text(''),
                );
              },
              separatorBuilder: (context, index) {
                return Divider(
                    height: 4.0,
                    color: Colors.orange,
                    indent: 3.0,
                    endIndent: 3.0);
              },
              itemCount: playlist.length,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              IconButton(
                  iconSize: 35.0,
                  icon: Icon(Icons.skip_previous),
                  onPressed:
                      playlist.length > 0 ? () => _playPrevious() : null),
              IconButton(
                  iconSize: 35.0,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: url != null
                      ? () => _isPlaying ? _pause() : _play()
                      : null),
              IconButton(
                  iconSize: 35.0,
                  icon: Icon(Icons.skip_next),
                  onPressed: playlist.length > 0 ? () => _playNext() : null)
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: <Widget>[
                Text('$_positionText'),
                Expanded(
                  child: SliderTheme(
                    data: Theme.of(context).sliderTheme.copyWith(
                          trackHeight: 2.0,
                          thumbShape:
                              RoundSliderThumbShape(enabledThumbRadius: 5.0),
                        ),
                    child: Slider(
                      value: sliderValue,
                      onChanged: (value) async => _isPlaying
                          ? await _audioPlayer.seek(Duration(
                              milliseconds: (value * _duration.inMilliseconds)
                                  .truncate()))
                          : null,
                    ),
                  ),
                ),
                Text('$_durationText'),
              ],
            ),
          )
        ],
      ),
    );
  }
}
