local addonName, NextCast = ...

_G.NextCast = NextCast
NextCast.name = addonName
NextCast.modules = {}

function NextCast:NewModule(name, module)
    self.modules[name] = module
end

function NextCast:GetModule(name)
    return self.modules[name]
end
