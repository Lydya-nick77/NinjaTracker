addon.name = 'NinjaTracker';
addon.author = 'Lydya';
addon.version = '1.0';
addon.desc = 'Displays ninja tools in Inventory, remaining Utsusemi shadows, and recast timers.';

require 'common';

local chat = require 'chat';
local imgui = require 'imgui';
local scaling = require 'scaling';
local settings = require 'settings';

local defaults = T{
    font = T{
        visible = true,
        font_height = scaling.scale_f(14),
        position_x = scaling.scale_w(30),
        position_y = scaling.scale_h(200),
        locked = false,
    },
};

local shihei_id = 1179;
local tools = {
    { 1161, 'Uchitake' },       { 2971, 'Inoshishinofuda' },
    { 1164, 'Tsurara' },        { 1194, 'Shinobi-Tabi' },
    { 1167, 'Kawahori-Ogi' },   { 1188, 'Sairui-Ran' },
    { 1170, 'Makibishi' },      { 1185, 'Kaginawa' },
    { 1173, 'Hiraishin' },      { 1182, 'Jusatsu' },
    { 1176, 'Mizu-Deppo' },     { 1191, 'Kodoku' },
};

local shadow_buffs = { [66] = 1, [444] = 2, [445] = 3, [446] = 4 };
local config = settings.load(defaults);
local counts = {};
local next_scan = 0;
local player_id;
local place_window = true;
local position_dirty = false;
local last_position_save = 0;

local function rgb(hex, alpha)
    return {
        tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
        alpha or 1,
    };
end

local color = {
    abyss = rgb('180e0e', 0.94),
    surface1 = rgb('291c1c'),
    surface2 = rgb('321f1f'),
    border = rgb('d2abab', 0.20),
    text = rgb('fff8f8'),
    white = rgb('ffffff'),
    peach = rgb('d2abab'),
    muted = rgb('8a6b6b'),
    royal = rgb('c55151'),
    danger = rgb('e04040'),
    gold = rgb('c5a131'),
    success = rgb('63ba8a'),
};

local theme_colors = {
    { ImGuiCol_WindowBg, color.abyss },
    { ImGuiCol_TitleBg, color.surface1 },
    { ImGuiCol_TitleBgActive, color.surface2 },
    { ImGuiCol_Border, color.border },
    { ImGuiCol_Separator, color.border },
    { ImGuiCol_Text, color.text },
    { ImGuiCol_Button, color.surface2 },
    { ImGuiCol_ButtonHovered, color.royal },
    { ImGuiCol_ButtonActive, color.danger },
    { ImGuiCol_TableRowBg, { 0, 0, 0, 0 } },
    { ImGuiCol_TableRowBgAlt, color.surface1 },
};
local window_padding = { 12, 10 };
local item_spacing = { 8, 5 };
local cell_padding = { 4, 3 };
local title_align = { 0.5, 0.5 };

local function push_theme()
    for _, entry in ipairs(theme_colors) do
        imgui.PushStyleColor(entry[1], entry[2]);
    end
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 8);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, window_padding);
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, item_spacing);
    imgui.PushStyleVar(ImGuiStyleVar_CellPadding, cell_padding);
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 4);
    imgui.PushStyleVar(ImGuiStyleVar_WindowTitleAlign, title_align);
    return #theme_colors;
end

local function update_settings(s)
    if (s ~= nil) then
        config = s;
    end
    place_window = true;
    position_dirty = false;
    settings.save();
end

settings.register('settings', 'settings_update', update_settings);

local function scan_inventory()
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    counts[shihei_id] = 0;
    for _, tool in ipairs(tools) do
        counts[tool[1]] = 0;
    end

    for slot = 1, inventory:GetContainerCountMax(0) do
        local item = inventory:GetContainerItem(0, slot);
        if (item ~= nil and counts[item.Id] ~= nil) then
            counts[item.Id] = counts[item.Id] + item.Count;
        end
    end
end

local function get_shadows()
    local count = 0;
    local buff_id;
    for _, buff in pairs(AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()) do
        if ((shadow_buffs[buff] or 0) > count) then
            count = shadow_buffs[buff];
            buff_id = buff;
        end
    end
    return count, buff_id;
end

local function message(text, is_error)
    print(chat.header(addon.name):append(is_error and chat.error(text) or chat.message(text)));
end

local function cancel_shadows()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party:GetMemberIsActive(0) == 0 or party:GetMemberServerId(0) == 0 or GetPlayerEntity() == nil) then
        message('Cannot cancel shadows without an active player.', true);
        return;
    end
    local _, buff_id = get_shadows();
    if (buff_id == nil) then
        message('No Utsusemi shadows to cancel.');
        return;
    end

    AshitaCore:GetPacketManager():AddOutgoingPacket(0x0F1,
        { 0, 0, 0, 0, buff_id % 256, math.floor(buff_id / 256), 0, 0 });
end

local function text_width(text)
    local width = imgui.CalcTextSize(text);
    if (type(width) == 'table') then
        return width.x or width[1];
    end
    return width;
end

local function draw_recast(recast, spell_id, label)
    local seconds = math.ceil(recast:GetSpellTimer(spell_id) / 60);
    imgui.TextColored(color.peach, label .. ':');
    imgui.SameLine();
    imgui.TextColored(seconds > 0 and color.gold or color.success,
        seconds > 0 and (tostring(seconds) .. 's') or 'Ready');
end

local function draw_tool_count(count)
    imgui.TextColored(count == 0 and color.danger or
        (count < 20 and color.gold or color.text), tostring(count));
end

local function draw_content()
    local count_width = text_width('9999');
    local width = math.max(text_width('Inoshishinofuda') + count_width + 28, 150);
    local row_x = imgui.GetCursorPosX();
    local shadows = get_shadows();
    local shadow_color = shadows == 0 and color.danger or
        (shadows == 1 and color.gold or color.success);
    imgui.TextColored(color.peach, 'UTSUSEMI');
    imgui.SameLine();
    imgui.TextColored(shadow_color, (shadows == 4 and '4+' or tostring(shadows)) .. ' shadows');
    if (shadows > 0) then
        local button_width = text_width('Cancel Shadows') + imgui.GetStyle().FramePadding.x * 2;
        imgui.SameLine(row_x + width * 2 - button_width);
        if (imgui.Button('Cancel Shadows')) then
            cancel_shadows();
        end
    end

    local x, y = imgui.GetCursorScreenPos();
    if (type(x) == 'table') then
        x, y = x.x or x[1], x.y or x[2];
    end
    local list = imgui.GetWindowDrawList();
    local pip_width = (width * 2 - 18) / 4;
    local active_pip_color = imgui.GetColorU32(shadow_color);
    local inactive_pip_color = imgui.GetColorU32(color.surface2);
    for i = 1, 4 do
        local left = x + (i - 1) * (pip_width + 6);
        list:AddRectFilled({ left, y }, { left + pip_width, y + 6 },
            i <= shadows and active_pip_color or inactive_pip_color, 3);
    end
    imgui.Dummy({ width * 2, 10 });
    local recast = AshitaCore:GetMemoryManager():GetRecast();
    draw_recast(recast, 338, 'Ichi');
    imgui.SameLine(row_x + width);
    draw_recast(recast, 339, 'Ni');
    imgui.Separator();
    local flags = bit.bor(ImGuiTableFlags_RowBg, ImGuiTableFlags_SizingFixedFit);
    if (imgui.BeginTable('##ninjatracker_items', 4, flags, { width * 2, 0 })) then
        for i = 1, 2 do
            imgui.TableSetupColumn('##tool' .. i, ImGuiTableColumnFlags_WidthFixed,
                width - count_width - 16, 0);
            imgui.TableSetupColumn('##count' .. i, ImGuiTableColumnFlags_WidthFixed,
                count_width, 0);
        end
        imgui.TableNextRow();
        imgui.TableNextColumn();
        imgui.TextColored(color.white, 'INVENTORY');
        imgui.TableNextColumn();
        imgui.TableNextColumn();
        local shihei_count = counts[shihei_id];
        imgui.TextColored(shihei_count == 0 and color.muted or color.peach, 'Shihei');
        imgui.TableNextColumn();
        draw_tool_count(shihei_count);
        for i, tool in ipairs(tools) do
            if (i % 2 == 1) then
                imgui.TableNextRow();
            end
            local count = counts[tool[1]];
            imgui.TableNextColumn();
            imgui.TextColored(count == 0 and color.muted or color.peach, tool[2]);
            imgui.TableNextColumn();
            draw_tool_count(count);
        end
        imgui.EndTable();
    end
end

local function draw_window(now)
    local colors = push_theme();
    if (place_window) then
        imgui.SetNextWindowPos({ config.font.position_x, config.font.position_y }, ImGuiCond_Always);
        place_window = false;
    end
    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoSavedSettings);
    if (config.font.locked) then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove);
    end
    if (imgui.Begin('NinjaTracker##ninjatracker', nil, flags)) then
        imgui.PushFont(imgui.GetFont(), config.font.font_height);
        draw_content();
        imgui.PopFont();
        local x, y = imgui.GetWindowPos();
        if (type(x) == 'table') then
            x, y = x.x or x[1], x.y or x[2];
        end
        x, y = math.floor(x), math.floor(y);
        if (x ~= config.font.position_x or y ~= config.font.position_y) then
            config.font.position_x, config.font.position_y = x, y;
            position_dirty = true;
        end
        if (position_dirty and now - last_position_save >= 1) then
            settings.save();
            position_dirty = false;
            last_position_save = now;
        end
    end
    imgui.End();
    imgui.PopStyleVar(6);
    imgui.PopStyleColor(colors);
end

local function print_help()
    message('/nt help - Show commands.');
    message('/nt pos <x> <y> - Move the display.');
    message('/nt size <8-40> - Set the font size.');
    message('/nt lock - Toggle dragging.');
    message('/nt show | hide - Set display visibility.');
    message('/nt reload | reset - Reload or reset settings.');
end

ashita.events.register('unload', 'ninjatracker_unload', function ()
    settings.save();
end);

ashita.events.register('command', 'ninjatracker_command', function (e)
    local args = e.command:args();
    local prefix = args[1] and args[1]:lower();
    if (prefix ~= '/nt' and prefix ~= '/ninjatracker') then
        return;
    end
    e.blocked = true;
    local command = args[2] and args[2]:lower() or 'help';
    if ((#args == 1 or #args == 2) and command == 'help') then
        print_help();
        return;
    elseif (#args == 2 and command == 'reload') then
        settings.reload();
        return;
    elseif (#args == 2 and command == 'reset') then
        settings.reset();
        return;
    elseif (#args == 2 and (command == 'show' or command == 'hide')) then
        config.font.visible = command == 'show';
    elseif (#args == 2 and command == 'lock') then
        config.font.locked = not config.font.locked;
        message(config.font.locked and 'Display locked.' or 'Display unlocked; drag to move.');
    elseif (#args == 4 and command == 'pos') then
        local x, y = tonumber(args[3]), tonumber(args[4]);
        if (x == nil or y == nil or x ~= x or y ~= y or
            math.abs(x) == math.huge or math.abs(y) == math.huge) then
            message('Position requires two finite numbers.', true);
            return;
        end
        config.font.position_x = x;
        config.font.position_y = y;
    elseif (#args == 3 and command == 'size') then
        local size = tonumber(args[3]);
        if (size == nil or not (size >= 8 and size <= 40)) then
            message('Font size must be a number from 8 to 40.', true);
            return;
        end
        config.font.font_height = size;
    else
        message('Invalid command. Use /nt help.', true);
        return;
    end
    update_settings();
end);

ashita.events.register('d3d_present', 'ninjatracker_present', function ()
    local party = AshitaCore:GetMemoryManager():GetParty();
    local current_id = party:GetMemberServerId(0);
    if (party:GetMemberIsActive(0) == 0 or current_id == 0 or GetPlayerEntity() == nil) then
        player_id = nil;
        next_scan = 0;
        return;
    end
    if (not config.font.visible) then
        return;
    end

    local now = os.clock();
    if (current_id ~= player_id or now >= next_scan) then
        scan_inventory();
        next_scan = now + 0.25;
        player_id = current_id;
    end
    draw_window(now);
end);
