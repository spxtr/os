pms = {}

-- TODO: Use love.data, introduced in 11.0.
-- Some of these functions are from http://lua-users.org/wiki/ReadWriteFormat

local function newStringBuf(str)
  return {pos=1, str=str}
end

local function readInt8(buf)
  buf.pos = buf.pos + 1
  return string.byte(buf.str, buf.pos - 1)
end

local function readInt16(buf)
  local b0, b1 = string.byte(buf.str, buf.pos, buf.pos + 1)
  buf.pos = buf.pos + 2
  return b0 + b1*2^8
end

local function readInt32(buf)
  local b0, b1, b2, b3 = string.byte(buf.str, buf.pos, buf.pos + 3)
  buf.pos = buf.pos + 4
  return b0 + b1*2^8 + b2*2^16 + b3*2^24
end

-- Strings are one byte at the start for length followed by a fixed length of
-- data.
local function readString(buf, max)
  local len = string.byte(buf.str, buf.pos)
  local ret = string.sub(buf.str, buf.pos + 1, buf.pos + len)
  buf.pos = buf.pos + max + 1
  return ret
end

local function readColor(buf)
  local b0, b1, b2, b3 = string.byte(buf.str, buf.pos, buf.pos + 3)
  buf.pos = buf.pos + 4
  return {b2/255.0, b1/255.0, b0/255.0, b3/255.0} -- Yes, that's right: BGRA.
end

local function readFloat32(buf)
  local b4, b3, b2, b1 = string.byte(buf.str, buf.pos, buf.pos + 3)
  buf.pos = buf.pos + 4
  local exponent = (b1 % 128) * 2 + math.floor(b2 / 128)
  if exponent == 0 then return 0 end
  local sign = (b1 > 127) and -1 or 1
  local mantissa = ((b2 % 128) * 256 + b3) * 256 + b4
  mantissa = (math.ldexp(mantissa, -23) + 1) * sign
  return math.ldexp(mantissa, exponent - 127)
end

local function skip(buf, amnt)
  buf.pos = buf.pos + amnt
end

function pms.load(path)
  local f = assert(io.open(path, "r"))
  local contents = f:read("*all")
  f:close()

  local buf = newStringBuf(contents)
  local map = {}

  -- PMS files start with a version.
  if readInt32(buf) ~= 11 then
    error("bad magic number")
  end
  -- Options.
  map.name = readString(buf, 38)
  map.texture = readString(buf, 24)
  map.bgTop = readColor(buf)
  map.bgBot = readColor(buf)
  map.jets = readInt32(buf)
  map.nades = readInt8(buf)
  map.meds = readInt8(buf)
  map.weather = readInt8(buf)
  map.steps = readInt8(buf)
  -- Then a random int32 that we can ignore.
  readInt32(buf)
  -- Polygons.
  map.minX = math.huge
  map.minY = math.huge
  map.maxX = -math.huge
  map.maxY = -math.huge
  map.polygons = {}
  map.vertMesh = {}
  for i=1,readInt32(buf) do
    local poly = {vertices={}, perps={}, lengths={}}
    for j=1,3 do
      local vertex = {}
      vertex.x = readFloat32(buf)
      vertex.y = readFloat32(buf)
      vertex.z = readFloat32(buf)
      vertex.rhw = readFloat32(buf)
      vertex.color = readColor(buf)
      vertex.tu = readFloat32(buf)
      vertex.tv = readFloat32(buf)
      table.insert(poly.vertices, vertex)
      table.insert(map.vertMesh, {
        vertex.x, vertex.y,
        vertex.tu, vertex.tv,
        vertex.color[1], vertex.color[2], vertex.color[3], vertex.color[4]
      })
      if vertex.x < map.minX then map.minX = vertex.x end
      if vertex.x > map.maxX then map.maxX = vertex.x end
      if vertex.y < map.minY then map.minY = vertex.y end
      if vertex.y > map.maxY then map.maxY = vertex.y end
    end
    for j=1,3 do
      local perp = {}
      perp.x = readFloat32(buf)
      perp.y = readFloat32(buf)
      perp.z = readFloat32(buf)
      table.insert(poly.perps, perp)
    end
    for j=1,3 do
      table.insert(poly.lengths, math.sqrt((poly.vertices[j].x - poly.vertices[j%3 + 1].x)^2 + (poly.vertices[j].y - poly.vertices[j%3 + 1].y)^2))
    end
    poly.type = readInt8(buf)
    table.insert(map.polygons, poly)
  end
  -- Sectors. Ignored.
  readInt32(buf)
  local sectors = readInt32(buf)
  for i=1,2*sectors + 1 do
    for j=1,2*sectors + 1 do
      skip(buf, readInt16(buf) * 2)
    end
  end
  -- Props. In PMS-land, each prop is an instance of a scenery. The style of
  -- the prop is the scenery index.
  map.props = {}
  for i=1,readInt32(buf) do
    if readInt8(buf) == 0 then skip(buf, 43) end
    skip(buf, 1)
    local prop = {}
    prop.style = readInt16(buf)
    -- Why is there width/height as well as scale x/y?
    prop.width = readInt32(buf)
    prop.height = readInt32(buf)
    prop.x = readFloat32(buf)
    prop.y = readFloat32(buf)
    prop.r = -readFloat32(buf) -- Reversed, for some reason.
    prop.sx = readFloat32(buf)
    prop.sy = readFloat32(buf)
    -- For some reason there is a separate alpha byte. Let me know if you know
    -- why this is. For now I'm using it rather than that in the color struct.
    local a = readInt8(buf) / 255.0
    skip(buf, 3)
    prop.color = readColor(buf)
    prop.color[4] = a
    prop.level = readInt8(buf)
    skip(buf, 3)
    table.insert(map.props, prop)
  end
  -- Scenery.
  map.scenery = {}
  for i=1,readInt32(buf) do
    table.insert(map.scenery, readString(buf, 50))
    skip(buf, 4)
  end
  return map
end

return pms
