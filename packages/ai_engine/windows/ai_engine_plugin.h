#ifndef FLUTTER_PLUGIN_AI_ENGINE_PLUGIN_H_
#define FLUTTER_PLUGIN_AI_ENGINE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace ai_engine {

class AiEnginePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AiEnginePlugin();

  virtual ~AiEnginePlugin();

  // Disallow copy and assign.
  AiEnginePlugin(const AiEnginePlugin&) = delete;
  AiEnginePlugin& operator=(const AiEnginePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace ai_engine

#endif  // FLUTTER_PLUGIN_AI_ENGINE_PLUGIN_H_
