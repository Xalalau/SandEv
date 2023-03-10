-- Manage detours

SEv_gameCleanUpMap = SEv_gameCleanUpMap or game.CleanUpMap

-- Cleanup

function SEv.Map:IsCleanupBlocked()
    return self.blockCleanup
end

function SEv.Map:BlockCleanup(value)
    self.blockCleanup = value
end

function SEv.Map:BlockEntCleanup(ent, value)
    self.CleanupEntFilter[ent] = value or nil
end

function game.CleanUpMap(dontSendToClients, extraFilters, ...)
    if SEv.Map:IsCleanupBlocked() then return end

    if not istable(extraFilters) then
        extraFilters = {}
    end

    local protectedEntities = {}

    for ent, isBlocked in pairs(SEv.Map.CleanupEntFilter) do
        if ent:IsValid() then
            local classname = ent:GetClass()
            local newClassName = 'sev_cleanup_protection_' .. tostring(ent)

            -- The function checks the "classname" key value on entities. If it finds that value in the filter, then it skips the entity.
            -- So, we change our protected entities' classname key value to something unique and add it to the filter.
            ent:SetKeyValue('classname', newClassName)
            
            extraFilters[#extraFilters + 1] = newClassName
            protectedEntities[ent] = classname
        else
            SEv.Map.CleanupEntFilter[ent] = nil
        end
    end

    SEv_gameCleanUpMap(dontSendToClients, extraFilters, ...)

    -- Return the protected entities' classnames back to their original name
    for ent, classname in pairs(protectedEntities) do
        if ent:IsValid() then
            ent:SetKeyValue('classname', classname)
        end
    end
end
