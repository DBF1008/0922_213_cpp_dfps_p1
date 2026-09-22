// Host-test stub for the real source/utils/inotify.h.
// Polls the watched file's mtime instead of using Linux inotify.
#pragma once

#include <string>
#include <sys/stat.h>
#include <unistd.h>

class Inotify {
public:
    enum { CLOSE_WRITE = 0x08 };

    void Add(const std::string &path, int, void *) { path_ = path; }

    // Returns once the file's mtime has changed and stayed stable for a few
    // polls, mimicking the real inotify CLOSE_WRITE event which fires only
    // after the writer has closed the file.
    void WaitAndHandle(void) {
        long long last = MtimeNs();
        long long changed = last;
        int stable = 0;
        for (;;) {
            usleep(50 * 1000);
            long long now = MtimeNs();
            if (now != changed) {
                changed = now;
                stable = 0;
            } else if (changed != last && ++stable >= 4) {
                return;
            }
        }
    }

private:
    long long MtimeNs(void) const {
        struct stat st;
        if (stat(path_.c_str(), &st) != 0) {
            return 0;
        }
#ifdef __APPLE__
        return (long long)st.st_mtimespec.tv_sec * 1000000000LL + st.st_mtimespec.tv_nsec;
#else
        return (long long)st.st_mtim.tv_sec * 1000000000LL + st.st_mtim.tv_nsec;
#endif
    }

    std::string path_;
};
