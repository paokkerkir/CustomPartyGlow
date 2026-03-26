-- ============================================================
-- CustomPartyGlow - Vanilla WoW 1.12 / Turtle WoW Compatible
-- ============================================================

-- Saved Variables (must also be declared in the .toc file as:
--   ## SavedVariables: ClassGlowMapIconsDB)
if not ClassGlowMapIconsDB then
    ClassGlowMapIconsDB = {}
end

local iconSize   = ClassGlowMapIconsDB.iconSize  or 24
local sliderPos  = ClassGlowMapIconsDB.sliderPos  or {}

local mapButton       = nil
local sizeSliderFrame = nil
local customBlips     = {}

-- ── Class colours ────────────────────────────────────────────
local classColors = {
    ["Warrior"]     = {1,    0.78, 0.55},
    ["Paladin"]     = {0.96, 0.55, 0.73},
    ["Hunter"]      = {0.67, 0.83, 0.45},
    ["Rogue"]       = {1,    0.96, 0.41},
    ["Priest"]      = {1,    1,    1   },
    ["Shaman"]      = {0,    0.44, 0.87},
    ["Mage"]        = {0.41, 0.8,  0.94},
    ["Warlock"]     = {0.58, 0.51, 0.79},
    ["Druid"]       = {1,    0.49, 0.04},
}
-- 1.12 UnitClass() returns the *localised* name as arg1 and the
-- English token as arg2.  We key on the English token (upper-case).
local classColorsByToken = {}
for k, v in pairs(classColors) do
    classColorsByToken[string.upper(k)] = v
end

-- ── Pulse helper (manual alpha-pulse via OnUpdate) ───────────
-- 1.12 has no AnimationGroup API, so we drive the pulse ourselves.
local pulseFrames = {}   -- { frame, timer, direction }
local PULSE_SPEED = 1.2  -- full cycle (0→1→0) in seconds

local pulseDriver = CreateFrame("Frame")
pulseDriver:SetScript("OnUpdate", function()
    local dt = arg1   -- 1.12 passes elapsed as arg1, not a parameter
    for i = 1, getn(pulseFrames) do
        local p = pulseFrames[i]
        if p.tex and p.tex:IsShown() then
            p.t = p.t + dt * PULSE_SPEED
            local alpha = 0.4 + 0.4 * math.sin(p.t * math.pi) -- 0.4 – 0.8
            p.tex:SetAlpha(alpha)
        end
    end
end)

local function RegisterPulse(tex)
    local entry = { tex = tex, t = math.random() * 2 }
    tinsert(pulseFrames, entry)
end

-- ── Magnify compatibility ───────────────────────────────────
-- Magnify zooms the map by calling WorldMapDetailFrame:SetScale().
-- Because our blips are children of that frame they scale with it,
-- becoming oversized when zoomed.  We compensate by dividing the
-- visual size by the current scale factor.
-- Magnify also raises WorldMapFrame to FULLSCREEN / FULLSCREEN_DIALOG
-- strata, so we must match the parent's strata instead of hard-coding.

local function GetDetailScale()
    if WorldMapDetailFrame and WorldMapDetailFrame.GetScale then
        local s = WorldMapDetailFrame:GetScale()
        if s and s > 0 then return s end
    end
    return 1
end

local function GetMapStrata()
    -- Inherit whatever strata the map is currently using (Magnify changes it)
    if WorldMapFrame and WorldMapFrame.GetFrameStrata then
        return WorldMapFrame:GetFrameStrata()
    end
    return "FULLSCREEN"
end

-- ── Map-coordinate helpers ───────────────────────────────────
-- In 1.12 there is no C_Map.  We use GetPlayerMapPosition() which
-- returns (x, y) as 0–1 fractions **when the world map is open and
-- the correct zone is displayed**.

local function GetCanvasSize()
    -- WorldMapDetailFrame is the actual map texture in 1.12
    local f = WorldMapDetailFrame
    if f then
        return f:GetWidth(), f:GetHeight()
    end
    return WorldMapFrame:GetWidth(), WorldMapFrame:GetHeight()
end

-- ── UpdatePartyIcons ─────────────────────────────────────────
local function UpdatePartyIcons()
    -- Hide all existing blips first
    for _, blip in pairs(customBlips) do
        blip:Hide()
    end

    -- Build unit list
    local numMembers = GetNumPartyMembers()  -- 0 if solo / in raid
    local numRaid    = GetNumRaidMembers()

    local units = {}
    if numRaid > 0 then
        for i = 1, numRaid do
            tinsert(units, "raid"..i)
        end
        tinsert(units, "player")
    elseif numMembers > 0 then
        tinsert(units, "player")
        for i = 1, numMembers do
            tinsert(units, "party"..i)
        end
    else
        return   -- solo – nothing to show
    end

    local cw, ch = GetCanvasSize()
    local scale   = GetDetailScale()
    local strata  = GetMapStrata()

    -- Compensate icon size so blips stay constant on screen when
    -- Magnify (or any other addon) zooms WorldMapDetailFrame.
    local adjSize     = iconSize / scale
    local adjGlowSize = adjSize * 2

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            -- GetPlayerMapPosition returns x,y in [0,1] if on current map
            local x, y = GetPlayerMapPosition(unit)
            if x and y and x > 0 and y > 0 then

                local blip = customBlips[unit]
                if not blip then
                    blip = CreateFrame("Frame", nil, WorldMapDetailFrame or WorldMapFrame)
                    blip:SetFrameLevel(2000)
                    blip:SetWidth(adjSize)
                    blip:SetHeight(adjSize)

                    -- Glow texture
                    local border = blip:CreateTexture(nil, "OVERLAY")
                    border:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
                    border:SetBlendMode("ADD")
                    border:SetAlpha(0.6)
                    blip.border = border

                    -- Class colour
                    local _, classToken = UnitClass(unit)
                    local color = (classToken and classColorsByToken[classToken]) or {1, 1, 0}
                    border:SetVertexColor(color[1], color[2], color[3])

                    border:SetWidth(adjGlowSize)
                    border:SetHeight(adjGlowSize)
                    border:SetPoint("CENTER", blip, "CENTER", 0, 0)

                    RegisterPulse(border)

                    customBlips[unit] = blip
                else
                    -- Refresh colour & size on existing blip
                    local _, classToken = UnitClass(unit)
                    local color = (classToken and classColorsByToken[classToken]) or {1, 1, 0}
                    blip.border:SetVertexColor(color[1], color[2], color[3])

                    blip:SetWidth(adjSize)
                    blip:SetHeight(adjSize)
                    blip.border:SetWidth(adjGlowSize)
                    blip.border:SetHeight(adjGlowSize)
                end

                -- Match the map's current strata (Magnify changes this)
                blip:SetFrameStrata(strata)

                -- Position: TOPLEFT of the detail frame + fractional offset
                blip:ClearAllPoints()
                blip:SetPoint("CENTER", WorldMapDetailFrame or WorldMapFrame,
                              "TOPLEFT", x * cw, -y * ch)
                blip:Show()
            end
        end
    end
end

-- ── Update ticker ────────────────────────────────────────────
local updateFrame = CreateFrame("Frame")
local UPDATE_INTERVAL  = 0.15
local timeSinceLast    = 0

updateFrame:SetScript("OnUpdate", function()
    local elapsed = arg1
    timeSinceLast = timeSinceLast + elapsed
    if timeSinceLast >= UPDATE_INTERVAL then
        timeSinceLast = 0
        if WorldMapFrame:IsVisible() then
            UpdatePartyIcons()
        end
    end
end)

-- ── Map button ───────────────────────────────────────────────
local function RepositionMapButton()
    if not mapButton then return end
    mapButton:ClearAllPoints()
    -- In 1.12 there is no MaximizeMinimizeFrame; anchor near the
    -- WorldMapFrame close button instead.
    mapButton:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -34, -16)
    -- Keep strata in sync (Magnify changes map strata on maximize/minimize)
    mapButton:SetFrameStrata(GetMapStrata())
end

local function CreateMapButton()
    if mapButton then return end

    mapButton = CreateFrame("Button", "ClassGlowMapIconsMapButton",
                            WorldMapFrame, "UIPanelButtonTemplate")
    mapButton:SetWidth(24)
    mapButton:SetHeight(24)
    mapButton:SetFrameStrata(GetMapStrata())
    RepositionMapButton()

    local icon = mapButton:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    icon:SetAllPoints()
    mapButton.icon = icon

    mapButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Adjust Glow Size", 1, 1, 1)
        GameTooltip:Show()
    end)
    mapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    mapButton:SetScript("OnClick", function()
        if sizeSliderFrame and sizeSliderFrame:IsVisible() then
            sizeSliderFrame:Hide()
        else
            ShowSizeSlider()
        end
    end)
end

-- ── Size-slider panel ────────────────────────────────────────
function ShowSizeSlider()
    if not sizeSliderFrame then
        -- 1.12 does not have BasicFrameTemplateWithInset; roll our own.
        sizeSliderFrame = CreateFrame("Frame", "ClassGlowMapIconsSliderFrame",
                                      UIParent)
        sizeSliderFrame:SetWidth(220)
        sizeSliderFrame:SetHeight(110)
        sizeSliderFrame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile     = true, tileSize = 32, edgeSize = 32,
            insets   = {left=11, right=12, top=12, bottom=11},
        })
        sizeSliderFrame:SetBackdropColor(0, 0, 0, 1)

        if sliderPos.point then
            sizeSliderFrame:SetPoint(sliderPos.point,
                                     sliderPos.relativeTo or "UIParent",
                                     sliderPos.relativePoint,
                                     sliderPos.xOfs, sliderPos.yOfs)
        else
            sizeSliderFrame:SetPoint("CENTER", WorldMapFrame, "CENTER")
        end

        sizeSliderFrame:SetFrameStrata("TOOLTIP")
        sizeSliderFrame:SetFrameLevel(2000)
        sizeSliderFrame:SetMovable(true)
        sizeSliderFrame:EnableMouse(true)
        sizeSliderFrame:RegisterForDrag("LeftButton")
        sizeSliderFrame:SetScript("OnDragStart", function() this:StartMoving() end)
        sizeSliderFrame:SetScript("OnDragStop", function()
            this:StopMovingOrSizing()
            local point, rel, relPoint, x, y = this:GetPoint()
            ClassGlowMapIconsDB.sliderPos = {
                point        = point,
                relativeTo   = rel and rel:GetName() or "UIParent",
                relativePoint = relPoint,
                xOfs = x, yOfs = y,
            }
        end)

        -- Title
        local title = sizeSliderFrame:CreateFontString(nil, "OVERLAY",
                                                       "GameFontNormal")
        title:SetPoint("TOP", sizeSliderFrame, "TOP", 0, -14)
        title:SetText("Adjust Glow Size")

        -- Slider  (OptionsSliderTemplate exists in 1.12)
        local slider = CreateFrame("Slider", "ClassGlowMapIconsSlider",
                                   sizeSliderFrame, "OptionsSliderTemplate")
        slider:SetWidth(170)
        slider:SetHeight(20)
        slider:SetPoint("CENTER", sizeSliderFrame, "CENTER", 0, -10)
        slider:SetMinMaxValues(16, 128)
        slider:SetValueStep(1)
        slider:SetValue(math.floor(iconSize))

        getglobal(slider:GetName().."Low"):SetText("16")
        getglobal(slider:GetName().."High"):SetText("128")
        getglobal(slider:GetName().."Text"):SetText("Size: "..math.floor(iconSize))

        slider:SetScript("OnValueChanged", function()
            local value = math.floor(this:GetValue())
            iconSize = value
            ClassGlowMapIconsDB.iconSize = value
            getglobal(this:GetName().."Text"):SetText("Size: "..value)
            if value > 16 then
                UpdatePartyIcons()
            else
                for _, blip in pairs(customBlips) do
                    blip:Hide()
                end
            end
        end)

        -- Close button
        local closeBtn = CreateFrame("Button", nil, sizeSliderFrame,
                                     "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", sizeSliderFrame, "TOPRIGHT", 1, 1)
        closeBtn:SetScript("OnClick", function() sizeSliderFrame:Hide() end)

    else
        sizeSliderFrame:Show()
        local slider = getglobal("ClassGlowMapIconsSlider")
        if slider then
            slider:SetValue(math.floor(iconSize))
            getglobal(slider:GetName().."Text"):SetText("Size: "..math.floor(iconSize))
        end
    end
end

-- Hide slider when map closes; refresh button strata when map opens
-- (Magnify changes WorldMapFrame strata in its own OnShow handler)
-- 1.12 has no HookScript; manually chain the existing handlers.
local origOnShow = WorldMapFrame:GetScript("OnShow")
WorldMapFrame:SetScript("OnShow", function()
    if origOnShow then origOnShow() end
    RepositionMapButton()
end)
local origOnHide = WorldMapFrame:GetScript("OnHide")
WorldMapFrame:SetScript("OnHide", function()
    if origOnHide then origOnHide() end
    if sizeSliderFrame then sizeSliderFrame:Hide() end
end)

-- ── Event handler ────────────────────────────────────────────
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "CustomPartyGlow" then
        iconSize  = ClassGlowMapIconsDB.iconSize  or 24
        sliderPos = ClassGlowMapIconsDB.sliderPos or {}
    elseif event == "PLAYER_LOGIN" then
        CreateMapButton()
    end
end)

-- ── Slash commands ───────────────────────────────────────────
SLASH_CUSTOMPARTYGLOW1 = "/cpg"
SLASH_CUSTOMPARTYGLOW2 = "/custompartyglow"
SlashCmdList["CUSTOMPARTYGLOW"] = function(msg)
    ShowSizeSlider()
end
