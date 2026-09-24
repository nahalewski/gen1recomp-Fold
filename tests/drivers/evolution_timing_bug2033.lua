-- pokered engine/movie/evolution.asm:12-19 stops the music and plays
-- and PlayCry blocks (home/pokemon.asm:145-149), so EvolvedText
-- (engine/pokemon/evos_moves.asm:136) cannot print until the new cry ends.
--   SHOT_DIR=/tmp/evo2033 POKEPORT_DRIVER=tests/drivers/evolution_timing_bug2033.lua \
--     POKEPORT_IDENTITY=bug2033 POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR")
    or "/tmp/evo2033"
  os.execute("mkdir -p " .. DIR)

  local Pokemon = require("src.pokemon.Pokemon")
  local Evolution = require("src.pokemon.Evolution")

  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1

  local function top() return game.stack:top() end
  local function evoState()
    for _, st in ipairs(game.stack.states or {}) do
      if st.screenId == "EvolutionState" then return st end
    end
    return nil
  end
  local function waitFor(cond, max)
    for _ = 1, max or 600 do
      if cond() then return true end
      U.wait(1)
    end
    return false
  end
  local function pagesText(st)
    if not st or not st.pages then return nil end
    local parts = {}
    for _, page in ipairs(st.pages) do
      if type(page) == "table" then
        for _, line in ipairs(page) do
          if type(line) == "string" then parts[#parts + 1] = line end
        end
      elseif type(page) == "string" then
        parts[#parts + 1] = page
      end
    end
    return table.concat(parts, " ")
  end
  local function findText(needle)
    for _, st in ipairs(game.stack.states or {}) do
      local blob = pagesText(st)
      if blob and blob:find(needle, 1, true) then return st end
    end
    return nil
  end

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(10)

  local mon = Pokemon.new(game.data, "PARAS", 23)
  table.insert(game.save.party, 1, mon)
  Evolution.evolve(game, mon, "PARASECT", nil, "LEVEL")

  if not waitFor(function() return evoState() ~= nil end, 300) then
    error("EvolutionState never opened")
  end
  local evo = evoState()

  U.shot(game, DIR .. "/evo2033_1_clear.png")
  U.log("head", "loading=", evo.loading, "t=", evo.t)
  waitFor(function() return (evo.loading or 0) <= 42 end, 200)
  U.shot(game, DIR .. "/evo2033_2_blank42.png")
  waitFor(function() return (evo.loading or 0) <= 2 end, 200)
  U.shot(game, DIR .. "/evo2033_3_blank_last.png")
  U.log("one frame short of the pic", "loading=", evo.loading)
  waitFor(function() return evo.loading == nil end, 200)
  U.shot(game, DIR .. "/evo2033_4_pic_and_cry.png")
  U.log("pic up", "loading=", evo.loading, "cryWait=", evo.cryWait)

  if not waitFor(function() return evo.done end, 900) then
    error("the flash never finished")
  end
  U.shot(game, DIR .. "/evo2033_5_settled.png")
  U.log("flash end", "species=", mon.species, "endCryWait=", evo.endCryWait)
  U.wait(50)
  U.shot(game, DIR .. "/evo2033_6_cry_alone.png")
  U.log("50 frames into the new cry", "topIsEvo=", top() == evo,
        "evolvedText=", findText("evolved") ~= nil)

  if not waitFor(function() return findText("evolved") ~= nil end, 400) then
    error("the evolved-into text never printed")
  end
  U.wait(70)
  U.shot(game, DIR .. "/evo2033_7_evolved_text.png")

  U.log("shots in", DIR)
  U.log("Right: shots 1-3 show a blank white field with the \"is evolving!\"")
  U.log("box still up (a Tink sounds on shot 1); shot 4 has the PARAS pic and")
  U.log("its cry together; shot 6 still has the settled PARASECT under the OLD")
  U.log("box, silent but for its cry; shot 7 finally types \"evolved into\".")
  U.log("Wrong: the pic is up on shot 1, or the text is typing on shot 6.")

  while true do
    coroutine.yield()
  end
end
