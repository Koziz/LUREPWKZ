-- SETTINGS --
math.randomseed(os.time())
local BOOSTER_NAME     = "LureBooster"
local WORKER_LIMIT     = 35
local BASE_SHIFT       = 77
local DISCORD_HOOK     = "YOUR_WEBHOOK"
local REPORT_INTERVAL  = 300000
local STORAGE_POINTS = {

    "KBOG:STEAL",
    "KBOG:STEAL1",
    "KBOG:STEAL2",
    "KBOG:STEAL3",
    "KBOG:STEAL4",
    "KBOG:STEAL5",
    "KBOG:STEAL6",
    "KBOG:STEAL7",
    "KBOG:STEAL8",
    "KBOG:STEAL9",
    "KBOG:STEAL10",
}
local TARGET_ITEMS = {

    2462,2463,2464,2465,2466,
    2467,2468,2469,2470,2471,
    2472,2473,2474,2475,2476,
    2477,2478,2479,2480,2481,
    2482,3353,3774,4561,4585,
}



local CURRENT_STORAGE = 1
local SHIFT_INTERVAL   = 100
local MIN_SHIFT        = 1
local BOOSTER_COST     = 100
--------------------------------------------------
-- SPEED
--------------------------------------------------

local STEP_DELAY       = 130
local RELEASE_DELAY    = 150
local PURCHASE_DELAY   = 120
local TRANSIT_DELAY    = 300


local SPAWN_INTERVAL   = 900
local LOOP_INTERVAL    = 1200
local RETRY_DELAY      = 1500

local TRAIN_TIMEOUT    = 80000
local TRANSIT_TIMEOUT  = 25000

local totalPurchased   = 0
local totalReleased    = 0
local completedCycles  = 0

local runningWorkers   = 0
local lastCreation     = 0

--------------------------------------------------
-- CHAT
--------------------------------------------------

local BOOT_QUOTES = {

    "another digital employee activated",
    "tutorial simulator 2026 edition",
    "your automation addiction continues",
    "the electricity meter is trembling",
    "human ambition truly ended here",
}

local SHOP_QUOTES = {

    "purchasing more fake fishing supplies",
    "economy manipulation in progress",
    "financial literacy has left the chat",
    "pixelstation shareholders terrified",
    "another excellent life decision",
}

local DROP_QUOTES = {

    "deploying industrial fish bait",
    "the ocean never asked for this",
    "mass production remains undefeated",
    "another pile of artificial garbage",
    "peak technological advancement",
}

local EXIT_QUOTES = {

    "cycle complete. sanity unavailable",
    "factory worker dismissed temporarily",
    "another glorious automated shift",
    "human laziness wins again",
    "router overheating successfully",
}

--------------------------------------------------
-- RANDOM LINE
--------------------------------------------------

local function phrase(pool)

    return pool[
        math.random(1, #pool)
    ]
end

--------------------------------------------------
-- ENGINE WRAPPER
--------------------------------------------------

local engine = {}

function engine.connect(actor)

    return actor:connect()
end

function engine.disconnect(actor)

    return actor:disconnect()
end

function engine.enter(actor, destination)

    return actor:warp(destination)
end

function engine.exit(actor)

    return actor:leave()
end

function engine.training(actor)

    return actor:start_tutorial()
end

function engine.position(actor, x, y)

    return actor:walk(x, y)
end

function engine.message(actor, text)

    return actor:say(text)
end

function engine.inventory(actor)

    return actor:get_inventory()
end

function engine.wallet(actor)

    return actor:get_account()
end

function engine.location(actor)

    return actor:get_world_name()
end

function engine.state(actor)

    return actor:state()
end

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function worldReady(actor)

    return engine.state(actor)
        == "InWorld"
end

local function gemCount(actor)

    local data =
        engine.wallet(actor)

    if data and data.gems then
        return data.gems
    end

    return 0
end

local function storagePoint()

    return STORAGE_POINTS[
        CURRENT_STORAGE
    ]
end

local function nextStorage()

    CURRENT_STORAGE =
        CURRENT_STORAGE + 1

    if CURRENT_STORAGE
        > #STORAGE_POINTS then

        CURRENT_STORAGE = 1
    end
end

local function trackedItem(id)

    for _, target
    in ipairs(TARGET_ITEMS) do

        if target == id then
            return true
        end
    end

    return false
end

--------------------------------------------------
-- CHAT SAFE
--------------------------------------------------

local function chatter(actor, text)

    if not worldReady(actor) then
        return
    end

    pcall(function()

        engine.message(
            actor,
            text
        )
    end)
end

--------------------------------------------------
-- ANTI COLLECT
--------------------------------------------------

local function suppressPickup(actor)

    pcall(function()

        actor:set_auto_collect(
            false,
            999999999
        )
    end)
end

--------------------------------------------------
-- WEBHOOK
--------------------------------------------------

local function report()

    if DISCORD_HOOK
        == "YOUR_WEBHOOK" then

        return
    end

    local payload = {

        embeds = {{

            title =
                "Factory Report",

            color = 5814783,

            fields = {

                {
                    name = "Cycles",
                    value =
                        tostring(
                            completedCycles
                        ),
                    inline = true
                },

                {
                    name = "Purchased",
                    value =
                        tostring(
                            totalPurchased
                        ),
                    inline = true
                },

                {
                    name = "Released",
                    value =
                        tostring(
                            totalReleased
                        ),
                    inline = true
                },
            }
        }}
    }

    pcall(function()

        http.post(
            DISCORD_HOOK,
            {
                json = payload
            }
        )
    end)
end

--------------------------------------------------
-- TRAVEL
--------------------------------------------------

local function travel(actor, destination)

    pcall(function()

        engine.enter(
            actor,
            destination
        )
    end)

    local timeout =
        now_ms() +
        TRANSIT_TIMEOUT

    while now_ms() < timeout do

        local currentState =
            engine.state(actor)

        local currentWorld =
            engine.location(actor)
            or ""

        if currentState
            == "InWorld"
        and string.upper(currentWorld)
            ==
            string.upper(
                destination:match(
                    "^([^:]+)"
                )
            ) then

            return true
        end

        if currentState
            == "Disconnected"
        or currentState
            == "Failed" then

            engine.connect(actor)

            sleep_ms(RETRY_DELAY)

            pcall(function()

                engine.enter(
                    actor,
                    destination
                )
            end)
        end

        sleep_ms(
            TRANSIT_DELAY
        )
    end

    return false
end

--------------------------------------------------
-- PURCHASE
--------------------------------------------------

local function consumeGems(actor)

    local count = 0

    while true do

        local gems =
            gemCount(actor)

        local currentState =
            engine.state(actor)

        local currentWorld =
            engine.location(actor)
            or ""

        if gems < BOOSTER_COST then
            break
        end

        if currentState
            ~= "InWorld"
        or string.upper(currentWorld)
            ~= "PIXELSTATION" then

            break
        end

        pcall(function()

            actor:send_packet({

                ID = "BIPack",
                IPId = BOOSTER_NAME
            })
        end)

        count = count + 1

        sleep_ms(
            PURCHASE_DELAY
        )
    end

    return count
end

--------------------------------------------------
-- MOVEMENT
--------------------------------------------------

local function relocate(actor, amount)

    if not worldReady(actor) then
        return
    end

    for _ = 1, amount do

        if not worldReady(actor) then
            break
        end

        engine.position(
            actor,
            1,
            0
        )

        sleep_ms(STEP_DELAY)
    end

    engine.position(
        actor,
        0,
        0
    )
end

--------------------------------------------------
-- RELEASE ITEMS
--------------------------------------------------

local function distribute(actor)

    if not worldReady(actor) then
        return 0
    end

    local inventory =
        engine.inventory(actor)

    local released = 0

    local globalOffset =
        math.floor(
            totalReleased /
            SHIFT_INTERVAL
        )

    local movement =
        BASE_SHIFT -
        globalOffset

    if movement < MIN_SHIFT then

        nextStorage()

        totalReleased = 0

        movement =
            BASE_SHIFT
    end

    relocate(
        actor,
        movement
    )

    local lastShift = 0

    for _, item
    in ipairs(inventory) do

        if not worldReady(actor) then
            break
        end

        if trackedItem(item.id)
        and item.amount > 0 then

            pcall(function()

                actor:drop(
                    item.id,
                    item.amount,
                    item.inventory_type
                )
            end)

            released =
                released +
                item.amount

            sleep_ms(
                RELEASE_DELAY
            )

            if released - lastShift
                >= SHIFT_INTERVAL then

                relocate(
                    actor,
                    movement
                )

                lastShift =
                    released
            end
        end
    end

    return released
end

--------------------------------------------------
-- CREATE SESSION
--------------------------------------------------

local function initializeWorker()

    local elapsed =
        now_ms() -
        lastCreation

    if elapsed
        < SPAWN_INTERVAL then

        sleep_ms(
            SPAWN_INTERVAL -
            elapsed
        )
    end

    local ok, actor =
        pcall(function()

            return addDevice()
        end)

    lastCreation =
        now_ms()

    if not ok or not actor then
        return nil, nil
    end

    local identity =
        actor:name()

    engine.connect(actor)

    local timeout =
        now_ms() + 30000

    while now_ms() < timeout do

        local currentState =
            engine.state(actor)

        if currentState
            == "MenuIdle" then

            break
        end

        if currentState
            == "Disconnected"
        or currentState
            == "Failed" then

            engine.connect(actor)

            sleep_ms(
                RETRY_DELAY
            )
        end

        sleep_ms(300)
    end

    if engine.state(actor)
        ~= "MenuIdle" then

        removeClient(identity)

        return nil, nil
    end

    --------------------------------------------------
    -- START TRAINING
    --------------------------------------------------

    local started = false

    timeout =
        now_ms() +
        TRAIN_TIMEOUT

    while now_ms() < timeout do

        local currentState =
            engine.state(actor)

        local currentWorld =
            engine.location(actor)
            or ""

        if not started
        and currentState
            == "MenuIdle" then

            started = true

            engine.training(actor)

            chatter(
                actor,
                phrase(
                    BOOT_QUOTES
                )
            )

            sleep_ms(3000)
        end

        if currentState
            == "InWorld"
        and string.upper(currentWorld)
            == "PIXELSTATION" then

            return actor, identity
        end

        if currentState
            == "Disconnected"
        or currentState
            == "Failed" then

            engine.connect(actor)

            sleep_ms(
                RETRY_DELAY
            )
        end

        sleep_ms(300)
    end

    removeClient(identity)

    return nil, nil
end

--------------------------------------------------
-- EXECUTE
--------------------------------------------------

local function executeCycle()

    local actor, identity =
        initializeWorker()

    if not actor then
        return
    end

    --------------------------------------------------
    -- ENSURE MARKET
    --------------------------------------------------

    local currentState =
        engine.state(actor)

    local currentWorld =
        engine.location(actor)
        or ""

    if currentState
        ~= "InWorld"
    or string.upper(currentWorld)
        ~= "PIXELSTATION" then

        if not travel(
            actor,
            "PIXELSTATION"
        ) then

            removeClient(identity)

            return
        end
    end

    sleep_ms(500)

    --------------------------------------------------
    -- BUY
    --------------------------------------------------

    local purchased =
        consumeGems(actor)

    chatter(
        actor,
        phrase(
            SHOP_QUOTES
        )
    )

    totalPurchased =
        totalPurchased +
        purchased

    --------------------------------------------------
    -- CLEAN EXIT
    --------------------------------------------------

    engine.exit(actor)

    local timeout =
        now_ms() + 15000

    while now_ms() < timeout do

        local currentState =
            engine.state(actor)

        if currentState
            == "MenuIdle" then

            break
        end

        if currentState
            == "Disconnected"
        or currentState
            == "Failed" then

            engine.connect(actor)
        end

        sleep_ms(300)
    end

    --------------------------------------------------
    -- STORAGE WORLD
    --------------------------------------------------

    local destination =
        storagePoint()

    if not travel(
        actor,
        destination
    ) then

        removeClient(identity)

        return
    end

    chatter(
        actor,
        phrase(
            DROP_QUOTES
        )
    )

    --------------------------------------------------
    -- DROP
    --------------------------------------------------

    local released =
        distribute(actor)

    totalReleased =
        totalReleased +
        released

    completedCycles =
        completedCycles + 1

    chatter(
        actor,
        phrase(
            EXIT_QUOTES
        )
    )

    --------------------------------------------------
    -- CLOSE
    --------------------------------------------------

    pcall(function()

        engine.exit(actor)
    end)

    sleep_ms(500)

    removeClient(identity)
end

--------------------------------------------------
-- THREAD
--------------------------------------------------

local function worker(index)

    sleep_ms(index * 500)

    while true do

        runningWorkers =
            runningWorkers + 1

        pcall(function()

            executeCycle()
        end)

        runningWorkers =
            runningWorkers - 1

        sleep_ms(
            LOOP_INTERVAL
        )
    end
end

--------------------------------------------------
-- REPORT LOOP
--------------------------------------------------

local function reporter()

    while true do

        sleep_ms(
            REPORT_INTERVAL
        )

        report()
    end
end

--------------------------------------------------
-- STARTUP
--------------------------------------------------

for _, id
in ipairs(getBots()) do

    removeClient(id)
end

sleep_ms(1000)

runThread(function()

    reporter()
end)

for i = 1, WORKER_LIMIT do

    runThread(function()

        worker(i)
    end)

    sleep_ms(500)
end

while true do
    sleep_ms(60000)
end
