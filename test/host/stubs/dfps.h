// Host-test stub for the real source/dfps.h.
// Mimics the real Dfps interface; Load() validates the config the same way
// the real DynamicFps::LoadConfig does (requires '*' and '-' rules) and
// throws on invalid config, which makes AppMain() exit the child process.
#pragma once

#include <string>

class Dfps {
public:
    Dfps();
    ~Dfps();

    void Load(const std::string &configPath, const std::string &notifyPath);
    void Start(void);
};
