# `just_audio` with MPV
This platform interface allows you to use `just_audio` on Linux with the user's installed MPV.

This uses `mpv_dart`, which uses a local socket to communicate with mpv over JSON IPC. mpv takes care of all the file loading, shuffling, looping, pretty much everything.

## Installation
**Users** with software that uses `just_audio_mpv` have to install `mpv`. A recent version is *highly recommended*. The `mpv` binary must be present in the PATH. One of the following commands should do this for you:

For Debian and Ubuntu, add [this](https://non-gnu.uvt.nl/) repository and run:
```
sudo apt update
sudo apt install mpv
```

For Arch, get `https://aur.archlinux.org/packages/mpv-git/` via AUR and install it. This can be done with something like:
```
yay -S mpv-git
```

For Fedora:
```
sudo yum install mpv
```

If your app is to be packaged as a Flatpak, you can add `io.mpv.Mpv` as a dependency (don't ask me how, I've never built for it) or bundle a custom build.

For other distributions, you might want to look into https://mpv.io/installation/.

Currently it is not possible to tell `just_audio_mpv` to use an asset-bundled `mpv`.

## Checking for MPV
To check whether MPV is installed, first check if it's going to be used (with `if (Platform.isLinux)`), then check the exit code of the command `which mpv`. If it returns `0`, MPV is present and you can continue. If it returns `1`, MPV is not present. Any other error codes are likely indicative of the `which` command not being present-- good luck getting a Flutter app to run on a machine that doesn't have basic tools like `which`.

```dart
// In a synchronous environment, optimally before the runApp(MyApp()) call and/or with a
// splash/loading screen available:
// (Note: asynchronous is preferred where possible, but `which` is an instant command
// so running it synchronously should not hurt performance.)
if (Platform.isLinux && Process.runSync("which", ["mpv"]).exitCode != 0) {
  // Tell the user somehow that MPV is not installed,
  // point them to this page, and prevent them from
  // trying to play audio.
}
// If you're running in an environment where audio support is considered absent by default,
// you can check for MPV's presence asynchronously like this:
final which = Process.run("which", ["mpv"]);
if (which.exitCode == 0) {
  canPlayAudio = true;
}
```

For Windows the command would be `Get-Command` for PowerShell and `where` for CMD.

## Logging
If you want centralized, controlled, or pretty logging, you can use the below example to tell `just_audio_mpv` to log to wherever you want instead. It logs to console by default, so for most debugging purposes nothing needs to be done.

**Please note:** the `dynamic error` parameter may include non-error information that may be useful in debugging, such as what track it is attempting to load. It is typically null.

```dart
// Map your various log levels to MPV's:
const _logLevelMap = {
  JAMPV_LogLevel.debug: LogLevel.debug,
  JAMPV_LogLevel.info: LogLevel.info,
  JAMPV_LogLevel.warning: LogLevel.warning,
  JAMPV_LogLevel.error: LogLevel.error,
  JAMPV_LogLevel.verbose: LogLevel.verbose,
  JAMPV_LogLevel.none: LogLevel.debug,
};
mpvLog = (dynamic message, {dynamic error, JAMPV_LogLevel level = JAMPV_LogLevel.debug, StackTrace stackTrace}) {
  // Run your logging function of choice here.
  // For example, if using Pinelogger:
  justAudioMpvPinelogger.log(message, severity: _logLevelMap[level]!, error: error, stackTrace: stackTrace);
};
```

## Features

| Feature                        |  Linux |
| ------------------------------ |  :---: |
| read from URL                  |   ✅   |
| read from file                 |   ✅   |
| read from asset                |   ✅   |
| read from byte stream          |        |
| request headers                |        |
| DASH                           |   ✅   |
| HLS                            |   ✅   |
| ICY metadata                   |        |
| buffer status/position         |   ✅   |
| play/pause/seek                |   ✅   |
| set volume/speed               |   ✅   |
| clip audio                     |   ✅   |
| playlists                      |   ✅   |
| looping/shuffling              |   ✅   |
| compose audio                  |        |
| gapless playback               |   ✅   |
| report player errors           |   ✅   |
| handle phonecall interruptions |        |
| buffering/loading options      |        |
| set pitch                      |        |
| skip silence                   |        |
| equalizer                      |   ✅   |
| volume boost                   |   ✅   |