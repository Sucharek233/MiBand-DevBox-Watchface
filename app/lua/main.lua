require "components"
require "about"
require "extraFunctions"

local Handler = require "service.handler"

local root
local isRunning = false

local function entry()
    local handler = Handler:new(1000)

    _, root = CreateRoot()

    local contentContainer = CreateFlexboxContainer(root)
    contentContainer:set {
        flex = {
            justify_content = "center",
            align_items = "center",
            flex_direction = "column"
        },
        h = lvgl.PCT(100)
    }

    CreateCenteredLabel(contentContainer, "DevBox Lua Service", 24)

    local statusCard = CreateFlexboxContainer(contentContainer)
    statusCard:set {
        h = 44,
        bg_color = "#1E1E24",
        bg_opa = lvgl.OPA(100),
        radius = 12,
        pad_left = 12,
        pad_right = 12,
        flex_grow = 0,
        flex = {
            justify_content = "center",
            align_content = "center",
        }
    }
    local statusDot = statusCard:Object(nil, {
        w = 10,
        h = 10,
        radius = 5,
        bg_color = "#FF453A",
        bg_opa = lvgl.OPA(100)
    })
    local statusText = CreateLabel(statusCard, "Stopped", 20)

    local function updateUIState(active)
        isRunning = active
        if active then
            statusText:set { text = "Running", text_color = "#30D158" }
            statusDot:set { bg_color = "#30D158" }
        else
            statusText:set { text = "Stopped", text_color = "#8E8E93" }
            statusDot:set { bg_color = "#FF453A" }
        end
    end

    local startBtn, startBtnLabel = CreateBtn(contentContainer, "Start Service")
    startBtnLabel:set {
        text_color = "#30D158",
        text_font = lvgl.Font(DefFont, 16)
    }
    startBtn:onClicked(function ()
        handler:startPolling()
        updateUIState(true)
    end)

    local stopBtn, stopBtnLabel = CreateBtn(contentContainer, "Stop Service")
    stopBtnLabel:set {
        text_color = "#FF453A",
        text_font = lvgl.Font(DefFont, 16)
    }
    stopBtn:onClicked(function ()
        handler:stopPolling()
        updateUIState(false)
    end)

    local cleanBtn, cleanBtnLabel = CreateBtn(contentContainer, "Clean Up")
    cleanBtnLabel:set {
        text_color = "#8E8E93",
        text_font = lvgl.Font(DefFont, 15)
    }
    cleanBtn:onClicked(function ()
        handler:clean()
        ShowPopup("Service Clean", "Output data and logs cleared.", nil, nil)
    end)

    updateUIState(false)
end

-- execute watchface function
entry()
