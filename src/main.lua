require "draw"
require "pms"

function love.load(arg)
  local dir = arg[2] or "./example"
  local m = arg[3] or "Example.PMS"

  map = pms.load(dir .. "/maps/" .. m)
  loadDrawables(dir, map)

  viewport = {x=0, y=0}
end

function love.draw()
  love.graphics.setColor(1.0, 1.0, 1.0)
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

  draw(map)

  love.graphics.pop()
  -- Draw the FPS counter top-right.
  love.graphics.printf("FPS: " .. love.timer.getFPS(), love.graphics.getWidth() - 120, 10, 100, "right")
end

function love.update(dt)
  updateWeather(dt)
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
