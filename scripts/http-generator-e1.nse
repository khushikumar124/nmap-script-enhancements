local http = require "http"
local shortport = require "shortport"
local stdnse = require "stdnse"

description = [[
Displays the contents of the "generator" meta tag of a web page (default: /)
if there is one.

The meta tag is found whatever the order of its attributes, the quoting of
its values or the case of its name. If a page has several generator meta tags,
all of them are shown. Only the start of the page is searched (up to the end of
<head> or the first 64 KB).
]]

author = "Michael Kohl"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"default", "discovery", "safe"}

---
-- @usage
-- nmap --script http-generator-e1 [--script-args http-generator.path=<path>,http-generator.redirects=<number>,...] <host>
--
-- @output
-- PORT    STATE SERVICE
-- 80/tcp  open  http
-- |_http-generator-e1: TYPO3 4.2 CMS
-- 443/tcp open  https
-- |_http-generator-e1: TYPO3 4.2 CMS
--
-- @output
-- PORT   STATE SERVICE
-- 80/tcp open  http
-- | http-generator-e1: WordPress 6.4
-- |_Elementor 3.18
--
-- @args http-generator.path Specify the path you want to check for a generator meta tag (default to '/').
-- @args http-generator.redirects Specify the maximum number of redirects to follow (defaults to 3).

-- Changelog:
-- 2011-12-23 Michael Kohl <citizen428@gmail.com>:
--   + Initial version
-- 2012-01-10 Michael Kohl <citizen428@gmail.com>:
--   + update documentation
--   + make pattern case insensitive
--   + only follow first redirect
-- 2012-01-11 Michael Kohl <citizen428@gmail.com>:
--   + more generic pattern
--   + simplified matching
-- 2012-01-13 Michael Kohl <citizen428@gmail.com>:
--   + add http-generator.path argument
--   + add http-generator.redirects argument
--   + restructure redirect handling
--   + improve redirect pattern
--   + update documentation
--   + add changelog
-- 2014-07-29 Fabian Affolter <fabian@affolter-engineering.ch>:
--   + update generator pattern
-- 2026-10-13 Khushi Kumar <khushikumar6819@gmail.com>:
--   + read the attributes of every <meta> tag instead of one fixed pattern
--   + report every generator tag found, not only the first

portrule = shortport.http

-- Only the start of the body is searched. Generator tags live in <head>, so the
-- search stops at </head> or after MAX_SCAN bytes, whichever comes first. This
-- keeps the work bounded on very large pages. The same limit is passed to
-- http.get, because a body over the library default (2MB) is otherwise
-- rejected as an error and the stock script then prints nothing.
local MAX_SCAN = 65536

-- Reads the attributes of one <meta ...> tag into a table keyed by lower-case
-- attribute name. Values may be in double quotes, single quotes or unquoted.
local function parse_attributes(tag)
  local attrs = {}
  local pos = tag:find("%s") -- skip "<meta"
  while pos do
    local name, e = tag:match("^%s*([^%s=/>]+)()", pos)
    if not name then
      -- nothing but whitespace, "/" or ">" is left (or a stray "=" or "/")
      local skip = tag:match("^[%s/=]+()", pos)
      if not skip then break end
      pos = skip
    else
      local value
      local vstart = tag:match("^%s*=%s*()", e)
      if vstart then
        local q = tag:sub(vstart, vstart)
        if q == '"' or q == "'" then
          value, pos = tag:match("^" .. q .. "([^" .. q .. "]*)" .. q .. "?()", vstart)
        else
          value, pos = tag:match("^([^%s>]*)()", vstart)
          -- a trailing "/>" belongs to the tag, not to the value
          value = value:gsub("/$", "")
        end
      else
        value, pos = "", e
      end
      attrs[name:lower()] = value
    end
  end
  return attrs
end

-- Returns a list with the content of every generator meta tag in the body.
local function find_generators(body)
  local head = body:sub(1, MAX_SCAN)
  local head_end = head:lower():find("</head", 1, true)
  if head_end then
    head = head:sub(1, head_end - 1)
  end

  local found = {}
  -- %f[%s/>] makes sure the tag name is exactly "meta" (not "metadata")
  for tag in head:gmatch("<[mM][eE][tT][aA]%f[%s/>][^>]*>") do
    local attrs = parse_attributes(tag)
    if attrs.name and attrs.name:lower() == "generator"
      and attrs.content and attrs.content:find("%S") then
      found[#found + 1] = attrs.content
    end
  end
  return found
end

action = function(host, port)
  local path = stdnse.get_script_args('http-generator.path') or '/'
  local redirects = tonumber(stdnse.get_script_args('http-generator.redirects')) or 3

  local response = http.get(host, port, path, {redirect_ok=redirects, max_body_size=MAX_SCAN, truncated_ok=true})
  if ( response and response.body ) then
    local found = find_generators(response.body)
    if #found > 0 then
      -- one tag: exactly the string the stock script printed
      return table.concat(found, "\n")
    end
  end
end
