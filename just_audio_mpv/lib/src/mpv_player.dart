import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:mpv_dart/mpv_dart.dart';

import '../just_audio_mpv.dart';

/// Shorthand for processing states.
typedef _State = ProcessingStateMessage;

class JustAudioMPVPlayer extends AudioPlayerPlatform {
  late final MPVPlayer mpv;
  late final Future<void> willBeReady;
  bool isReady = false;
  //bool idle = false;
  _State _state = ProcessingStateMessage.loading;
  final _eventController = StreamController<PlaybackEventMessage>.broadcast();
  @override
  get playbackEventMessageStream => _eventController.stream;
  final _dataController = StreamController<PlayerDataMessage>.broadcast();
  @override
  get playerDataMessageStream => _dataController.stream;

  Future<void> update(
      {Duration? updatePosition,
      Duration? bufferedPosition,
      Duration? duration,
      IcyMetadataMessage? icyMetadata,
      int? currentIndex}) async {
    if (_eventController.isClosed == false) {
      // ignore: no_leading_underscores_for_local_identifiers
      final _duration = Duration(
          milliseconds: (await mpv.getDuration().catchError((_) => 0.0) * 1000)
              .truncate());
      _eventController.add(PlaybackEventMessage(
          processingState: _state,
          updateTime: DateTime.now(),
          updatePosition: Duration(
              milliseconds: (updatePosition?.inMilliseconds ??
                      await mpv.getTimePosition().catchError((_) => 0.0) * 1000)
                  .clamp(0, (duration ?? _duration).inMilliseconds)
                  .truncate()),
          bufferedPosition: bufferedPosition ?? _duration,
          duration: duration ?? _duration,
          icyMetadata: icyMetadata,
          currentIndex: currentIndex ??
              await mpv
                  .getPlaylistPosition()
                  .catchError((_) => 0)
                  .then((value) => value < 0 ? 0 : value),
          androidAudioSessionId: null));
    }
  }

  void _setState(_State state) => _state = state;

  JustAudioMPVPlayer({required String id}) : super(id) {
    final completer = Completer();
    willBeReady = completer.future;
    mpv = MPVPlayer(
        audioOnly: true,
        timeUpdate: 1,
        socketURI: Platform.isWindows
            ? '\\\\.\\pipe\\mpvserver-$id'
            : '/tmp/MPV_Dart-$id.sock',
        mpvArgs: ["audio-buffer=1", "idle=yes"]);
    mpv.stop();
    mpv.on("idle", null, (ev, _) async {
      _setState(_State.idle);
    });
    // unawaited(mpv.start(mpv_args: mpv.mpvArgs).then((_) {
    mpv.on(MPVEvents.status, null, (ev, _) async {
      await update();
    });
    mpv.on(MPVEvents.paused, null, (ev, _) async {
      _dataController.add(PlayerDataMessage(playing: false));
    });
    mpv.start().then(((value) {
      if (!completer.isCompleted) completer.complete();
      isReady = true;
      mpvLog("MPV $id started", level: JAMPV_LogLevel.info);
      _setState(_State.ready);
      update();
    }));
    mpv.on(MPVEvents.resumed, null, (ev, _) async {
      _dataController.add(PlayerDataMessage(playing: true));
      _setState(_State.ready);
      update();
    });
    mpv.on(MPVEvents.started, null, (ev, _) async {
      _dataController.add(PlayerDataMessage(playing: true));
      _setState(_State.ready);
      update();
    });
    mpv.on(MPVEvents.seek, null, (ev, _) async {
      _setState(_State.ready);
      update();
    });
    mpv.on(MPVEvents.quit, null, (ev, _) async {
      _setState(_State.idle);
      update();
      mpvLog("MPV $id exited", level: JAMPV_LogLevel.warning);
    });
    mpv.on(MPVEvents.timeposition, null, (ev, _) async {
      final _duration = await mpv.getDuration().catchError((_, __) => -1);
      final _bufferedTo =
          await mpv.getProperty("demuxer-cache-time").catchError((_, __) => -1);
      await update(
          updatePosition: Duration(
              milliseconds: ((ev.eventData as double) * 1000).truncate()),
          bufferedPosition: (_bufferedTo ?? -1) < 0
              ? null
              : Duration(milliseconds: (_bufferedTo * 1000).truncate()),
          duration: _duration < 0
              ? null
              : Duration(milliseconds: (_duration * 1000).truncate()));
    });
  }

  release() async {
    mpvLog("MPV $id quitting at request", level: JAMPV_LogLevel.info);
    if (await mpv.isRunning()) {
      await _eventController.close();
      await _dataController.close();
      //await mpv.socket.quit();
      try {
        await mpv.stop();
      } finally {}
      try {
        await mpv.quit();
      } finally {}
    }
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    mpvLog("MPV $id loading track...",
        level: JAMPV_LogLevel.verbose,
        error: request.audioSourceMessage.toMap());
    _setState(_State.loading);
    update();
    await mpv.clearPlaylist();
    if (request.audioSourceMessage is ClippingAudioSourceMessage) {
      await mpv.load(
          (request.audioSourceMessage as ClippingAudioSourceMessage).child.uri,
          options: [
            if ((request.audioSourceMessage as ClippingAudioSourceMessage)
                    .start !=
                null)
              "start=.${(request.audioSourceMessage as ClippingAudioSourceMessage).start!.inMilliseconds}",
            if ((request.audioSourceMessage as ClippingAudioSourceMessage)
                    .end !=
                null)
              "end=.${(request.audioSourceMessage as ClippingAudioSourceMessage).end!.inMilliseconds}",
          ]);
    } else if (request.audioSourceMessage is UriAudioSourceMessage) {
      await mpv.load((request.audioSourceMessage as UriAudioSourceMessage).uri);
    } else if (request.audioSourceMessage is ConcatenatingAudioSourceMessage) {
      for (final message
          in (request.audioSourceMessage as ConcatenatingAudioSourceMessage)
              .children) {
        await _concatenatingInsert(message);
      }
      //if (request.initialIndex != null) await mpv.setProperty("playlist-start", request.initialIndex);
      //if (request.initialIndex != null) await mpv.setProperty("playlist-pos", request.initialIndex);
      if (request.initialIndex != null)
        await mpv
            .command("playlist-play-index", [request.initialIndex!.toString()]);
    } else if (request.audioSourceMessage is SilenceAudioSourceMessage) {
      await mpv.load(
          "av://lavfi:anullsrc=d=${(request.audioSourceMessage as SilenceAudioSourceMessage).duration.inMilliseconds}ms",
          mode: LoadMode.append);
    } else {
      _setState(_State.idle);
      update();
      throw UnsupportedError(
          "${request.audioSourceMessage.runtimeType.toString()} is not supported");
    }
    //await update();
    _setState(_State.ready);
    mpvLog("MPV $id loaded track", level: JAMPV_LogLevel.verbose);
    return LoadResponse(duration: const Duration(days: 365));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    await mpv.play();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    await mpv.pause();
    return PauseResponse();
  }

  // Future<void> next(dynamic request) async {
  //   await mpv.next();
  // }
  // Future<void> previous(dynamic request) async {
  //   await mpv.prev();
  // }
  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    _setState(_State.buffering);
    if (request.index != null)
      await mpv.command("playlist-play-index", [request.index!.toString()]);
    if (request.index == null && request.position != null)
      await mpv.seek(request.position!.inMilliseconds / 1000,
          mode: SeekMode.absolute);
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    if (request.volume > 1.3) return SetVolumeResponse();
    await mpv.volume(request.volume * 100);
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    await mpv.speed(request.speed);
    return SetSpeedResponse();
  }
  // @override
  // Future<SetPitchResponse> setPitch(SetPitchRequest request) async {
  //   await mpv.s(request.pitch * 100);
  //   return SetPitchResponse();
  // }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    if (request.loopMode == LoopModeMessage.all) {
      await mpv.loop('no');
      await mpv.loopPlaylist('inf');
    } else if (request.loopMode == LoopModeMessage.one) {
      await mpv.loop('inf');
      await mpv.loopPlaylist('no');
    } else {
      await mpv.loop('no');
      await mpv.loopPlaylist('no');
    }
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
      SetShuffleModeRequest request) async {
    if (request.shuffleMode == ShuffleModeMessage.all) {
      await mpv.shuffle();
    } else {
      await mpv.unshuffle();
    }
    return SetShuffleModeResponse();
  }

  Future<void> _concatenatingInsert(AudioSourceMessage message) async {
    if (message is ClippingAudioSourceMessage) {
      await mpv.load(message.child.uri,
          options: [
            if (message.start != null)
              "start=.${message.start!.inMilliseconds}",
            if (message.end != null) "end=.${message.end!.inMilliseconds}",
          ],
          mode: LoadMode.append);
    } else if (message is UriAudioSourceMessage) {
      await mpv.load(message.uri, mode: LoadMode.append);
    } else if (message is ConcatenatingAudioSourceMessage) {
      throw UnsupportedError(
          "nested ${message.runtimeType.toString()} is not supported");
    } else if (message is SilenceAudioSourceMessage) {
      await mpv.load(
          "av://lavfi:anullsrc=d=${message.duration.inMilliseconds}ms",
          mode: LoadMode.append);
    } else {
      throw UnsupportedError(
          "${message.runtimeType.toString()} is not supported");
    }
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
      ConcatenatingInsertAllRequest request) async {
    //final length = await mpv.getPlaylistSize();
    //mpvLog("D: ConcatenatingInsertAll", error: {"request.index": request.index, "length": length}, level: JAMPV_LogLevel.verbose);
    for (final source in request.children.reversed) {
      await _concatenatingInsert(source);
      final length = await mpv.getPlaylistSize();
      if (length == 0) continue;
      if (request.index < (length - 1) && request.index >= 0) {
        await mpv.playlistMove(length - 1, request.index);
      } else if (request.index == length) {
        //await mpv.playlistMove(length-1, length-2);
      }
    }
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
      ConcatenatingRemoveRangeRequest request) async {
    for (var i = 0; i < request.endIndex - request.startIndex; i++) {
      await mpv.playlistRemove(request.startIndex + i);
    }
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
      ConcatenatingMoveRequest request) async {
    await mpv.playlistMove(request.currentIndex, request.newIndex);
    return ConcatenatingMoveResponse();
  }
}
