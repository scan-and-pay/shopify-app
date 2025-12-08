#!/bin/bash
# Filter out EGL_emulation logs from Flutter Android

flutter run "$@" 2>&1 | grep -v -E "(EGL_emulation|app_time_stats|D/eglCodecCommon)"
