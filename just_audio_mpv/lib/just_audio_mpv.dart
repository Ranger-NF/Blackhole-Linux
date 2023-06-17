import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_mpv/src/mpv_player.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

enum JAMPV_LogLevel { none, error, warning, info, verbose, debug }

typedef _Logger = FutureOr<void> Function(dynamic message, {dynamic error, StackTrace? stackTrace, JAMPV_LogLevel level});

/// Logger for the just_audio_mpv plugin.
/// This is a global variable that can be set to a function that will be called
/// whenever the plugin logs a message.
// ignore: library_private_types_in_public_api
_Logger mpvLog = (message, {error, stackTrace, level = JAMPV_LogLevel.info}) {
  if (kDebugMode) {
    print(message);
    if (error != null) {
      print(error);
    }
    if (stackTrace != null) {
      print(stackTrace);
    }
  }
};

class JustAudioMpv extends JustAudioPlatform {
  final Map<String, JustAudioMPVPlayer> players = {};

  /// The entrypoint called by the generated plugin registrant.
  static void registerWith() {
    JustAudioPlatform.instance = JustAudioMpv();
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    if (players.containsKey(request.id)) {
      throw PlatformException(
          code: "error",
          message: "Platform player ${request.id} already exists");
    }
    final player = JustAudioMPVPlayer(id: request.id);
    if (!player.isReady) await player.willBeReady;
    players[request.id] = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
      DisposePlayerRequest request) async {
    await players[request.id]?.release();
    players.remove(request.id);
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    for (var player in players.values) {
      await player.release();
    }
    players.clear();
    return DisposeAllPlayersResponse();
  }
}
