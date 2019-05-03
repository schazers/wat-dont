Level = Level or {}

Level.dieSound = Level.dieSound or love.audio.newSource('./die.wav', 'static')

function Level:create(layout)
    Block.stopSounds()

    self = self or {}
    setmetatable(self, { __index = Level })
    self.died = false

    self.bumpWorld = bump.newWorld(1)

    self.layout = assert(layout, 'need `layout`')

    self.player = nil
    self.blocks = {}

    local maxX, maxY = 0, 0
    for i = 1, #self.layout do
        local line = self.layout[i]
        for j = 1, #line do
            local char = line:sub(j, j)
            local x, y = j, i

            maxX = math.max(maxX, x)
            maxY = math.max(maxY, y)

            if char == 'P' then
                assert(not self.player, 'need max 1 `Player`')
                self.player = Player.create({
                    level = self, x = x, y = y,
                })
            elseif char == 'B' then
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y,
                }))
            elseif char == 'M' then
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y,
                    isMover = true,
                }))
            elseif char == 'W' then
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y,
                    isWin = true,
                }))
            elseif char == 'D' then
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y,
                    isDanger = true,
                }))
            end
        end
    end

    assert(self.player, 'need min 1 `Player`')

    -- Outer blocks
    do
        local hw, hh = math.floor(W / 1.5), math.floor(H / 1.5)
        for x = -hw, 0 do
            for y = -hh, 0 do
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y
                }))
            end
        end
        for x = -hw, 0 do
            for y = 1, maxY do
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y
                }))
            end
        end
        for x = -hw, 0 do
            for y = maxY + 1, maxY + hh do
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y
                }))
            end
        end
        for x = maxX + 1, maxX + 1 + hw do
            for y = -hh, 0 do
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y
                }))
            end
        end
        for x = maxX + 1, maxX + 1 + hw do
            for y = 1, maxY do
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y
                }))
            end
        end
        for x = maxX + 1, maxX + 1 + hw do
            for y = maxY + 1, maxY + hh do
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y
                }))
            end
        end
        for x = 1, maxX do
            for y = -hh, 0 do
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y
                }))
            end
        end
        for x = 1, maxX do
            for y = maxY + 1, maxY + 1 + hh do
                table.insert(self.blocks, Block.create({
                    level = self, x = x, y = y
                }))
            end
        end
    end

    self.viewX, self.viewY = self.player.x, self.player.y

    return self
end

function Level:die()
    self.died = true
    Level.dieSound:play()
end

function Level:draw()
    -- View motion
    local bw, bh = math.floor(W / 6) + 1, math.floor(H / 6) + 1
    local escapeX, escapeY
    if self.player.x - self.viewX < -bw then
        escapeX = self.player.x - self.viewX + bw
    end
    if self.player.x - self.viewX > bw then
        escapeX = self.player.x - self.viewX - bw
    end
    if self.player.y - self.viewY < -bw then
        escapeY = self.player.y - self.viewY + bw
    end
    if self.player.y - self.viewY > bw then
        escapeY = self.player.y - self.viewY - bw
    end
    if escapeX then
        self.viewX = self.viewX + escapeX
    end
    if escapeY then
        self.viewY = self.viewY + escapeY
    end

    love.graphics.translate(-self.viewX, -self.viewY)

    for _, block in ipairs(self.blocks) do
        block:draw()
    end

    self.player:draw()
end

function Level:update(dt)
    if self.died then
        self:create(self.layout)
        return
    end

    for _, block in ipairs(self.blocks) do
        block.updatedThisFrame = false
    end
    for _, block in ipairs(self.blocks) do
        block:update(dt)
    end

    self.player.tryLeft = love.keyboard.isDown('left')
    self.player.tryRight = love.keyboard.isDown('right')
    self.player:update(dt)
end

function Level:keypressed(key)
    if key == 'up' then
        self.player:tryJump()
    end
    if key == 'r' then
        self:die()
    end
end

return Level
