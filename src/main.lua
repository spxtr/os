require "pms"

function love.load(arg)
  local dir = arg[2] or "./example"
  local m = arg[3] or "Example.PMS"

  map = pms.load(dir .. "/maps/" .. m)

  bgGrad = gradient{direction="vertical", map.bgTop, map.bgBottom}

  -- Rain will be a big mesh with high texture u and v coords. We can make it
  -- look like it is falling by increasing the v on all vertices. Even better,
  -- lets use two meshes with slightly different properties.
  -- TODO: This comes at a pretty severe performance drop.
  local rainImg = loadImg(dir .. "/sparks-gfx/rain.png")
  rainImg:setWrap("repeat", "repeat")
  -- Use nearest filtering instead of linear. It's simpler and we don't need to
  -- premultiply alpha values in our rain texture.
  rainImg:setFilter("nearest", "nearest")
  rainMesh1 = makeRainMesh(rainImg, 100)
  rainMesh2 = makeRainMesh(rainImg, 50)

  local texture = loadImg(dir .. "/textures/" .. map.texture)
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

  viewport = {x=0, y=0}
end

function love.draw()
  love.graphics.setColor(255, 255, 255)
  love.graphics.push()

  -- Origin at the center of the window.
  love.graphics.translate(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
  -- Scale the window to 800x600. It should not be possible to see farther by
  -- growing the window.
  local scaleW = love.graphics.getWidth() / 800
  local scaleH = love.graphics.getHeight() / 600
  local scale = scaleW
  if scaleH > scaleW then scale = scaleH end
  love.graphics.scale(scale)

  love.graphics.translate(-viewport.x, -viewport.y)

  -- Draw background. It extends 100px out of the boundary of the map.
  love.graphics.draw(bgGrad, map.minX - 100, map.minY - 100, 0.0, map.maxX - map.minX + 200, map.maxY - map.minY + 200)
  -- Draw rain.
  if map.weather == 1 then
    love.graphics.draw(rainMesh2)
    love.graphics.draw(rainMesh1)
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

  love.graphics.pop()
  -- Draw the FPS counter top-right.
  love.graphics.printf("FPS: " .. love.timer.getFPS(), love.graphics.getWidth() - 120, 10, 100, "right")
end

function love.update(dt)
  updateRainMesh(rainMesh1, dt, 0.1, -4.0)
  updateRainMesh(rainMesh2, dt, -0.1, -2.0)
  local vel = 200
  if love.keyboard.isDown("left") then
    viewport.x = viewport.x - vel*dt
  elseif love.keyboard.isDown("right") then
    viewport.x = viewport.x + vel*dt
  end
  if love.keyboard.isDown("up") then
    viewport.y = viewport.y - vel*dt
  elseif love.keyboard.isDown("down") then
    viewport.y = viewport.y + vel*dt
  end
end

-- love.filesystem only loads from a few select places. Because we want to load
-- from outside of these places, we have to use lua's io library. Luckily, it's
-- easy to do this. Unluckily, we lose security and portability guarantees.
function newImg(path)
  local f = assert(io.open(path, "r"))
  local contents = f:read("*all")
  f:close()
  local fdat = love.filesystem.newFileData(contents, path)
  local imgDat = love.image.newImageData(fdat)
  return love.graphics.newImage(imgDat)
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
function greenScreen(img)
  local dat = img:getData()
  dat:mapPixel(function(x, y, r, g, b, a) 
    if r == 0 and g == 255 and b == 0 and a == 255 then
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
        result:setPixel(x, y, color[1], color[2], color[3], color[4] or 255)
    end
    result = love.graphics.newImage(result)
    result:setFilter('linear', 'linear')
    return result
end

function makeRainMesh(img, alpha)
  -- rainScale determines how large each rain image will appear.
  local rainScale = 150
  local rainUScale = (map.maxX - map.minX + 200) / rainScale
  local rainVScale = (map.maxY - map.minY + 200) / rainScale
  local rm = love.graphics.newMesh({
    {map.minX - 100, map.minY - 100, 0, 0, 255, 255, 255, alpha},
    {map.maxX + 100, map.minY - 100, rainUScale, 0, 255, 255, 255, alpha},
    {map.maxX + 100, map.maxY + 100, rainUScale, rainVScale, 255, 255, 255, alpha},
    {map.minX - 100, map.maxY + 100, 0, rainVScale, 255, 255, 255, alpha},
  })
  rm:setTexture(img)
  return rm
end

-- TODO: Don't keep decreasing forever. Occasionally roll back coords to
-- equivalent positions.
function updateRainMesh(rm, dt, vu, vv)
  for i=1,rm:getVertexCount() do
    local oldU, oldV = rm:getVertexAttribute(i, 2)
    local newU, newV = oldU + vu*dt, oldV + vv*dt
    rm:setVertexAttribute(i, 2, newU, newV)
  end
end
