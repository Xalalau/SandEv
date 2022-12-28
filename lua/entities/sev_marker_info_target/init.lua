-- A target position

ENT.Base = "base_entity"
ENT.Type = "brush"

function ENT:Setup(base, eventName, entName, vec, vecConnection)
    self:Spawn()

    local vecA = vec + Vector(5, 5, 10)
    local vecB = vec - Vector(5, 5, 0)

    self:SetVar("eventName", eventName)
    self:SetVar("entName", entName)
    self:SetVar("vecA", vecA)
    self:SetVar("vecB", vecB)
    self:SetVar("vecCenter", vec + Vector(0, 0, 5))
    self:SetVar("color", Color(3, 252, 152, 255)) -- Some green
    self:SetVar("vecConnection", vecConnection)

    self:SetName(entName)
    self:SetPos(vec)

    self:SetSolid(FSOLID_NOT_SOLID)

    base.Event:SetRenderInfoEntity(self)
end