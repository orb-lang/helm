















local Node    = require "espalier/node"
local Grammar = require "espalier/grammar"
local elpatt  = require "espalier/elpatt"
local P, R    = elpatt.P, elpatt.R


































local alpha = R"az" + R"AZ"



local digit = R"09"





local hexdig = digit + R"AF"









local pct_encoded = P"%" * hexdig * hexdig



















local gen_delims = P":" + "/" + "?" + "#" + "[" + "]" + "@"

local sub_delims = P"!" + "$" + "&" + "'" + "(" + ")"
                   + "*" + "+" + "," + ";" + "="

local reserved =  gen_delims + sub_delims















local unreserved = alpha + digit + P"-" + P"." + P"_" + P"~"
























local scheme = alpha * (alpha + digit + "+" + ".")^0






































































local dec_octet = digit
                + digit * digit
                + P"1" * digit * digit
                * P"2" * R"04" * digit
                * P"25" * R"05"

ipv4address = dec_octet * "." * dec_octet * "."
            * dec_octet * "." * dec_octet



ipvfuture = P"v" * hexdig^1 * "." * (unreserved + sub_delims + ":")^1
ipv6address = "NYI"
ip_literal = P"[" *  (ipv6address + ipvfuture) * P"]"








reg_name = (unreserved + pct_encoded + sub_delims)^0


host = ipv4address + ip_literal + reg_name














































































port = digit^0











userinfo = (unreserved + pct_encoded + sub_delims + ":")^0













authority = (userinfo * P"@")^-1 * host *(P":" * port)^-1










































pchar = unreserved + pct_encoded + sub_delims + P"@" + ":"
segment = pchar^0
segment_nz = pchar^1
segment_nz_nc = (unreserved + pct_encoded + sub_delims + P"@")^1



path_abempty = (P"/" * segment)^0
path_absolute = P"/" * (segment_nz * (P"/" * segment)^0)^-1
path_noscheme = segment_nz_nc * (P"/" * segment)^0
path_rootless = segment_nz * (P"/" * segment)^0





path_empty = -pchar



local path = path_empty    -- zero characters

           + path_absolute   -- begins with "/" but not "//"
           + path_noscheme   -- begins with a non-colon segment
           + path_rootless   -- begins with a segment
           + path_abempty    -- begins with "/" or is empty



hier_part = P"//" * authority * path_abempty
          + path_absolute
          + path_rootless
          + path_empty








query = (pchar + P"/" + P"?")^0









fragment = (pchar + P"/" + P"?")^0


















local relative_part = P"//" * authority * path_abempty
                    + path_absolute
                    + path_noscheme
                    + path_empty

local relative_ref = relative_part * (P"?" * query)^-1 * (P"#" * fragment)^-1












local absolute_uri = scheme * P":" * hier_part * (P"?" * query)^-1



local uri = scheme * P":" * hier_part * (P"?" * query)^-1 * (P"#" * fragment)-1































local rfc3968 = { alpha         = alpha,
                  digit         = digit,
                  hexdig        = hexdig,
                  pct_encoded   = pct_encoded,
                  gen_delims    = gen_delims,
                  sub_delims    = sub_delims,
                  reserved      = reserved,
                  unreserved    = unreserved,
                  uri           = uri,
                  hier_part     = hier_part,
                  query         = query,
                  fragment      = fragment,
                  scheme        = scheme,
                  authority     = authority,
                  path_abempty  = path_abempty,
                  path_absolute = path_absolute,
                  path_rootless = path_rootless,
                  userinfo      = userinfo,
                  host          = host,
                  port          = port,
                  ip_literal    = ip_literal,
                  ipv4address   = ipv4address,
                  reg_name      = reg_name,
                  ipv6address   = ipv6address,
                  ipvfuture     = ipvfuture,
                  dec_octet     = dec_octet,
                  path_noscheme = path_noscheme,
                  path          = path,
                  relative_part = relative_part,
                  relative_ref  = relative_ref,
                  absolute_uri  = absolute_uri, }





return rfc3968