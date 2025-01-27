-- ElectricWeaponContextMenu.lua
-- Author: MyrnaCarrie
-- Date: 2025-01-20 18:32:46

require "ISInsertBatteryAction"
require "ISRemoveBatteryAction"
require "ElectricWeaponConfig"
require "ISElectricWeapon"

ISElectricWeaponContextMenu = {}

-- 获取图标路径的辅助函数
local function getIconPath(iconName)
    return "media/textures/ui/" .. iconName
end

-- 为菜单选项设置图标的辅助函数
local function InventorySetIcon(optionName, iconMethod, iconName, context)
    local option = context:getOptionFromName(getText(optionName))
    if not option then return end
    option.iconTexture = getTexture(iconMethod(iconName))
end

-- 切换电击模式的函数
function ISElectricWeaponContextMenu.onToggleElectricMode(playerObj, weapon)
    if not playerObj or not weapon then return end
    ISElectricWeapon.toggleElectricMode(playerObj:getPlayerNum())
end

-- 查找电池并返回
function ISElectricWeaponContextMenu.findBattery(playerObj)
    local containerList = ISInventoryPaneContextMenu.getContainers(playerObj)
    if not containerList then return nil end
    
    -- 遍历所有容器查找电池
    for i=1, containerList:size() do
        local container = containerList:get(i-1)
        local items = container:getItems()
        for j=0, items:size()-1 do
            local item = items:get(j)
            if item:getFullType() == "Base.Battery" then
                return item
            end
        end
    end
    return nil
end

-- 上下文菜单处理函数
function ISElectricWeaponContextMenu.addBatteryOptions(_player, _context, _items)
    -- 整理物品列表
    local resItems = {}
    for i, v in ipairs(_items) do
        if not instanceof(v, "InventoryItem") then
            for _, it in ipairs(v.items) do
                resItems[it] = true
            end
        else
            resItems[v] = true
        end
    end

    -- 处理每个电击武器物品
    for item, _ in pairs(resItems) do
        -- 检查是否为电击棒
        if ISElectricWeapon.isElectricWeapon(item) then
            local modData = item:getModData()
            if not modData.totalCharge then
                modData.totalCharge = 0
            end

            local playerObj = getSpecificPlayer(_player)

            -- 如果有电量，添加电击模式切换选项
            if modData.totalCharge > 0 and modData.hasBattery then
                local modeText = modData.electricModeOn and 
                    getText("ContextMenu_ElectricWeapon_DeactivateMode") or 
                    getText("ContextMenu_ElectricWeapon_ActivateMode")
                
                local toggleOption = _context:addOption(
                    modeText,
                    playerObj,
                    ISElectricWeaponContextMenu.onToggleElectricMode,
                    item
                )

                -- 添加电量信息的工具提示
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                local chargeLevel = math.floor(modData.totalCharge)
    -- 根据电量设置整个工具提示的颜色
    local description
    if chargeLevel > 65 then
        -- 绿色
        description = string.format("<RGB:0,1,0>%s %d%%", getText("Tooltip_ElectricWeapon_Charge"), chargeLevel)
    elseif chargeLevel > 25 then
        -- 黄色
        description = string.format("<RGB:1,1,0>%s %d%%", getText("Tooltip_ElectricWeapon_Charge"), chargeLevel)
    else
        -- 红色
        description = string.format("<RGB:1,0,0>%s %d%%", getText("Tooltip_ElectricWeapon_Charge"), chargeLevel)
    end
    
    tooltip.description = description
    toggleOption.toolTip = tooltip
                
                -- 设置电击模式图标
                local modeIcon = modData.electricModeOn and "Electric_Mode_On.png" or "Electric_Mode_Off.png"
                InventorySetIcon(modeText, getIconPath, modeIcon, _context)
            end

            -- 电池未满时的选项
            if modData.totalCharge < 100 then
                -- 检查是否能找到电池
                local battery = ISElectricWeaponContextMenu.findBattery(playerObj)
                
                -- 如果武器没有安装电池，显示安装选项
                if not modData.hasBattery then
                    local addBatteryOption = _context:addOption(
                        getText("ContextMenu_ElectricWeapon_AddBattery"), 
                        playerObj, 
                        ISElectricWeaponContextMenu.onAddBattery, 
                        item
                    )

                    -- 设置安装电池选项的图标
                    InventorySetIcon("ContextMenu_ElectricWeapon_AddBattery", getIconPath, "Battery_Plus.png", _context)

                    -- 如果没有电池，显示提示并禁用选项
                    if not battery then
                        addBatteryOption.notAvailable = true
                        local tooltip = ISInventoryPaneContextMenu.addToolTip()
                        tooltip.description = getText("ContextMenu_ElectricWeapon_NoBattery")
                        addBatteryOption.toolTip = tooltip
                    end
                end
            end

            -- 如果有电量，显示移除电池选项
            if modData.totalCharge > 0 then
                local removeBatteryOption = _context:addOption(
                    getText("ContextMenu_ElectricWeapon_RemoveBattery"), 
                    playerObj, 
                    ISElectricWeaponContextMenu.onRemoveBattery, 
                    item
                )

                -- 设置移除电池选项的图标
                InventorySetIcon("ContextMenu_ElectricWeapon_RemoveBattery", getIconPath, "Battery_Minus.png", _context)
            end
        end
    end
end

-- 添加电池的回调函数
function ISElectricWeaponContextMenu.onAddBattery(playerObj, weapon)
    if not playerObj or not weapon then return end
    
    -- 查找电池
    local battery = ISElectricWeaponContextMenu.findBattery(playerObj)
    if not battery then 
        -- 如果没找到电池,显示提示
        playerObj:Say(getText("IGUI_PlayerText_NoBattery"))
        return 
    end
    
    -- 如果电池不在玩家背包,先转移
    if battery:getContainer() ~= playerObj:getInventory() then
        -- 确保容器有效
        if not battery:getContainer() or not battery:getContainer():isExistYet() then
            return
        end
        
        -- 添加转移动作
        local transferAction = ISInventoryTransferAction:new(
            playerObj,
            battery,
            battery:getContainer(),
            playerObj:getInventory(),
            nil
        )
        
        -- 在转移完成后再添加安装动作
        transferAction:setOnComplete(function()
            ISTimedActionQueue.add(ISInsertBatteryAction:new(playerObj, weapon, battery))
        end)
        
        -- 添加转移动作
        ISTimedActionQueue.add(transferAction)
    else
        -- 如果电池已经在背包中,直接添加安装动作
        ISTimedActionQueue.add(ISInsertBatteryAction:new(playerObj, weapon, battery))
    end
end

-- 移除电池的回调函数
function ISElectricWeaponContextMenu.onRemoveBattery(playerObj, weapon)
    if not playerObj or not weapon then return end
    ISTimedActionQueue.add(ISRemoveBatteryAction:new(playerObj, weapon))
end

-- 注册上下文菜单事件
Events.OnFillInventoryObjectContextMenu.Add(ISElectricWeaponContextMenu.addBatteryOptions)

return ISElectricWeaponContextMenu