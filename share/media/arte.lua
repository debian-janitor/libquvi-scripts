-- libquvi-scripts v0.9.20131012
-- Copyright (C) 2012-2013  Toni Gundogdu <legatvs@gmail.com>
-- Copyright (C) 2011  Raphaël Droz <raphael.droz+floss@gmail.com>
--
-- This file is part of libquvi-scripts <http://quvi.sourceforge.net/>.
--
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU Affero General Public
-- License as published by the Free Software Foundation, either
-- version 3 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General
-- Public License along with this program.  If not, see
-- <http://www.gnu.org/licenses/>.
--

-- NOTE: Most videos expire some (7?) days after their original broadcast

local Arte = {} -- Utility functions unique to to this script.

-- Identify the media script.
function ident(qargs)
  return {
    can_parse_url = Arte.can_parse_url(qargs),
    domains = table.concat({'videos.arte.tv'}, ',')
  }
end

-- Parse media properties.
function parse(qargs)
  local L = require 'quvi/lxph'
  local P = require 'lxp.lom'

  -- Config data ('c') contains config data for each available language.
  -- Each language consists of >0 media streams, e.g. 'hd', 'sd'.

  local c,lang_code = Arte.get_config(qargs, L)
  qargs.streams,S = Arte.iter_streams(c, L, P, lang_code)

  -- Many of the optional properties depend on the language setting.
  -- e.g. title, even the media ID. Have these parsed _after_ the
  -- streams have been parsed.

  Arte.opt_properties(qargs, lang_code);

  return qargs
end

--
-- Utility functions
--

function Arte.can_parse_url(qargs)
  local U = require 'socket.url'
  local t = U.parse(qargs.input_url)
  if t and t.scheme and t.scheme:lower():match('^http$')
       and t.host   and t.host:lower():match('^videos%.arte%.tv$')
       and t.path   and t.path:lower():match('^/%w+/videos/')
  then
    return true
  else
    return false
  end
end

function Arte.get_config(qargs, L)

  -- Collect all config data for all available (language) streams.
  -- Return a list containing the config dictionaries, and the language
  -- code which will be used to select the default and the best streams.

  local p = quvi.http.fetch(qargs.input_url).data

  local u = p:match('videorefFileUrl = "(.-)"')
              or error('no match: config URL')

  local l = u:match('%.tv/(%w+)/') or error('no match: lang code')

  local c = quvi.http.fetch(u).data
  local x = lxp.lom.parse(c)
  local v = L.find_first_tag(x, 'videos')
  local r = {}

  for i=1, #v do -- For each language in the config.
    if v[i].tag == 'video' then
      local d = quvi.http.fetch(v[i].attr['ref'], o).data
      local t = {
        lang_code = v[i].attr['lang'],
        lang_data = d
      }
      -- Make the stream the first in the list if the language codes
      -- match, making it the new default stream.
      table.insert(r, ((t.lang_code == l) and 1 or #t), t)
    end
  end

  return r, l
end

function Arte.opt_properties(qargs, lang_code)

  -- The first stream should now be the default stream. This should
  -- apply to the 'best' stream also, they are both the first streams
  -- in the stream list.

  local r = qargs.streams[1]
  qargs.thumb_url = r.nostd.thumb_url
  qargs.title = r.nostd.title
  qargs.id = r.nostd.id
end

function Arte.iter_streams(config, L, P, lang_code)
  local S = require 'quvi/stream'
  local T = require 'quvi/time'
  local r = {}

  for _,v in pairs(config) do -- For each language in the config.
    local c = P.parse(v.lang_data)

    local d = L.find_first_tag(c, 'dateExpiration')[1]
    if Arte.has_expired(d, T) then
      error('media no longer available (expired)')
    end

    local urls = L.find_first_tag(c, 'urls')

    for i=1, #urls do
      if urls[i].tag == 'url' then
        local t = S.stream_new(urls[i][1])

        -- Save the property values that may be used later, these depend
        -- on the language setting. Many of these are the so called
        -- "optional media properties".  The 'nostd' dictionary is used
        -- only by this script. libquvi ignores it completely.

        t.nostd = {
          thumb_url = L.find_first_tag(c, 'firstThumbnailUrl')[1],
          title = L.find_first_tag(c, 'name')[1],
          quality = urls[i].attr['quality'],
          lang_code = c.attr['lang'],
          id = c.attr['id'] or ''
        }
        t.id = Arte.to_id(t)
        table.insert(r, t)
      end
    end
  end

  if #r >1 then
    Arte.ch_best(S, r, lang_code)
  end

  return r,S
end

function Arte.has_expired(s, T)
  return (T.to_timestamp(s) - os.time()) <0
end

function Arte.ch_best(S, t, lang_code)
  local r = t[1] -- Make the first one the 'best' by default.
  r.flags.best = true
  for _,v in pairs(t) do  -- Whatever matches 'hd' first.
    if v.id:match('hd') and v.nostd.lang_code == lang_code then
      r = S.swap_best(r, v)
    end
  end
end

-- Return an ID for a stream.
function Arte.to_id(t)
  return string.format("%s_%s", t.nostd.quality, t.nostd.lang_code)
end

-- vim: set ts=2 sw=2 tw=72 expandtab:
