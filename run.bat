@echo off
rem Wrapper that sets PUB_CACHE to a non-sandboxed location before invoking Flutter.
rem Required when running from within the Claude Code environment where the default
rem pub cache path is inside the app sandbox and invisible to the Gradle JVM daemon.
set PUB_CACHE=%USERPROFILE%\pub_cache
flutter %*
