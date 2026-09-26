# AeonDX

Azahar, the 3DS emulator, opening on a 3DS HOME menu that also plays DS
(melonDS), GB / GBC / GBA (SkyEmu), Switch (Eden) and the gen1recomp
games: see *3DS Fold* below.  Each push to `main` builds the APK
(`AeonDX-<version>-build<n>` in the run's artifacts) and attaches it to
the release numbered in `VERSION` (now `0.0.1-prerelease0.1`, a GitHub
pre-release).  Bump `VERSION` to start the next release.

# gen1recomp Fold

## 3DS Fold: Azahar with the 3DS HOME menu (`build.sh`)

One app that is both things at once: [Azahar](https://github.com/azahar-emu/azahar),
the 3DS emulator, is the base Android app, and it opens on this repo's 3DS
HOME menu (the fold3ds layer on gen1recomp, described below).  The HOME menu
is unchanged: same shell, top screen, applet bar, icon grid, play
coins, camera, stickers, sounds, and the recomp games playing from their
icons on the bottom screen.  Azahar is added to it:

* **3DS games on the HOME menu.**  Every game in Azahar's library (the
  games folder and installed titles) is a tile next to the recomp games,
  with its own icon.  On the top screen it shows as a 3DS game card with
  that icon as its label.  Tap it again, press A or Open, or tap the top
  screen, and Azahar plays it.  Back or Azahar's close-game option return
  to the HOME menu.  Manual opens the game's options in Azahar: cheats,
  shortcuts, the save / DLC / update / mod folders, compress,
  uninstall, and so on.  Tiles can be rearranged and resized like the
  others.
* **Adding 3DS games.**  An *Add 3DS Games* tile after the 3DS games offers
  Install CIA files (games, updates, DLC) or Choose your 3DS games folder
  (`.3ds`, `.cci`, `.cxi`).  New games join the grid on their own once
  Azahar has installed or found them.
* **Real game cards.**  A selected 3DS game shows a photo of its game card
  on the top screen: Azahar's side reads the product code from the game's
  header (`CTR-P-ECLP` -> `ECLP`) and fetches the card from GameTDB
  (`art.gametdb.com/3ds/cart/…`) once, on the phone.  Without one, a drawn
  card with the game's icon stands in.
* **The Azahar folder.**  One folder tile holds an icon for each Azahar
  settings page and tool, so the grid stays tidy:
  3DS Library, Emulation Settings (all of them), Graphics, Screen Layout,
  Controls, Sound, System Settings, General, 3DS Camera, Storage, Web
  Service, Debug, Install CIA, Games Folder, System Files, GPU Drivers,
  Multiplayer, Artic Base, Azahar Folder, Share Log, About Azahar.  Open
  the folder and its icons fill the grid, with Close Folder first and the
  folder's name on the play-meter row.  B, HOME or Close Folder closes
  it.  Each icon opens that page directly; Back returns to the folder.
  The icons are in `fold3ds/icons3ds/` (`az_<page>.png`,
  `azahar.png` for the folder), drawn by `tools/make_azahar_icons.py`.
  Replace any PNG to restyle it.
* **The Switch HOME Menu.**  The *Switch HOME Menu* applet on the 3DS
  HOME menu's bar swaps it for the Nintendo Switch's HOME menu across the
  whole inner screen (`fold3ds/homenx.lua`): your icon (Play Activity),
  the clock, Wi-Fi and battery across the top; one row of big square
  software icons that slides sideways, the selected one framed in blue
  with its name above; the round buttons -- Nintendo eShop, Album, 3DS
  HOME Menu, System Settings; the button guide along the bottom.  Basic
  White or Basic Black (System Settings > Themes).  A starts, X shows a
  recomp game's manual.  The *3DS HOME Menu* button, or System Settings >
  HOME Menu, goes back to the 3DS HOME menu; the choice is remembered
  (`fold3ds_ui.cfg`).
* **Controllers, as they connect.**  A Switch Pro Controller, Joy-Con,
  the Razer Kishi or any other pad works everywhere the shell draws --
  both HOME menus, the apps, the games playing in the shell -- and in the
  recomp games, with no setting up (`fold3ds/pads.lua`).  Buttons follow
  their labels: A on the right on a Nintendo pad, at the bottom on the
  Kishi.  The left stick is the + Pad, the right stick the C-Stick, the
  triggers ZL / ZR, the Home / Guide button HOME.  If a pad's labels come
  out wrong, the Switch HOME menu's System Settings > Controllers sets the
  layout by hand.
* **The 3DS skin is the only skin.**  The Classic launcher look and the
  THEME card are gone; the bottom screen is always the HOME menu.
* **First run.**  Until Azahar has its folder, a *Set Up 3DS* tile takes
  the grid slot of the 3DS games.  Opening it, or any Azahar icon, runs
  Azahar's own first-time setup (user folder, games folder, permissions).
* **Nothing removed from Azahar.**  Every Azahar screen, setting and
  feature is still there.  They open from the folder instead of from
  Azahar's own home screen, which is no longer a launcher entry.
* App id `com.nahalewski.aeondx`, signed with `ci/debug.keystore`.
  arm64 only.

How it fits together:

    build.sh                 apply.sh --package-only, then Azahar at a pinned commit + azahar/, builds
    fold3ds/azahar.lua       reads Azahar's library, opens Azahar (love.system.openURL)
    fold3ds/home3ds.lua      + 3DS game tiles and the Azahar folder
    fold3ds/init.lua         + the top screen for them; the 3DS skin as the only skin
    fold3ds/icons3ds/        the Azahar folder's icons (tools/make_azahar_icons.py draws them)
    azahar/                  the layer on Azahar (Android)
      patches/                 :love module, launcher, app id, three small hooks
      java/.../fold3ds/        Fold3dsBridge (library -> HOME menu), Fold3dsLinkActivity
                               (HOME menu -> Azahar), Fold3dsMain (Azahar's own screens)
      res/                     the link activity's theme, the launcher icon

The HOME menu (`org.love2d.android.GameActivity`) is the launcher.  When it
comes to the front, `Fold3dsBridge` scans Azahar's library (the same scan
Azahar's games list runs) and writes `fold3ds_azahar/games.tsv` plus the
game icons into the LÖVE save folder, where `fold3ds/azahar.lua` reads
them.  Tapping something calls `love.system.openURL("fold3ds-azahar://…")`.
The invisible `Fold3dsLinkActivity` receives it and starts the game, settings
page or tool on top of the menu.

Build:

    ./build.sh               # build/out/*.apk

Needs the Android SDK (platforms 35 and 36, build-tools 36, CMake 3.30.3,
NDK 27.3.13750724 for Azahar and NDK 25.2.9519653 for LÖVE), JDK 17, git
and python3.  GitHub Actions runs it on every push to `pixel-fold`
(`.github/workflows/build-3ds-fold.yml`) and attaches the APK to a Release.
`AZAHAR_COMMIT` picks another Azahar commit.  (`build-apk.yml` still builds
the gen1recomp-only APK with `apply.sh`.)

Desktop testing of the HOME menu works as below.  `POKEPORT_FOLD_FAKEAZAHAR=1` adds
three made-up 3DS games to the grid.

## DS and Virtual Console (`emu/`, `fold3ds/emucore.lua`)

DS games on the melonDS core (melonDS-android-lib) and Game Boy / Game Boy
Color / Game Boy Advance games on SkyEmu's cores, shown as the Virtual
Console, play inside the 3DS shell.  The cores are one native library,
`libemucore.so` (`emu/native`, the `:emucore` Gradle module `build.sh`
adds), which `fold3ds/emucore.lua` drives through LuaJIT's FFI;
`fold3ds/melonds.lua` and `fold3ds/vc.lua` are their providers for
`fold3ds/emus.lua` (tiles, a settings folder each).

* **The folder**, as Azahar keeps its own: `<phone storage>/Omnindo/` with
  `config/settings.ini`, `games/` (put `.nds`, `.gb`, `.gbc`, `.gba` here),
  `saves/`, `states/` and `bios/` (optional `bios7.bin`, `bios9.bin`,
  `firmware.bin`; `SkyEmu/gb_bios.bin`, `gbc_bios.bin`, `gba_bios.bin`).
* **Names and art**: `fold3ds/emudb/` maps a dump's CRC32 (GB / GBC / GBA)
  or a DS game's code to its No-Intro name (`tools/make_emudb.py`, from
  `tools/romdb`).  Box art (libretro-thumbnails), DS covers and cards
  (GameTDB) and each game's border (The Bezel Project) are downloaded on
  the phone when first needed; none are shipped.
* Desktop: `emu/native` builds with CMake
  (`-DMELONDS_DIR=... -DSKYEMU_DIR=...`); `EMUCORE_LIB=/path/libemucore.so`
  points the Lua side at it.

## gen1recomp Fold on its own (`apply.sh`)

gen1recomp on a foldable phone, as a 3DS.  This is upstream
[gen1recomp](https://github.com/bryanthaboi/gen1recomp)'s own Android app
(LÖVE 11.5, its launcher, its game engine, its mods) plus one layer,
`fold3ds/`, that plugs into the engine's display and input seams.  `apply.sh` clones upstream at a pinned commit,
drops `fold3ds/` in, applies `patches/` (the launcher's compact
bottom-screen layout, active only on the fold), appends one line to
`main.lua`, adds the folder to the packaged `game.love`, and runs
upstream's own Android build script.

## What it does

* **Open (inner screen)**: the 3DS, on a pale blue-white wallpaper.  The top shell's screen shows the game
  (or, in the launcher, the selected game's cartridge with arrows that
  change the game and a tap on the cart that plays it); the bottom shell's screen
  shows upstream's launcher with all its menus (GAMES, MODS, FIND, ONLINE,
  SKINS, IMPORT, settings) or, in game, the game's Pokémon animated
  (Yellow's Pikachu surfs).  Touch inside either screen reaches the
  launcher or the game as if that screen were the whole window.
* **Top screen shapes (in game)**: a tap on the C-stick above X cycles
  GAME BOY COLOR (the 10:9 screen at a whole pixel scale), WIDESCREEN (the
  whole screen opening) and FULL SCREEN (the whole top panel, over the
  Game Boy Color frame).  The choice is remembered.
* **L / ZL / R / ZR**: L over ZL at the middle of the left edge, R over
  ZR at the right, beside the hinge.  They fade out when nothing touches
  that edge and come back at a touch.  In game L / R are the GBA's L / R
  (FireRed / LeafGreen) and ZL / ZR slow the game down / speed it up; in
  the launcher L / R change tabs and ZL / ZR fast-scroll; on the 3DS HOME
  menu L / R scroll the icons and ZL / ZR change their size.  Settings >
  3DS Shell turns them off.
* **Menus on the bottom screen**: START's menu (and everything opened
  from it) and the mod manager draw on the bottom screen while the world
  stays on the top.  SELECT in the overworld opens the mod manager; SELECT
  again closes it.
* **Bottom-screen launcher**: no wordmark and no cartridge (the cartridge
  is on the top screen); the GAMES / MODS / FIND / ONLINE / SKINS / IMPORT
  strip scrolls sideways by dragging; the header stays put while the page
  under it scrolls with the up / down arrows at the screen's right edge or
  the D-pad's up / down (hold to repeat).  The circle pad and the D-pad's
  left / right move the focus.  Settings is its own screen, and carries
  the app updater, the patch notes, Troubleshooting and the BOIS CLUB
  GAMES mark that used to sit under every page.
* **SKINS (fold)**: a *THEME* card switches the bottom screen between
  *Classic* and *3DS*.  The 3DS theme turns the bottom screen into the 3DS HOME
  menu: the applet bar (Settings, Mods, Find, Online, Skins, Import, Save
  Sync, Exit) with the two icon-size buttons, the icon grid (every game)
  filling down then across on a strip you swipe or flick sideways, the
  name bubble over the selected icon at one row, the play meter (the
  blue bar fills with time in the app; every 12 hours full pays a coin,
  up to 99999) and Manual / Open.  Five
  sizes, 1 row of 4 across to 5 rows of 9 across (size buttons, a pinch,
  or X / Y), and every change animates the icons from their old slots to
  their new ones.  Hold an icon until it lifts to drag it somewhere else;
  size and order are remembered.  Tap to select, tap again or A to open;
  Manual opens a game's electronic manual on the bottom screen, as the
  3DS does: pages written for each recomp game (getting started, the
  controls on the Fold, the adventure, battles, what is only in that
  version, and gen1recomp's options, rulesets, mods, online play and
  saves; `fold3ds/manualtext.lua`), a Contents list, the contents on the
  top screen with the chapter being read lifted out, and Game Options for
  the game's manage page.  Scans of your own printed manual go in front
  of them (`fold3ds/manuals/<version>/`).  An opened icon shows its page
  (light theme: white panels, HOME-menu blue selection) under a back bar;
  back, B or HOME returns to the menu.  The top screen is the 3DS's
  too: the status bar (signal, Internet, the play coins, date and time,
  battery), the tiled wallpaper with the selected game's cartridge
  floating over it -- a solid 3D Game Boy Color cart (GBA cart for
  FireRed / LeafGreen) in the game's shell colour with its label on the
  front, bobbing and swaying over a soft shadow and spinning in when you
  pick another game (your own label art: `fold3ds/labels/<version>.png`)
  -- and the game's name; tapping it
  plays a ready game.  Tile icons come from
  `fold3ds/icons3ds/<id>.png`, with stand-ins until they exist.  And a *COVER STICKERS* card puts
  pictures of your own on the closed lid, as many as you like, stacked
  newest on top.  The editor crops a picture (drag the frame or its
  corners), rounds its corners, sizes it, keeps or drops its white edge
  and turns it freely (the knob above it on the cover preview, the Turn
  buttons, or L / R); drag it on the preview to place it.  On the cover
  screen a sticker peels: drag it and its nearest corner folds back to its
  white backing; peel it far enough and it comes off in your finger (a
  second finger twists it), and letting go sticks it down there, on top.
  Every re-stick leaves its corner lifted a little more and starts it
  wearing with play time -- sooner the more it has been re-stuck -- until
  it falls off; a sticker never peeled stays on for good.  Fallen stickers
  wait in SKINS (*Put the fallen ones back*).  Stickers keep their
  proportions, stay on the lid's flat face and are cut to the shell's
  shape.  Stickers come in five shapes: rectangle (rounded as you like), square,
  circle, triangle and a slime splat with drips.  A sticker on the lid or
  the open top shell can hang over the top, left or right edge.  The part
  that hangs over wraps round onto the other side, where a real sticker
  would bend: from the lid onto the top shell's face, and back.  It sits
  mirrored at the shared edge, with a crease shadow where it bends.
  Tapping the cover's right camera eye opens the maker too.
  Tapping the inner camera above the open 3DS's top screen puts stickers
  on the open shells instead: the editor's *On: top shell / On: bottom
  shell* row picks which one.  They sit under the screens and buttons,
  so they never cover them, and they are cut to the shell.
* **Every emulator in the one HOME menu.**  3DS games open in Azahar.
  DS games (melonDS) and GB / GBC / GBA games (SkyEmu, *Virtual Console*)
  play inside the 3DS shell (`fold3ds/emuplay.lua`).  DS uses both
  screens, with touch on the bottom one.  Virtual Console uses the top
  screen, with the box art and Save / Load / Reset / Close below.  The
  shell's buttons play the game, and HOME opens its pause menu.  The whole
  top panel is the top screen.  Every game starts FULL SCREEN (stretched
  over the whole screen); the C-stick switches to NATIVE (its own shape at
  whole pixels), on both screens.  Each emulator has its own folder on the
  grid with its settings and tools.  Their pages are drawn like the 3DS's
  System Settings (`fold3ds/emupage.lua`), and their icons are made by
  `tools/make_emu_icons.py`.
* **Friend List** (HOME bar): your friend card (name, a friend code of
  your own, a comment, the game you play most) and the friends you
  register by their friend code, as cards: rename or delete them; names
  and comments are typed on the phone's keyboard.
* **Game Notes** (HOME bar): sixteen ruled pages to draw on with your
  finger. It has four pen colours, three sizes, an eraser and Clear, and
  L / R turn the page. The top screen shows every page; pages are kept in
  `fold3ds_notes/`.
* **3DS game banners**: a 3DS game picked on the HOME grid shows as the
  3DS shows software: its card on a stage in its icon's colour, light
  turning behind it, and the title bubble below (icon, title, publisher).
* **Startup, as a 3DS starts**: the boot screen and its jingle, then the
  *Health & Safety Information* warning (its real HOME Menu title, EN or
  JP with the artwork setting) until a touch or a button, then the HOME
  Menu coming up out of white.
* **Real 3DS HOME Menu art**: the HOME bar's Camera, Download Play,
  eShop, Settings and Online wear the 3DS's own HOME Menu icons (from The
  Spriters Resource's 3DS HOME Menu sheets, kept whole in
  `fold3ds/homesprites/`, not packed into the APK).  Picking Camera or
  Settings on the bar shows its banner on the top screen as the 3DS does:
  the icon turning in 3D over the app's real title ("Nintendo 3DS Camera",
  "System Settings"), in English or Japanese with SKINS > CARTRIDGE
  ARTWORK (`fold3ds/banners/`).  *Division of work*: this UI layer
  (fold3ds/*.lua, icons, banners) is kept in step with the Azahar base
  (azahar/, shell/, build.sh -- the other session's) by merging before
  every push.
* **Activity Log (3DS theme)**: on the HOME bar with the 3DS's own icon
  and banner title (English / Japanese).  *Play Time* ranks every title
  played -- gen1recomp's games timed while they run, Azahar's 3DS games
  from launch until the HOME menu is back -- with its icon, total time,
  times played and average; the top screen shows the chosen title's
  record (first and last day played).  *This Week* is a bar per day of
  time played, and on the top screen the week's steps from the pedometer
  with the Activity Log's walking figure.  Kept in fold3ds_activity.cfg.
* **Nintendo eShop (3DS theme)**: the shopping bag on the applet bar is
  the community mod catalog as a 3DS store (`fold3ds/eshop.lua`, art in
  `fold3ds/eshop/` cut from the supplied eShop sheet).  The orange eShop
  bar, shelves (New, Popular, Updated, Installed; L / R switch), four titles
  a page with their art, author, "Free", a NEW tag for recent ones and
  Download / Update / Open buttons; a title's page with its big Download
  (Free) button, the bar filling and the dots turning, then "Thank you!".
  Open goes on to MODS to turn it on.  The top screen turns the eShop bag
  in 3D over the logo, or shows the title's art and blurb.  It is FIND's
  own catalog and installer underneath.  Sounds from the 3DS pack:
  connecting on the way in, the wait loop while the catalog loads and its
  end, the gift unwrapping when a download lands, the error chime if not.
* **Download Play (3DS theme)**: the orange icon on the applet bar.
  Picking it (d-pad) shows its banner turning in 3D under the top screen's
  panel, as the 3DS does.  *Send* packs a game's saves
  (`saves/<game>/`, `save_<game>.lua` and backups), the installed mods,
  or both (the *Sends:* button picks; mods only skips the game list); *Receive a game* finds phones that are sending, lists
  them, and receives with a progress bar and the link speed; *Install*
  (tap twice) unpacks it, moving every file it replaces into
  `downloadplay/backup_<time>/`.  The ROM and the data extracted from it
  never travel: each phone imports its own.  The transfer is Google's
  Nearby Connections (`android/FoldPlay.java`): the phones find each other
  over Bluetooth and the files move over Wi-Fi Direct / Wi-Fi whenever
  that is faster.  Android asks for Nearby devices and Location the
  first time (Nearby needs location on every Android version); if one is
  refused, *Allow and try again* asks again.  `POKEPORT_FOLD_FAKEDP=1` stands in for a second phone on a
  desktop.
* **L / R on the HOME menu**: the L-camera and camera-R buttons sit in
  the top screen's lower corners (3DS theme); L, R or a tap on either
  opens the Camera, as on the 3DS.  (ZL / ZR still resize the icons.)
* **Steps**: the 3DS theme's top screen status bar shows today's steps
  in the 3DS pedometer's grey pill (footprints, "8692 Steps", the time),
  from the phone's step counter (`FoldBridge` "steps", counted from the
  start of the day, separate from the Pokewalker mod's bridge).  Android
  asks for Physical activity permission once; without it the date shows
  instead.  `POKEPORT_FOLD_FAKESTEPS=<n>` fakes it on a desktop.
* **Volume slider**: the VOL slider on the top half's left edge moves:
  drag it (top loud, bottom off) and it sets the app's volume.  The
  phone's volume keys move it too, without Android's volume popup
  (Settings > 3DS Shell > Volume keys move the 3DS slider).
* **Boot screen**: the first time the menu comes up on the open 3DS, the
  G1R Deluxe logo fills both screens (`fold3ds/boot/top.jpg`,
  `bottom.jpg`, cut to 5:3 and 4:3) with a slow push-in and a light
  sweep, to the lid's click and the 3DS HOME menu's welcome jingle, then
  fades into the menu (3.6 s; a tap or any button skips it).  Unfolding
  the phone later clicks too.
* **Camera (3DS theme)**: the orange camera icon at the front of the
  HOME menu's applet bar opens the 3DS Camera.  The phone's live camera
  picture fills the top screen inside white corner brackets (yellow while
  the self-timer counts down, green as the shutter fires, with a white
  flash and a shutter click).  On the bottom screen: Shoot (or A, L, R),
  Photos, Settings, zoom + / - (or up / down, up to 4x), the rear / front
  camera switch (or X), the filter chip (or left / right), and the modes
  Auto, Video, Multi (four shots half a second apart in one 2x2 picture)
  and Self-Timer (3 s).  Filters, after the 3DS camera's effects and
  lenses (`fold3ds/camfilters.lua`, shaders): Normal, Sepia, Black &
  White, Negative, Posterize, Pinhole, Fisheye, Mosaic, Mirror, Sparkle,
  Sketch -- in the viewfinder, the pictures and the videos.  Video: Shoot
  starts and stops (a red REC timer and red brackets while it runs, up to
  ten minutes), H.264 with the microphone's sound in
  `videos/HNV_0001.mp4`; the album shows videos with a play mark and A
  plays them in the phone's video player from the gallery copy
  (Movies/Gen1Recomp).  Photos shows the
  pictures newest first, ten to a page (swipe or left / right), the chosen
  one big on the top screen, with info and delete (tap the bin twice).
  Settings: camera, shutter sound, grid lines, and whether a copy goes to
  the phone's gallery (Pictures/Gen1Recomp).  Pictures are saved as
  `photos/HNI_0001.png`, ... in the save folder, exactly what the top
  screen shows.  Android asks for camera permission the first time.  The
  camera stops while the phone is folded or the applet is closed.  Native side:
  `android/FoldCamera.java` (Camera2), `android/FoldRecorder.java`
  (MediaCodec H.264 + AAC into MediaMuxer) and
  `patches/android-camera.patch` (`love.system.foldCamera` in liblove:
  YUV to RGBA straight into an ImageData, RGBA to YUV for the encoder;
  the CAMERA and RECORD_AUDIO permissions).
* **Menu sounds**: the 3DS HOME menu's own sound effects
  (`fold3ds/sounds/`, trimmed) on the menus -- tiles, the applet bar,
  resizing, lifting and dropping icons, scrolling, HOME, back, launcher
  buttons, stickers peeling / sticking / falling, the play coin, and a
  chime when the menu first comes up.  Silent in game except HOME and the
  C-stick.  Settings > 3DS Shell > Menu sounds turns them off.
* **Mods**: MODS has a *Download mods* button that opens FIND on the
  community catalog (gen1recomp.com/mod, the
  `bryanthaboi/gen1recomp-mod-index` feed): every listed mod, voxel ones
  included, downloads from its author's GitHub release, and MODS' update
  check keeps them current.  *Import* still installs a mod .zip.  The
  catalog as of the build ships in the APK (`fold3ds/modindex/`, refreshed
  by `apply.sh`) so the list is there before the first live fetch; no mod
  itself is bundled.
* **Shell buttons**: the drawn A, B, X, Y, D-pad, stick, START, SELECT and
  HOME press real input.  In game they are the Game Boy buttons (X and Y
  are R and L for FireRed / LeafGreen); HOME returns to the launcher.  In
  the launcher they drive its controller navigation (D-pad moves the
  focus, A activates, B backs out, Y switches to the pointer cursor,
  START / SELECT as upstream maps them).
* **Closed (cover screen)**: the closed lid, on a black wallpaper, fills the screen, whole,
  turned on its side on a portrait cover.  Opening the phone returns to
  the 3DS.
* The app locks landscape so the hinge runs across the middle; the game's
  own touch overlay is switched off because the shell replaces it.

## Build

    ./apply.sh                    # debug APK, app id com.nahalewski.aeondx
    ./apply.sh --release          # with upstream's signing variables set

Needs the Android SDK (platform 36, build-tools 36, NDK 25.2.9519653) and
a JDK; see upstream's `mobile/ANDROID.md`.

GitHub Actions builds it too (`.github/workflows/build-apk.yml`): every push
to `main`, and every 12 hours, attaches the APK to a GitHub Release.  It is signed with
`ci/debug.keystore`, a fixed debug key, so each build installs over the last.

## Desktop testing

With LÖVE 11.5 installed, from the prepared tree
(`build/gen1recomp`):

    POKEPORT_FOLD=ds  POKEPORT_FOLD_SIZE=1076x1038 love .   # the opened 3DS
    POKEPORT_FOLD=lid POKEPORT_FOLD_SIZE=2424x1080 love .   # the cover screen

`POKEPORT_FOLD_TEST` runs `fold3ds/dev/driver.lua` (not shipped): a
script of `frame:action:arg` items separated by `;`, for example
`40:touch:422,714;70:shot:/tmp/a.png;100:quit`.  `POKEPORT_FOLD_FAKECAM=1`
gives the Camera applet a moving test picture.

## Credits

Based on the Pokémon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC
(https://github.com/bryanthaboi/gen1recomp).  3DS shell art supplied by
the port's author.  Idle animations from the Generation V sprites in
github.com/PokeAPI/sprites.  Ported by nahalewski.
