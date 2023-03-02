-- Show our tools only in devmode

local function HandleToolCategories()
    if not SEv.Tool.categoriesPanel:IsValid() then
        SEv.Tool.categoriesPanel = nil
        return
    end

    if #SEv.Tool.categoryControllers == 0 then
        local categoryNamesSearch = {}

        for k, instance in ipairs(SEv.Tool.instances) do
            for j, categoryName in ipairs(instance.toolCategories) do
                categoryNamesSearch[categoryName] = instance
            end
        end

        for k, GModCategory in ipairs(SEv.Tool.categoriesPanel:GetChildren()) do
            if GModCategory.Header then
                local GModCategoryName = GModCategory.Header:GetText()

                local instance = categoryNamesSearch[GModCategoryName]
                if instance then
                    table.insert(SEv.Tool.categoryControllers, { derma = GModCategory, instance = instance })
                end
            end
        end
    end

    local isAnyDevModeOn = false
    for k, instance in ipairs(SEv.instances) do
        if instance.devMode then
            isAnyDevModeOn = true
        end
    end

    for k, categoryInfo in ipairs(SEv.Tool.categoryControllers) do
        if not categoryInfo.derma:IsValid() then
            SEv.Tool.categoryControllers = {}
            break
        else
            if categoryInfo.instance.devMode or isAnyDevModeOn and categoryInfo.instance == SEv then
                categoryInfo.derma:Show()
                categoryInfo.derma:DoExpansion(true)
            else
                categoryInfo.derma:Hide()
                categoryInfo.derma:DoExpansion(false)
            end
        end
    end
end

hook.Add("OnSpawnMenuOpen", "sev_deal_with_tools_category", function()
    if SEv.Tool.categoriesPanel then
        HandleToolCategories()
    else
        timer.Create("sev_handle_tools_category", 0.2, 60, function()
            local categoriesPanel = g_SpawnMenu and -- Beautiful
                                    istable(g_SpawnMenu:GetChildren()) and
                                           #g_SpawnMenu:GetChildren() >= 2 and
                                    istable(g_SpawnMenu:GetChildren()[2]:GetChildren()) and
                                           #g_SpawnMenu:GetChildren()[2]:GetChildren() >= 2 and
                                    istable(g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren()) and
                                           #g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren() >= 2 and
                                    istable(g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren()[2]:GetChildren()) and
                                           #g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren()[2]:GetChildren() >= 1 and
                                    istable(g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren()[2]:GetChildren()[1]:GetChildren()) and
                                           #g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren()[2]:GetChildren()[1]:GetChildren() >=2 and
                                    istable(g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren()[2]:GetChildren()[1]:GetChildren()[2]:GetChildren()) and
                                           #g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren()[2]:GetChildren()[1]:GetChildren()[2]:GetChildren() >=2 and
                                    istable(g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren()[2]:GetChildren()[1]:GetChildren()[2]:GetChildren()[2]:GetChildren()) and
                                           #g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren()[2]:GetChildren()[1]:GetChildren()[2]:GetChildren()[2]:GetChildren() >=1 and
                                            g_SpawnMenu:GetChildren()[2]:GetChildren()[2]:GetChildren()[2]:GetChildren()[1]:GetChildren()[2]:GetChildren()[2]:GetChildren()[1]

            if categoriesPanel then
                SEv.Tool.categoriesPanel = categoriesPanel
                timer.Remove("sev_handle_tools_category")
                HandleToolCategories()
            end
        end)
    end
end)

function SEv:RegisterToolCategories(instance)
    if not istable(instance.toolCategories) then return end

    table.insert(SEv.Tool.instances, instance)
end