#include "dfps.h"
#include "utils/misc.h"

#include <fstream>
#include <stdexcept>

Dfps::Dfps() {}

Dfps::~Dfps() {}

void Dfps::Load(const std::string &configPath, const std::string &) {
    std::ifstream in(configPath);
    if (!in) {
        throw std::runtime_error("cannot open config");
    }
    bool hasUniversial = false;
    bool hasOffscreen = false;
    std::string line;
    while (std::getline(in, line)) {
        auto pos = line.find_first_not_of(" \t\r");
        if (pos == std::string::npos || line[pos] == '#') {
            continue;
        }
        if (line[pos] == '*') {
            hasUniversial = true;
        }
        if (line[pos] == '-') {
            hasOffscreen = true;
        }
    }
    if (!hasUniversial || !hasOffscreen) {
        throw std::runtime_error("invalid config: '*' or '-' rule missing");
    }
}

void Dfps::Start(void) { RecordPid("app.pid"); }
