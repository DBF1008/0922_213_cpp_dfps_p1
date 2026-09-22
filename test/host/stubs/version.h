// Host-test stub for the real source/version.h.
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

inline const char *GetGitCommitHash(void) { return "host-test"; }

#ifdef __cplusplus
}
#endif
