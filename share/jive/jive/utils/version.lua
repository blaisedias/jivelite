module(...)

-- this is source code build version, not jive.JIVE_VERSION
-- which is used for other purposes including communication
-- with LMS
local version="git"

function getBuildVersion()
    return version
end
