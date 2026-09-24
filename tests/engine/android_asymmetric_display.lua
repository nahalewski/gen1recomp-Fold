local function read(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end

local function check(value, message)
  if not value then error(message, 2) end
end

local java = read(
  "mobile/android/love/src/main/java/org/love2d/android/GameActivity.java")
local manifest = read("mobile/android/app/src/main/AndroidManifest.xml")

check(manifest:find("android.allow_multiple_resumed_activities", 1, true)
    and manifest:find("GameActivity$SecondaryActivity", 1, true)
    and manifest:find('android:exported="false"', 1, true),
  "the private companion Activity opts into Android multi-display resume")
check(java:find("android.os.Build.VERSION.SDK_INT < 29", 1, true)
    and java:find("options.setLaunchDisplayId", 1, true),
  "the primary-display fallback is restricted to Android 10+")
check(java:find("SECONDARY_TARGET_HANDHELD", 1, true)
    and java:find("SECONDARY_TARGET_EXTERNAL", 1, true)
    and java:find("handheldAvailable ? handheld : external", 1, true),
  "routing hints retain a safe available-display fallback")
check(java:find("dualScreenDisplayMode != %-1")
    and java:find("AYN_SECOND_SCREEN", 1, true)
    and java:find("dualScreenModeObserverRegistered", 1, true),
  "the optional AYN state is guarded and lifecycle-bound")
check(java:find("activity.dispatchKeyEvent", 1, true)
    and java:find("activity.dispatchGenericMotionEvent", 1, true),
  "companion windows forward controller input to the game Activity")

print("android asymmetric display routing: ok")
