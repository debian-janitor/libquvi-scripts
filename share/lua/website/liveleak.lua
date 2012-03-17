
-- libquvi-scripts v0.4.3
-- Copyright (C) 2010-2011  Toni Gundogdu <legatvs@gmail.com>
--
-- This file is part of libquvi-scripts <http://quvi.sourceforge.net/>.
--
-- This library is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.
--
-- This library is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
-- 02110-1301  USA
--

local LiveLeak = {} -- Utility functions specific to this script

-- Identify the script.
function ident (self)
    package.path = self.script_dir .. '/?.lua'
    local C      = require 'quvi/const'
    local r      = {}
    r.domain     = "liveleak%.com"
    r.formats    = "default"
    r.categories = C.proto_http
    local U      = require 'quvi/util'
    LiveLeak.normalize(self)
    r.handles    = U.handles(self.page_url,
                    {r.domain}, {"view"}, {"i=[%w_]+"})
    return r
end

-- Query available formats.
function query_formats(self)
    self.formats = 'default'
    return self
end

-- Parse media URL.
function parse (self)
    self.host_id = "liveleak"

    LiveLeak.normalize(self)
    local page   = quvi.fetch(self.page_url)

    local _,_,s = page:find("<title>LiveLeak.com%s+%-%s+(.-)</")
    self.title  = s or error ("no match: media title")

    local _,_,s = self.page_url:find('view%?i=([%w_]+)')
    self.id     = s or error ("no match: media id")

    local _,_,s      = page:find('config: "(.-)"')
    local config_url = s or error ("no match: config")

    local opts       = { fetch_type = 'config' }
    local U          = require 'quvi/util'
    local config     = quvi.fetch (U.unescape(config_url), opts)

    local _,_,s = config:find("<file>(.-)</")
    self.url    = {s or error ("no match: file")}

    return self
end

--
-- Utility functions
--

function LiveLeak.normalize(self)
    if not self.page_url then return self.page_url end

    local U = require 'quvi/url'
    local t = U.parse(self.page_url)

    if not t.path then return self.page_url end

    local i = t.path:match('/e/([_%w]+)')
    if i then
        t.query = 'i=' .. i
        t.path = '/view'
        self.page_url = U.build(t)
    end
end

-- vim: set ts=4 sw=4 tw=72 expandtab:
