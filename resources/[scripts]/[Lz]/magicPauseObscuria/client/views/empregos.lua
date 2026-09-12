local cachedPayload = nil

RegisterNetEvent("escmenu:jobs:payload", function(payload)
  cachedPayload = payload
end)

RegisterNUICallback("getJobsProgress", function(data, cb)
  if Config.JobsEnabled == false then
    cb({ jobs = {}, currentJobId = nil, disabled = true })
    return
  end

  cachedPayload = nil
  TriggerServerEvent("escmenu:jobs:requestProgress")

  CreateThread(function()
    local timeout = GetGameTimer() + 5000
    while cachedPayload == nil and GetGameTimer() < timeout do
      Wait(10)
    end

    cb(cachedPayload or { jobs = {}, currentJobId = nil })
    cachedPayload = nil
  end)
end)

RegisterNUICallback("jobsMark", function(data, cb)
  if Config.JobsEnabled == false then
    cb({ ok = false, disabled = true })
    return
  end

  local jobId = data and data.jobId or nil
  if not jobId then cb({ ok = false }) return end

  for id, job in pairs(Config.Jobs or {}) do
    if tostring(id) == tostring(jobId) then
      local c = job.coords
      if c and c.x and c.y then
        SetNewWaypoint(c.x + 0.0, c.y + 0.0)
      end
      cb({ ok = true })
      return
    end
  end

  cb({ ok = false })
end)
