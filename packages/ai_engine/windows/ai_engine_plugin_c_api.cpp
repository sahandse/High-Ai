#include "include/ai_engine/ai_engine_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "ai_engine_plugin.h"

void AiEnginePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ai_engine::AiEnginePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
