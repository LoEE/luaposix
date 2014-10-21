--[[
 POSIX library for Lua 5.1/5.2.
 (c) Gary V. Vaughan <gary@vaughan.pe>, 2013-2014
 (c) Reuben Thomas <rrt@sc3d.org> 2010-2013
 (c) Natanael Copa <natanael.copa@gmail.com> 2008-2010
]]
--[[--
 Legacy Lua POSIX bindings.

 Undocumented Legacy APIs for compatibility with previous releases.

 @module posix.compat
]]


local function argerror (name, i, extramsg, level)
  level = level or 1
  local s = string.format ("bad argument #%d to '%s'", i, name)
  if extramsg ~= nil then
    s = s .. " (" .. extramsg .. ")"
  end
  error (s, level + 1)
end

local function toomanyargerror (name, expected, got, level)
  level = level or 1
  local fmt = "no more than %d argument%s expected, got %d"
  argerror (name, expected + 1,
            fmt:format (expected, expected > 1 and "s" or "", got), level + 1)
end

local function argtypeerror (name, i, expect, actual, level)
  level = level or 1
  local fmt = "%s expected, got %s"
  argerror (name, i,
            fmt:format (expect, type (actual):gsub ("nil", "no value")), level + 1)
end

local function badoption (name, i, what, option)
  local fmt = "invalid %s option '%s'"
  argerror (name, i, fmt:format (what, option), 2)
end

local function checkstring (name, i, actual)
  if type (actual) ~= "string" then
    argtypeerror (name, i, "string", actual, 2)
  end
  return actual
end

local function checktable (name, i, actual)
  if type (actual) ~= "table" then
    argtypeerror (name, i, "table", actual, 2)
  end
  return actual
end

local function optstring (name, i, actual, def)
  if actual ~= nil and type (actual) ~= "string" then
    argtypeerror (name, i, "string or nil", actual, 2)
  end
  return actual or def
end


local M = {
  argerror        = argerror,
  argtypeerror    = argtypeerror,
  badoption       = badoption,
  checkstring     = checkstring,
  checktable      = checktable,
  optstring       = optstring,
  toomanyargerror = toomanyargerror,
}


-- Create a file.
-- This function is obsoleted by @{posix.fcntl.open} with `posix.O_CREAT`.
-- @function creat
-- @string path name of file to create
-- @string mode permissions with which to create file
-- @treturn[1] int file descriptor of file at *path*, if successful
-- @return[2] nil
-- @treturn[2] string error message
-- @see creat(2)
-- @see posix.sys.stat.chmod
-- @usage
--   fd = P.creat ("data", "rw-r-----")

local fcntl = require "posix.fcntl"
local bit   = bit32 or require "bit"

local creat_flags = bit.bor (fcntl.O_CREAT, fcntl.O_WRONLY, fcntl.O_TRUNC)

local open = fcntl.open

local function creat (path, mode)
  return open (path, creat_flags, mode)
end

if _DEBUG ~= false then
  M.creat = function (...)
    local argt = {...}
    checkstring ("creat", 1, argt[1])
    checkstring ("creat", 2, argt[2])
    if #argt > 2 then toomanyargerror ("creat", 2, #argt) end
    return creat (...)
  end
else
  M.creat = creat
end


--- Match a filename against a shell pattern.
-- @function fnmatch
-- @string pat shell pattern
-- @string name filename
-- @return true or false
-- @raise error if fnmatch failed
-- @see posix.fnmatch.fnmatch

local fnm = require "posix.fnmatch"

function M.fnmatch (...)
  local r = fnm.fnmatch (...)
  if r == 0 then
    return true
  elseif r == fnm.FNM_NOMATCH then
    return false
  end
  error "fnmatch failed"
end


--- Group information.
-- @table group
-- @string name name of group
-- @int gid unique group id
-- @string ... list of group members


--- Information about a group.
-- @function getgroup
-- @tparam[opt=current group] int|string group id or group name
-- @treturn group group information
-- @usage
--   print (P.getgroup (P.getgid ()).name)

local grp    = require "posix.grp"
local unistd = require "posix.unistd"

local getgrgid, getgrnam = grp.getgrgid, grp.getgrnam
local getegid = unistd.getegid

local function getgroup (grp)
  if grp == nil then grp = getegid () end

  local g
  if type (grp) == "number" then
    g = getgrgid (grp)
  elseif type (grp) == "string" then
    g = getgrnam (grp)
  else
    argtypeerror ("getgroup", 1, "string, int or nil", grp)
  end

  if g ~= nil then
    return {name=g.gr_name, gid=g.gr_gid, mem=g.gr_mem}
  end
end

if _DEBUG ~= false then
  M.getgroup = function (...)
    local argt = {...}
    if #argt > 1 then toomanyargerror ("getgroup", 1, #argt) end
    return getgroup (...)
  end
else
  M.getgroup = getgroup
end


--- Get the password entry for a user.
-- @function getpasswd
-- @tparam[opt=current user] int|string user name or id
-- @string ... field names, each one of "uid", "name", "gid", "passwd",
--   "dir" or "shell"
-- @return ... values, or a table of all fields if *user* is `nil`
-- @usage for a,b in pairs (P.getpasswd "root") do print (a, b) end
-- @usage print (P.getpasswd ("root", "shell"))

local pwd    = require "posix.pwd"
local unistd = require "posix.unistd"

local getpwnam, getpwuid = pwd.getpwnam, pwd.getpwuid
local geteuid = unistd.geteuid

local function getpasswd (user, ...)
  if user == nil then user = geteuid () end

  local p
  if type (user) == "number" then
    p = getpwuid (user)
  elseif type (user) == "string" then
    p = getpwnam (user)
  else
    argtypeerror ("getpasswd", 1, "string, int or nil", user)
  end

  if p ~= nil then
    local argt = {...}

    if not (next (argt)) then
      return {
	dir    = p.pw_dir,
	gid    = p.pw_gid,
	name   = p.pw_name,
	passwd = p.pw_passwd,
	shell  = p.pw_shell,
	uid    = p.pw_uid,
      }
    else
      local r = {}
      for i, v in ipairs (argt) do
        if     v == "dir"    then r[#r + 1] = p.pw_dir
        elseif v == "gid"    then r[#r + 1] = p.pw_gid
        elseif v == "name"   then r[#r + 1] = p.pw_name
        elseif v == "passwd" then r[#r + 1] = p.pw_passwd
        elseif v == "shell"  then r[#r + 1] = p.pw_shell
        elseif v == "uid"    then r[#r + 1] = p.pw_uid
        else
	  M.argerror ("getpasswd", i + 1, "invalid option '" .. v .. "'")
        end
      end
      return unpack (r)
    end
  end
end

if _DEBUG ~= false then
  M.getpasswd = function (user, ...)
    for i, v in ipairs {...} do
      checkstring ("getpasswd", i + 1, v)
    end
    return getpasswd (user, ...)
  end
else
  M.getpasswd = getpasswd
end


--- Get process identifiers.
-- @function getpid
-- @tparam[opt] table|string type one of "egid", "euid", "gid", "uid",
--   "pgrp", "pid" or "ppid"; or a single list of the same
-- @string[opt] ... unless *type* was a table, zero or more additional
--   type strings
-- @return ... values, or a table of all fields if no option given
-- @usage for a,b in pairs (P.getpid ()) do print (a, b) end
-- @usage print (P.getpid ("uid", "euid"))

local unistd = require "posix.unistd"

local getegid, geteuid, getgid, getuid =
  unistd.getegid, unistd.geteuid, unistd.getgid, unistd.getuid
local _getpid, getpgrp, getppid =
  unistd.getpid, unistd.getpgrp, unistd.getppid

local function getpid (...)
  local argt = {...}
  if type (argt[1]) == "table" then argt = argt[1] end

  if not (next (argt)) then
    return {
      egid = getegid (),
      euid = geteuid (),
      gid  = getgid (),
      uid  = getuid (),
      pgrp = getpgrp (),
      pid  = _getpid (),
      ppid = getppid (),
      }
  else
    local r = {}
    for i, v in ipairs (argt) do
      if     v == "egid" then r[#r + 1] = getegid ()
      elseif v == "euid" then r[#r + 1] = geteuid ()
      elseif v == "gid"  then r[#r + 1] = getgid ()
      elseif v == "uid"  then r[#r + 1] = getuid ()
      elseif v == "pgrp" then r[#r + 1] = getpgrp ()
      elseif v == "pid"  then r[#r + 1] = _getpid ()
      elseif v == "ppid" then r[#r + 1] = getppid ()
      else
	M.argerror ("getpid", i, "invalid option '" .. v .. "'")
      end
    end
    return unpack (r)
  end
end

if _DEBUG ~= false then
  M.getpid = function (t, ...)
    local argt = {t, ...}
    if type (t) == "table" and #argt > 1 then
      toomanyargerror ("getpid", 1, #argt)
    elseif t ~= nil and type (t) ~= "string" then
      argtypeerror ("getpid", 1, "table, string or nil", t)
    end
    for i = 2, #argt do
      checkstring ("getpid", i, argt[i])
    end
    return getpid (t, ...)
  end
else
  M.getpid = getpid
end


--- Get host id.
-- @function hostid
-- @treturn int unique host identifier

local unistd = require "posix.unistd"

M.hostid = unistd.gethostid


--- Get time of day.
-- @function gettimeofday
-- @treturn timeval time elapsed since *epoch*
-- @see gettimeofday(2)

local systime = require "posix.sys.time"

local gettimeofday = systime.gettimeofday

function M.gettimeofday (...)
  local tv = gettimeofday (...)
  return { sec = tv.tv_sec, usec = tv.tv_usec }
end


--- Check for any printable character except space.
-- @function isgraph
-- @see isgraph(3)
-- @string character to act on
-- @treturn bool non-`false` if character is in the class

local ctype = require "posix.ctype"

local isgraph = ctype.isgraph

function M.isgraph (...)
  return isgraph (...) ~= 0
end


--- Check for any printable character including space.
-- @function isprint
-- @string character to act on
-- @treturn bool non-`false` if character is in the class
-- @see isprint(3)

local ctype = require "posix.ctype"

local isprint = ctype.isprint

function M.isprint (...)
  return isprint (...) ~= 0
end


--- Return information about this machine.
-- @function uname
-- @see uname(2)
-- @string[opt="%s %n %r %v %m"] format contains zero or more of:
--
-- * %m  machine name
-- * %n  node name
-- * %r  release
-- * %s  sys name
-- * %v  version
--
--@treturn[1] string filled *format* string, if successful
--@return[2] nil
--@treturn string error message

local utsname = require "posix.sys.utsname"

local _uname = utsname.uname

local function uname (spec)
  local u = _uname ()
  return optstring ("uname", 1, spec, "%s %n %r %v %m"):gsub ("%%(.)", function (s)
    if s == "%" then return "%"
    elseif s == "m" then return u.machine
    elseif s == "n" then return u.nodename
    elseif s == "r" then return u.release
    elseif s == "s" then return u.sysname
    elseif s == "v" then return u.version
    else
      badoption ("uname", 1, "format", s)
    end
  end)
end

if _DEBUG ~= false then
  M.uname = function (s, ...)
    local argt = {s, ...}
    if #argt > 1 then
      toomanyargerror ("uname", 1, #argt)
    end
    return uname (s)
  end
else
  M.uname = uname
end


return M