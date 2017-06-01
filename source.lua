--- A Source for Cloudant
local json = require 'cjson'
local request = require 'http.request'

local Source = { 
  database = nil, 
  username = nil,
  password = nil,
  url = nil
}

--- A Source for Cloudant
-- @param database The name of the database file. Use ':memory:' for a temporary db
-- @usage local source = Source:new{url='https://account.cloudant.com', username='user', password='pass', database="routes"}
-- @return table
function Source:new(tbl) 
  tbl = tbl or {}
  setmetatable(tbl, self)
  self.__index = self
  assert(tbl.database)
  assert(tbl.url)

  -- TODO: figure out how sessions work
  local match = string.match(tbl.url, '(https://)([^:@]+)')
  if match and tbl.username and tbl.password then
    tbl.url = match[1] .. tbl.username .. ':' .. tbl.password .. '@' .. match[2]
  end

  if string.sub(tbl.url, -1) ~= '/' then
    tbl.url = tbl.url .. '/'
  end

  return tbl
end

function Source:emit_next()
  local req = request.new_from_uri(string.format('%s%s/_changes?feed=continuous&style=main_only&include_docs=true&timeout=0', self.url, self.database))
  local headers, stream = req:go()

  local index = 1

  while true do
    
    local line = stream:get_body_until('\n', true, false)
    if not line then break end
    if line ~= '' then
      local row = json.decode(line) 
      if row.last_seq then 
        coroutine.yield(index, {last_seq=row.last_seq})
        break 
      end
      coroutine.yield(index, row)
      index = index + 1
    end
  end
end

--- Co-routine for listing all documents
function Source:emit()
  return coroutine.wrap(function() self:emit_next() end)
end

return Source