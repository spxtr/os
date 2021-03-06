function loadDrawables(dir, map)
  bgGrad = gradient{direction="vertical", map.bgTop, map.bgBottom}

  -- Weather is a big mesh with high texture u and v coords. We can make it
  -- look like it is falling by increasing the v on all vertices. Even better,
  -- use two meshes with slightly different properties.
  local rainImg = love.graphics.newImage(loadImg(dir .. "/sparks-gfx/rain.png"))
  local snowImg = love.graphics.newImage(loadImg(dir .. "/sparks-gfx/snow.png"))
  local sandImg = love.graphics.newImage(loadImg(dir .. "/sparks-gfx/sand.png"))
  -- We'll have tu, tv much larger than 1, so set textures to repeat.
  rainImg:setWrap("repeat", "repeat")
  snowImg:setWrap("repeat", "repeat")
  sandImg:setWrap("repeat", "repeat")
  -- Use nearest filtering instead of linear. It's simpler and we don't need to
  -- premultiply alpha values in our rain texture.
  rainImg:setFilter("nearest", "nearest")
  snowImg:setFilter("nearest", "nearest")
  sandImg:setFilter("nearest", "nearest")

  rainMesh1 = makeWeatherMesh(rainImg, 0.4)
  rainMesh2 = makeWeatherMesh(rainImg, 0.2)
  snowMesh1 = makeWeatherMesh(snowImg, 0.3)
  snowMesh2 = makeWeatherMesh(snowImg, 0.1)
  sandMesh1 = makeWeatherMesh(sandImg, 0.3)
  sandMesh2 = makeWeatherMesh(sandImg, 0.1)

  local texture = love.graphics.newImage(loadImg(dir .. "/textures/" .. map.texture))
  -- Set the texture wrap mode to "repeat" instead of the default "clamp"
  -- which causes artifacts at the edge.
  texture:setWrap("repeat", "repeat")
  -- Use a static mesh to draw the polygons.
  polyMesh = love.graphics.newMesh(map.vertMesh, "triangles", "static")
  polyMesh:setTexture(texture)
  -- Load polygon edges. For this we have to attach a Mesh to a SpriteBatch
  -- which will let us do per-vertex coloring.
  local ok, edgeImg = pcall(loadImg, dir .. "/textures/edges/" .. map.texture)
  if ok then
    edgeImg = greenScreen(edgeImg)
    local edgeH = edgeImg:getHeight()
    local edgeW = edgeImg:getWidth()
    edges = love.graphics.newSpriteBatch(edgeImg, 3 * #map.polygons, "static")
    -- Default Meshes have color, position, and texture coords. These override
    -- the settings from the SpriteBatch, but we only want to override color.
    local edgeMesh = love.graphics.newMesh({{"VertexColor", "byte", 4}}, 4 * edges:getBufferSize(), "fan", "static")
    edges:attachAttribute("VertexColor", edgeMesh)
    for i,poly in pairs(map.polygons) do
      for j=1,3 do
        -- The vertex order is top-left, bottom-left, top-right, bottom-right.
        local lcol = poly.vertices[j].color
        local rcol = poly.vertices[j%3 + 1].color
        local id = 4 * (3*(i - 1) + j - 1)
        edgeMesh:setVertexAttribute(1 + id, 1, lcol[1], lcol[2], lcol[3], lcol[4])
        edgeMesh:setVertexAttribute(2 + id, 1, lcol[1], lcol[2], lcol[3], lcol[4])
        edgeMesh:setVertexAttribute(3 + id, 1, rcol[1], rcol[2], rcol[3], rcol[4])
        edgeMesh:setVertexAttribute(4 + id, 1, rcol[1], rcol[2], rcol[3], rcol[4])
        -- Protrude the edge out from the polygon by scaling its height by -1.
        edges:add(
          poly.vertices[j].x, poly.vertices[j].y,
          math.atan2(poly.perps[j].y, poly.perps[j].x) - math.pi / 2,
          poly.lengths[j] / edgeW, -1.0)
      end
    end
  end

  local sceneryImages = {}
  for k,v in ipairs(map.scenery) do
    sceneryImages[k] = greenScreen(loadImg(dir .. "/scenery-gfx/" .. v))
  end

  -- Level -> Style -> SpriteBatch. From the spec:
  -- 0: Behind everything.
  -- 1: In front of player.
  -- 2: In front of polygons.
  scenery = {[0]={}, {}, {}}
  for k,v in ipairs(map.props) do
    if not scenery[v.level][v.style] then
      scenery[v.level][v.style] = love.graphics.newSpriteBatch(sceneryImages[v.style], 1000, "static")
    end
    scenery[v.level][v.style]:setColor(v.color)
    scenery[v.level][v.style]:add(v.x, v.y, v.r, v.width / sceneryImages[v.style]:getWidth() * v.sx, v.height / sceneryImages[v.style]:getHeight() * v.sy)
  end
end

function draw(map)
  -- Draw background. It extends 100px out of the boundary of the map.
  love.graphics.draw(bgGrad, map.minX - 100, map.minY - 100, 0.0, map.maxX - map.minX + 200, map.maxY - map.minY + 200)
  -- Draw weather.
  if map.weather == 1 then
    love.graphics.draw(rainMesh2)
    love.graphics.draw(rainMesh1)
  elseif map.weather == 2 then
    love.graphics.draw(sandMesh2)
    love.graphics.draw(sandMesh1)
  elseif map.weather == 3 then
    love.graphics.draw(snowMesh2)
    love.graphics.draw(snowMesh1)
  end
  -- Draw scenery in the back.
  for k,v in pairs(scenery[0]) do
    love.graphics.draw(v)
  end
  -- Draw players.
  -- Draw scenery in front of the players.
  for k,v in pairs(scenery[1]) do
    love.graphics.draw(v)
  end
  -- Draw edges. Set a stencil test to prevent drawing behind partially
  -- transparent polygons.
  if edges then
    love.graphics.stencil(function() love.graphics.draw(polyMesh) end)
    love.graphics.setStencilTest("equal", 0)
    love.graphics.draw(edges)
    love.graphics.setStencilTest()
  end
  -- Draw polygons.
  love.graphics.draw(polyMesh)
  -- Draw scenery in front of everything.
  for k,v in pairs(scenery[2]) do
    love.graphics.draw(v)
  end
end

function updateWeather(dt)
  -- TODO: We can be more creative with our x velocities for weather. Some
  -- random gusts would make the snow look really nice.
  updateWeatherMesh(rainMesh1, dt, 0.1, -4.0)
  updateWeatherMesh(rainMesh2, dt, -0.1, -2.0)
  updateWeatherMesh(snowMesh1, dt, 0.1*math.sin(love.timer.getTime() * 2*math.pi*0.23), -0.8)
  updateWeatherMesh(snowMesh2, dt, 0.1*math.sin(love.timer.getTime() * 2*math.pi*0.15), -0.6)
  updateWeatherMesh(sandMesh1, dt, -4.0 - math.sin(love.timer.getTime() * 2*math.pi*0.23), -3.0)
  updateWeatherMesh(sandMesh2, dt, -3.0 - math.sin(love.timer.getTime() * 2*math.pi*0.15), -2.0)
end

-- love.filesystem only loads from a few select places. Because we want to load
-- from outside of these places, we have to use lua's io library. Luckily, it's
-- easy to do this. Unluckily, we lose security and portability guarantees.
-- TODO: Use love.filesystem.
function newImg(path)
  local f = assert(io.open(path, "r"))
  local contents = f:read("*all")
  f:close()
  local fdat = love.filesystem.newFileData(contents, path)
  return love.image.newImageData(fdat)
end

-- Many of Soldat's images can be either .bmp or .png. In general, prefer the
-- .png version.
function loadImg(path)
  local png = path:gsub(".bmp", ".png")
  local ok, img = pcall(newImg, png)
  if ok then
    return img
  end
  local bmp = path:gsub(".png", ".bmp")
  return newImg(bmp)
end

-- Soldat likes to use (0, 255, 0, 255) to indicate transparency.
function greenScreen(dat)
  dat:mapPixel(function(x, y, r, g, b, a) 
    if r == 0 and g == 1.0 and b == 0 and a == 1.0 then
      return 0, 0, 0, 0
    end
    return r, g, b, a
  end)
  return love.graphics.newImage(dat)
end

-- From https://love2d.org/wiki/Gradients
function gradient(colors)
    local direction = colors.direction or "horizontal"
    if direction == "horizontal" then
        direction = true
    elseif direction == "vertical" then
        direction = false
    else
        error("Invalid direction '" .. tostring(direction) .. "' for gradient.  Horizontal or vertical expected.")
    end
    local result = love.image.newImageData(direction and 1 or #colors, direction and #colors or 1)
    for i, color in ipairs(colors) do
        local x, y
        if direction then
            x, y = 0, i - 1
        else
            x, y = i - 1, 0
        end
        result:setPixel(x, y, color[1], color[2], color[3], color[4] or 1.0)
    end
    result = love.graphics.newImage(result)
    result:setFilter('linear', 'linear')
    return result
end

function makeWeatherMesh(img, alpha)
  -- scale determines how large each image will appear in pixels.
  local scale = 150
  local uScale = (map.maxX - map.minX + 200) / scale
  local vScale = (map.maxY - map.minY + 200) / scale
  local m = love.graphics.newMesh({
    {map.minX - 100, map.minY - 100, 0, 0, 1.0, 1.0, 1.0, alpha},
    {map.maxX + 100, map.minY - 100, uScale, 0, 1.0, 1.0, 1.0, alpha},
    {map.maxX + 100, map.maxY + 100, uScale, vScale, 1.0, 1.0, 1.0, alpha},
    {map.minX - 100, map.maxY + 100, 0, vScale, 1.0, 1.0, 1.0, alpha},
  })
  m:setTexture(img)
  return m
end

-- TODO: Don't keep decreasing forever. Occasionally roll back coords to
-- equivalent positions.
function updateWeatherMesh(m, dt, vu, vv)
  for i=1,m:getVertexCount() do
    local oldU, oldV = m:getVertexAttribute(i, 2)
    local newU, newV = oldU + vu*dt, oldV + vv*dt
    m:setVertexAttribute(i, 2, newU, newV)
  end
end
