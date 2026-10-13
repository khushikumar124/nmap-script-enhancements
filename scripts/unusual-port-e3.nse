local datafiles = require "datafiles"
local nmap = require "nmap"
local shortport = require "shortport"
local stdnse = require "stdnse"

description = [[
Compares the detected service on a port against the expected service for that
port number (e.g. ssh on 22, http on 80) and reports deviations. The script
requires that a version scan has been run in order to be able to discover what
service is actually running on each port.

For each deviation the output also shows the service that nmap-services lists
for the port (left out for ports that have their own check), whether the
service name was probed or only taken from the table, and the confidence of
the version detection. A structured table is returned for XML output.
]]

---
-- @usage
-- nmap --script unusual-port-e3 <ip>
--
-- @output
-- 23/tcp open   ssh     OpenSSH 5.8p1 Debian 7ubuntu1 (protocol 2.0)
-- | unusual-port-e3: ssh unexpected on port tcp/23
-- |_expected telnet; detection probed, confidence 10
-- 25/tcp open   smtp    Postfix smtpd
--
-- @xmloutput
-- <elem key="port">23</elem>
-- <elem key="protocol">tcp</elem>
-- <elem key="detected">ssh</elem>
-- <elem key="expected">telnet</elem>
-- <elem key="confidence">10</elem>
-- <elem key="method">probed</elem>
--

author = "Patrik Karlsson"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = { "safe" }


local svc_table

portrule = function()
  local status
  status, svc_table = datafiles.parse_services()
  if not status then
    return false --Can't check if we don't have a table!
  end
  return true
end

hostrule = function() return true end

-- the hostrule is only needed to warn
hostaction = function(host)
  local port, state = nil, "open"
  local is_version_scan = false

  -- iterate over ports and check whether name_confidence > 3 this would
  -- suggest that a version scan has been run
  for _, proto in ipairs({"tcp", "udp"}) do
    repeat
      port = nmap.get_ports(host, port, proto, state)
      if ( port and port.version.name_confidence > 3 ) then
        is_version_scan = true
        break
      end
    until( not(port) )
  end

  -- if no version scan has been run, warn the user as the script requires a
  -- version scan in order to work.
  if ( not(is_version_scan) ) then
    return stdnse.format_output(true, "WARNING: this script depends on Nmap's service/version detection (-sV)")
  end

end

portchecks = {

  ['tcp'] = {
    [113] = function(host, port) return ( port.service == "ident" ) end,
    [445] = function(host, port) return ( port.service == "netbios-ssn" ) end,
    [587] = function(host, port) return ( port.service == "smtp" ) end,
    [593] = function(host, port) return ( port.service == "ncacn_http" ) end,
    [636] = function(host, port) return ( port.service == "ldapssl" ) end,
    [3268] = function(host, port) return ( port.service == "ldap" ) end,
  },

  ['udp'] = {
    [5353] = function(host, port) return ( port.service == "mdns" ) end,
  }

}

servicechecks = {
  ['http'] = function(host, port)
    local service = port.service
    port.service = "unknown"
    local status = shortport.http(host, port)
    port.service = service
    return status
  end,

  -- accept msrpc on any port for now, we might want to limit it to certain
  -- port ranges in the future.
  ['msrpc'] = function(host, port) return true end,

  -- accept ncacn_http on any port for now, we might want to limit it to
  -- certain port ranges in the future.
  ['ncacn_http'] = function(host, port) return true end,
}

portaction = function(host, port)
  local ok = false

  if ( port.version.name_confidence <= 3 ) then
    return
  end
  if ( portchecks[port.protocol][port.number] ) then
    ok = portchecks[port.protocol][port.number](host, port)
  end
  if ( not(ok) and servicechecks[port.service] ) then
    ok = servicechecks[port.service](host, port)
  end
  if ( not(ok) and port.service and
      ( port.service == svc_table[port.protocol][port.number] or
      "unknown" == svc_table[port.protocol][port.number] or
      not(svc_table[port.protocol][port.number]) ) ) then
    ok = true
  end
  if ( not(ok) ) then
    local sentence = ("%s unexpected on port %s/%d"):format(port.service, port.protocol, port.number)

    local out = stdnse.output_table()
    out.port = port.number
    out.protocol = port.protocol
    out.detected = port.service
    -- a port with its own entry in portchecks is judged by that check, not by
    -- the nmap-services name, so no expected service is shown for it
    if not portchecks[port.protocol][port.number] then
      out.expected = svc_table[port.protocol][port.number]
    end
    out.confidence = math.floor(port.version.name_confidence)
    out.method = port.version.service_dtype

    -- the first line is the stock sentence; the detail follows on a second line
    local detail = {}
    if out.expected then
      detail[#detail + 1] = "expected " .. out.expected
    end
    if out.method then
      detail[#detail + 1] = ("detection %s, confidence %d"):format(out.method, out.confidence)
    end
    if #detail > 0 then
      sentence = sentence .. "\n" .. table.concat(detail, "; ")
    end
    return out, sentence
  end
end

local Actions = {
  hostrule = hostaction,
  portrule = portaction
}

-- execute the action function corresponding to the current rule
action = function(...) return Actions[SCRIPT_TYPE](...) end
