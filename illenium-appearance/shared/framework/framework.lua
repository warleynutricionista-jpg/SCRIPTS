Framework = {}

function Framework.ESX()
    return GetResourceState('es_extended') ~= 'missing'
end

-- True for both qb-core and qbx_core.
-- qbx_core ships a qb-core compatibility bridge so qb-core is typically
-- also "started" on Qbox, but we check both to be safe.
function Framework.QBCore()
    return GetResourceState('qb-core')  ~= 'missing'
        or GetResourceState('qbx_core') ~= 'missing'
end

function Framework.Ox()
    return GetResourceState('ox_core') ~= 'missing'
end
