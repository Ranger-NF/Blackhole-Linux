#include "include/just_audio_mpv/just_audio_mpv_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "just_audio_mpv_plugin.h"

void JustAudioMpvPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  just_audio_mpv::JustAudioMpvPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
