module(...)

-- this is source code build version, not jive.JIVE_VERSION
-- which is used for other purposes
local version="git"

function getBuildVersion()
    return version
end
