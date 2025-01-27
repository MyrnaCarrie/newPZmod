require "TimedActions/ISBaseTimedAction"

ISRepairElectricWeaponAction = ISBaseTimedAction:derive("ISRepairElectricWeaponAction")

function ISRepairElectricWeaponAction:isValid()
    return self.character:getPrimaryHandItem() == self.weapon
end

function ISRepairElectricWeaponAction:waitToStart()
    return false
end

function ISRepairElectricWeaponAction:update()
    -- 更新进度条
    self.weapon:setJobDelta(self:getJobDelta())
end

function ISRepairElectricWeaponAction:start()
    -- 设置进度条显示
    self.weapon:setJobDelta(0.0)
    
	    -- 播放开始修理音效
    if ElectricWeaponConfig.GlobalSounds.repair then
        self.character:getEmitter():playSound(ElectricWeaponConfig.GlobalSounds.repair)
    end
	
    -- 播放修理动画
    self:setActionAnim(CharacterActionAnims.Disassemble)
end

function ISRepairElectricWeaponAction:stop()
    -- 重置进度条
    self.weapon:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function ISRepairElectricWeaponAction:perform()
    -- 重置进度条
    self.weapon:setJobDelta(0.0)
    
    -- 修复武器
    if self.weapon and self.weapon:getModData() then
        local modData = self.weapon:getModData()
        modData.malfunctioned = false
        -- 显示修复成功消息
        self.character:Say(getText("UI_ElectricWeapon_RepairSuccess"))
    end
    
    ISBaseTimedAction.perform(self)
end

function ISRepairElectricWeaponAction:new(character, weapon)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.weapon = weapon
    o.maxTime = 50 -- 修理时间（游戏刻）
    o.stopOnWalk = true
    o.stopOnRun = true
    
    -- 如果角色有加速动作的特性
    if character:isTimedActionInstant() then 
        o.maxTime = 1
    end
    
    return o
end

return ISRepairElectricWeaponAction