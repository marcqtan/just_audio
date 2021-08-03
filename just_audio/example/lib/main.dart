import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_example/common.dart';
import 'package:rxdart/rxdart.dart';

void main() => runApp(
      Audio(),
    );

class Audio extends StatefulWidget {
  @override
  _AudioState createState() => _AudioState();
}

class _AudioState extends State<Audio> {
  late AudioPlayer player;
  bool playing = false;

  TextEditingController start = TextEditingController();
  TextEditingController end = TextEditingController();

  @override
  void initState() {
    super.initState();
    final _playlist = ConcatenatingAudioSource(
      children: [
        AudioSource.uri(
          Uri.parse(
            'asset:///assets/audio/A_02_HM2011.mp3',
          ),
        ),
        AudioSource.uri(
          Uri.parse(
            'asset:///assets/audio/1A_04.mp3',
          ),
        ),
      ],
    );
    player = AudioPlayer();
    player.setAudioSource(_playlist);
  }

  @override
  void dispose() {
    super.dispose();
    player.dispose();
  }

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          player.positionStream,
          player.bufferedPositionStream,
          player.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              // crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ControlButtons(player),
                StreamBuilder<PositionData>(
                  stream: _positionDataStream,
                  builder: (context, snapshot) {
                    final positionData = snapshot.data;
                    return SeekBar(
                      duration: positionData?.duration ?? Duration.zero,
                      position: positionData?.position ?? Duration.zero,
                      bufferedPosition:
                          positionData?.bufferedPosition ?? Duration.zero,
                      onChangeEnd: player.seek,
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                        left: 20,
                        top: 20,
                      ),
                      width: 70,
                      child: TextField(
                        controller: start,
                        decoration: InputDecoration(
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              5,
                            ),
                          ),
                          labelText: 'Start',
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(
                        left: 20,
                        top: 20,
                      ),
                      width: 70,
                      child: TextField(
                        controller: end,
                        decoration: InputDecoration(
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              5,
                            ),
                          ),
                          labelText: 'End',
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: () {
                    print(start.text);
                    player.setClip(
                      start: start.text.isEmpty
                          ? null
                          : Duration(seconds: int.parse(start.text)),
                      end: end.text == '0' || end.text.isEmpty
                          ? null
                          : Duration(
                              seconds: int.parse(end.text),
                            ),
                    );
                  },
                  child: Text('Apply AB'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        player.setLoopMode(LoopMode.all);
                      },
                      child: Text('Turn On Loop'),
                    ),
                    SizedBox(
                      width: 5,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        player.setLoopMode(LoopMode.off);
                      },
                      child: Text('Turn Off Loop'),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  ControlButtons(this.player);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            player.seekToPrevious();
          },
          icon: Icon(
            Icons.skip_previous,
          ),
        ),
        IconButton(
          onPressed: () {
            if (player.playing) {
              final currentPos = player.position;
              final nextPosition = currentPos.inMilliseconds - 5000;
              // don't seek less that 0
              final currentPositionCapped = Duration(
                milliseconds: max(0, nextPosition),
              );

              player.seek(currentPositionCapped);
            }
          },
          icon: Icon(Icons.replay_5),
        ),
        // Opens volume slider dialog
        IconButton(
          icon: Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),

        /// This StreamBuilder rebuilds whenever the player state changes, which
        /// includes the playing/paused state and also the
        /// loading/buffering/ready state. Depending on the state we show the
        /// appropriate button or loading indicator.
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return IconButton(
                icon: Icon(Icons.play_arrow),
                iconSize: 64.0,
                onPressed: player.play,
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero),
              );
            }
          },
        ),
        // Opens speed slider dialog
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                value: player.speed,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
        IconButton(
          onPressed: () {
            if (player.playing && player.duration != null) {
              final totalDuration = player.duration!.inMilliseconds;
              final nextPosition = player.position.inMilliseconds + 5000;
              // don't seek more that song duration
              final currentPositionCapped = Duration(
                milliseconds: min(totalDuration, nextPosition),
              );

              player.seek(currentPositionCapped);
            }
          },
          icon: Icon(Icons.forward_5),
        ),
        IconButton(
          onPressed: () {
            player.seekToNext();
          },
          icon: Icon(
            Icons.skip_next,
          ),
        ),
      ],
    );
  }
}
