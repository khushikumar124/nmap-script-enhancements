local http = require "http"
local shortport = require "shortport"
local stdnse = require "stdnse"

description = [[
Displays the contents of the "generator" meta tag of a web page (default: /)
if there is one. The X-Generator HTTP response header is shown too.

The meta tag is found whatever the order of its attributes, the quoting of
its values or the case of its name. If a page has several generator meta tags,
all of them are shown. Only the start of the page is searched (up to the end of
<head> or the first 64 KB).

Both sources come from the single response the script already requests. Each
finding in the structured output records whether it came from a "meta" tag or
the "header".
]]

author = "Michael Kohl"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"default", "discovery", "safe"}

---
-- @usage
-- nmap --script http-generator-e2 [--script-args http-generator.path=<path>,http-generator.redirects=<number>,...] <host>
--
-- @output
-- PORT    STATE SERVICE
-- 80/tcp  open  http
-- |_http-generator-e2: TYPO3 4.2 CMS
-- 443/tcp open  https
-- |_http-generator-e2: TYPO3 4.2 CMS
--
-- @output
-- PORT   STATE SERVICE
-- 80/tcp open  http
-- | http-generator-e2: WordPress 6.4
-- |_Elementor 3.18
--
-- @output
-- PORT   STATE SERVICE
-- 80/tcp open  http
-- | http-generator-e2: Hugo 0.120
-- |_Drupal 10 (https://www.drupal.org) (X-Generator header)
--
-- @xmloutput
-- <table>
--   <elem key="generator">Hugo 0.120</elem>
--   <elem key="source">meta</elem>
-- </table>
-- <table>
--   <elem key="generator">Drupal 10 (https://www.drupal.org)</elem>
--   <elem key="source">header</elem>
-- </table>
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
--   + report the X-Generator response header, with the source of each finding
--   + add structured output

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
  if not response then
    return
  end

  -- each finding: {generator=<value>, source=<"meta" or "header">}
  local findings = {}
  if response.body then
    for _, value in ipairs(find_generators(response.body)) do
      findings[#findings + 1] = {generator=value, source="meta"}
    end
  end

  -- http.lua stores header names in lower case; a repeated header is a table
  local header = response.header["x-generator"]
  if type(header) == "table" then
    header = table.concat(header, ", ")
  end
  if header and header:find("%S") then
    local same
    for _, f in ipairs(findings) do
      if f.generator == header then
        same = f
        break
      end
    end
    if same then
      -- the same value in the tag and the header is listed once
      same.source = "meta, header"
    else
      findings[#findings + 1] = {generator=header, source="header"}
    end
  end

  if #findings == 0 then
    return
  end

  local structured, lines = {}, {}
  for _, f in ipairs(findings) do
    local item = stdnse.output_table()
    item.generator = f.generator
    item.source = f.source
    structured[#structured + 1] = item
    -- meta values are printed bare, as the stock script did; a header-only
    -- value is marked so the text shows where it came from
    if f.source == "header" then
      lines[#lines + 1] = f.generator .. " (X-Generator header)"
    else
      lines[#lines + 1] = f.generator
    end
  end
  return structured, table.concat(lines, "\n")
end
