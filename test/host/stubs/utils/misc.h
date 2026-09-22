// Host-test stub for the real source/utils/misc.h.
#pragma once

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <string_view>
#include <unistd.h>

inline void Sleep(int64_t us) { usleep((useconds_t)us); }

constexpr int64_t SToUs(double second) { return second * 1000 * 1000; }

// Records the caller's pid into $DFPS_TEST_DIR/<file> so host tests can
// track daemon/app processes without ps(1).
inline void RecordPid(const std::string &file) {
    const char *dir = getenv("DFPS_TEST_DIR");
    if (dir == nullptr) {
        return;
    }
    std::string path = std::string(dir) + "/" + file;
    FILE *fp = fopen(path.c_str(), "w");
    if (fp) {
        fprintf(fp, "%d", getpid());
        fclose(fp);
    }
}

inline void InitArgv(int, char **) {}
inline void SetSelfName(const std::string_view &name) { RecordPid(std::string(name) + ".pid"); }
