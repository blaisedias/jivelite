-----------------------------------------------------------------------------
-- platform.lua
-----------------------------------------------------------------------------

--[[
=head1 NAME

jive.util.platform - generic desktop platform implemenetation

=head1 DESCRIPTION

generic desktop platform
This module contains functions which facilitate platform specific
behavioural change with the same core jivelite modules.

A platform specific version of this file replaces the default
generic desktop implementation to get the required behaviour.

=head1 SYNOPSIS

This module implements functionality required for jivelite on desktop OS
platforms, works on linux, windows ....

=cut
--]]

local log   = require("jive.utils.log").logger("jivelite.platform")

-- use ffi as luajit does not appear to support fileno as a method for io objects
local ffi = require("ffi")
ffi.cdef[[int fileno(void *)]]

module(...)

local version = 1.0

-- ========================
--  { visImage interface
-- ======================
function getPersisentStorageRoot(_)
    return nil
end
--  } visImage interface

-- ========================
--  { Process interface
-- ======================
function getfd(_, fh)
    log:debug("getfd return ffi.C.fileno(fh) = ", ffi.C.fileno(fh))
    return ffi.C.fileno(fh)
end
--  } Process interface

-- ========================
--  { System interface
-- ======================
function hasTouch(_, cap)
    local ret_value = cap ~= nil
    log:debug("hasTouch: cap=", cap, " return=", ret_value)
    return ret_value
end
--  } System interface

-- ========================
--  { JiveMain interface
-- ======================
-- brightness control
-- set default brightness values - 
function setDefaultBrightnessValues(_, appletManager)
    log:debug("setDefaultBrightnessValues: NOP, appletManager=", appletManager)
end

-- set reduced brightness
function setReducedBrightness(_)
    log:debug("setReducedBrightness: NOP")
end

-- set normal brightness
function setBrightness(_)
    log:debug("setBrightness: NOP")
end
--  } JiveMain interface for brightness control

-- ========================
-- ScreenSavers interface {
-- ========================
-- return if platform should be treated as local playe
function forceLocalPlayer(_)
    local ret_value = false
    log:debug("forceLocalPlayer: ", ret_value)
    return ret_value
end

-- return if platform allows all actions when screen saver is activated
function screenSaverAllowAllActions(_, appletManager)
    local ret_value = true
    log:debug("screenSaverAllowAllActions: ", ret_value, " appletManager=", appletManager)
    return true
end
-- } ScreenSavers interface

-- platform check
function getVersion(_)
    log:debug("platform implementation version ", version)
    return version
end
