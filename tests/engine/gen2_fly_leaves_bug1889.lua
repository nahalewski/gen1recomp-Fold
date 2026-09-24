-- pokegold engine/events/field_moves.asm:429-446 (#1889)
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

local World = require("src.world.gen2.World")

local function newWorld()
  return setmetatable({}, { __index = World })
end

do
  local world, fa = newWorld(), { leaves = {} }
  world:spawnFlyLeaves(fa)
  T.eq(#fa.leaves, 1, "the first FrameTimer tick spawns a leaf")
  T.eq(fa.leaves[1].y, 0x40 - 1,
    "on the $40 row, one pixel up after its own first step")
  T.eq(fa.leaves[1].x, 2, "AnimSeq_FlyLeaf's `inc [hl] / inc [hl]` on XCOORD")
end

do
  local world, fa = newWorld(), { leaves = {} }
  world:spawnFlyLeaves(fa)
  local leaf = fa.leaves[1]
  local x, y = World.leafScreenPos(leaf)
  T.eq(x, 2 + 0x40 - 12,
    "XCOORD + XOFFSET less the OAM origin and .OAMData_Leaf's own -1 tile")
  T.eq(y, 0x40 - 1 - 20, "and YCOORD the same way")
  T.eq(select(1, World.leafScreenPos({ x = 0, y = 0 })), -12,
    "a leaf with no XOFFSET yet still gets the bias")
end

do
  local world, fa = newWorld(), { leaves = {} }
  local rows = {}
  for _ = 1, 32 do
    local before = #fa.leaves
    world:spawnFlyLeaves(fa)
    if #fa.leaves > before then
      rows[#rows + 1] = fa.leaves[#fa.leaves].y + 1
    end
  end
  T.eq(#rows, 4, "four leaves in thirty-two frames: one every eight")
  T.eq(rows[1], 0x40, "`and $18 / sla a / add 8 * 8` row one is $40")
  T.eq(rows[2], 0x50, "row two is $50")
  T.eq(rows[3], 0x60, "row three is $60")
  T.eq(rows[4], 0x70, "row four is $70, and then it wraps")
end

do
  local world, fa = newWorld(), { leaves = {} }
  world:spawnFlyLeaves(fa)
  T.eq(fa.leaves[1].xoff, 0x40, "VAR1 starts at zero, so XOFFSET is the full $40")
  for _ = 1, 16 do world:spawnFlyLeaves(fa) end
  T.check(fa.leaves[1].xoff < 0x40,
    "and it swings back in as VAR1 climbs")
end

do
  local world, fa = newWorld(), { leaves = {} }
  world:spawnFlyLeaves(fa)
  local first = fa.leaves[1]
  local gone = false
  for _ = 1, 200 do
    world:spawnFlyLeaves(fa)
    local live = false
    for _, leaf in ipairs(fa.leaves) do
      if leaf == first then live = true end
    end
    if not live then gone = true break end
    T.check(first.x < 184 + 2, "a live leaf is still short of 184")
  end
  T.check(gone, "past the right edge DeinitializeSprite takes it")
end

do
  local world, fa = newWorld(), { leaves = {} }
  for _ = 1, 400 do world:spawnFlyLeaves(fa) end
  T.check(#fa.leaves <= 9,
    "InitSpriteAnimStruct runs out of slots at nine leaves")
end

do
  local world = newWorld()
  local from = { leaves = {} }
  for _ = 1, 8 do world:spawnFlyLeaves(from) end
  T.eq(world.flyLeafCounter, 8, "the counter is World's, not the animation's")
  local to = { leaves = {} }
  world:spawnFlyLeaves(to)
  T.eq(#to.leaves, 1, "so FlyTo's frame 8 spawns rather than waiting for 0")
  T.eq(to.leaves[1].y + 0, 0x50 - 1, "and on the row after FlyFrom's last")
end

T.finish("gen2_fly_leaves_bug1889")
