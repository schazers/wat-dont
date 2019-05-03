Block = Block or {}

function Block.symrand(size)
    return size * (1 - 2 * math.random())
end

Block.moverSound = Block.moverSound or love.audio.newSource('./mover1.wav', 'static')
Block.movingSound = Block.movingSound or love.audio.newSource('./mover2.wav', 'static')

BLOCK_MOVE_PITCH_VARIATION = 0.1

function Block:create()
    -- Init
    self = self or {}
    setmetatable(self, { __index = Block })
    assert(self.level, 'need `level`!')
    self.x = self.x or 0
    self.y = self.y or 0

    self.isFloor = true

    if self.isMover == nil then
        self.isMover = false
    end

    if self.isMover then
        self.moveDirX = self.moveDirX or 0
        self.moveDirY = self.moveDirY or 0
    end

    -- Add to bump world
    self.level.bumpWorld:add(self, self.x - 0.5, self.y - 0.5, 1, 1)

    return self
end

Block.staticImageAll = Block.staticImageAll or love.graphics.newImage('static-block-all.png')
Block.staticImageDownLeft = Block.staticImageDownLeft or love.graphics.newImage('static-block-down-left.png')
Block.staticImageDown = Block.staticImageDown or love.graphics.newImage('static-block-down.png')
Block.staticImageDownRight = Block.staticImageDownRight or love.graphics.newImage('static-block-down-right.png')
Block.staticImageLeft = Block.staticImageLeft or love.graphics.newImage('static-block-left.png')
Block.staticImageNone = Block.staticImageNone or love.graphics.newImage('static-block-none.png')
Block.staticImageRight = Block.staticImageRight or love.graphics.newImage('static-block-right.png')
Block.staticImageUpLeft = Block.staticImageUpLeft or love.graphics.newImage('static-block-up-left.png')
Block.staticImageUp = Block.staticImageUp or love.graphics.newImage('static-block-up.png')
Block.staticImageUpRight = Block.staticImageUpRight or love.graphics.newImage('static-block-up-right.png')

Block.dirs = Block.dirs or {
    up = { 0, -1 },
    down = { 0, 1 },
    left = { -1, 0 },
    right = { 1, 0 },
}

function Block:hasNeighbor(dir)
    if self.hasNeighborCache and self.hasNeighborCache[dir] then
        return self.hasNeighborCache[dir]
    end

    local hits = self.level.bumpWorld:queryRect(
        self.x - 0.5 / G + (0.5 + 1 / G) * Block.dirs[dir][1],
        self.y - 0.5 / G + (0.5 + 1/ G) * Block.dirs[dir][2],
        1 / G, 1 / G,
        function (obj) return obj ~= self and obj.isFloor end)
    local has = #hits > 0

    local nMovers = 0
    for _, hit in ipairs(hits) do
        if hit.isMover then
            nMovers = nMovers + 1
        end
    end

    if not self.isMover and nMovers < #hits then
        if not self.hasNeighborCache then
            self.hasNeighborCache = {}
        end
        self.hasNeighborCache[dir] = has
    end

    return has
end

function Block:draw()
    love.graphics.stacked('all', function()
        local up = self:hasNeighbor('up')
        local down = self:hasNeighbor('down')
        local left = self:hasNeighbor('left')
        local right = self:hasNeighbor('right')

        local nNeighbors = (up and 1 or 0) + (down and 1 or 0) + (left and 1 or 0) + (right and 1 or 0)

        local image
        if nNeighbors >= 3 then
            image = Block.staticImageAll
        elseif nNeighbors == 2 then
            if up and left then
                image = Block.staticImageUpLeft
            elseif up and right then
                image = Block.staticImageUpRight
            elseif down and left then
                image = Block.staticImageDownLeft
            elseif down and right then
                image = Block.staticImageDownRight
            else
                image = Block.staticImageAll
            end
        elseif nNeighbors == 1 then
            if up then
                image = Block.staticImageUp
            elseif down then
                image = Block.staticImageDown
            elseif left then
                image = Block.staticImageLeft
            elseif right then
                image = Block.staticImageRight
            end
        else
            image = Block.staticImageNone
        end

        if self.isMover then
            if self.moveDirUpdated then
                love.graphics.setColor(0.2, 1, 0.2)
                love.graphics.setColor(0.4 + Block.symrand(0.2), 0.62 + Block.symrand(0.2), 1 - 0.2 * math.random())
            else
                love.graphics.setColor(0.8, 0.52, 1)
            end
        elseif self.isWin then
            love.graphics.setColor(1, 1, 0.2)
        elseif self.isDanger then
            love.graphics.setColor(0.9, 0.2, 0.2)
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
        end

        love.graphics.draw(image, self.x, self.y, 0,
            1 / image:getWidth(), 1 / image:getHeight(),
            0.5 * image:getWidth(), 0.5 * image:getHeight())

        -- love.graphics.rectangle('fill', self.x - 0.5, self.y - 0.5, 1, 1)
        -- love.graphics.setColor(0, 0, 0)
        -- love.graphics.rectangle('line', self.x - 0.5, self.y - 0.5, 1, 1)
    end)
end

function Block:update(dt)
    if self.updatedThisFrame then return end
    self.updatedThisFrame = true

    if self.isMover then
        if self.moveDirX ~= 0 or self.moveDirY ~= 0 then
            local dx, dy = BLOCK_MOVE_SPEED * self.moveDirX * dt, BLOCK_MOVE_SPEED * self.moveDirY * dt
            local moversInWay = self.level.bumpWorld:queryRect(
                self.x - 0.5 + dx, self.y - 0.5 + dy, 1, 1,
                function (obj) return obj.isMover and not obj.updatedThisFrame end)
            for _, mover in ipairs(moversInWay) do
                mover:update(dt)
            end
            local newX, newY, cols = self.level.bumpWorld:move(
                self, self.x - 0.5 + dx, self.y - 0.5 + dy,
                function(self, other)
                    if other.isPlayer then -- Player? Push them and continue in that direction...
                        return 'cross'
                    end
                    return 'slide' -- Else slide against whatever it is
                end
            )
            newX = newX + 0.5
            newY = newY + 0.5
            self.x, self.y = newX, newY
            if #cols == 0 then
                if not Block.movingSound:isPlaying() then
                    Block.movingSound:setPitch(1 + BLOCK_MOVE_PITCH_VARIATION * math.random())
                    Block.movingSound:play()
                end
            end
        end
    end

    self.moveDirUpdated = false
end

function Block:setMoveDir(dirX, dirY)
    self.moveDirUpdated = true

    -- See if clear in that direction
    do
        local blockers = self.level.bumpWorld:queryRect(
            self.x - 0.5 + dirX, self.y - 0.5 + dirY, 1, 1,
            function(obj)
                if obj == self then return false end

                if obj.isMover then
                    if obj.moveDirY ~= dirY then return true end
                    if obj.moveDirX ~= dirX then return true end
                    return false
                end

                if obj.isPlayer then
                    return false
                end

                return true
            end)
        if #blockers > 0 then
            return
        end
    end

    if not Block.moverSound:isPlaying() and (self.moveDirX ~= dirX or self.moveDirY ~= dirY) then
        Block.moverSound:setPitch(1 + BLOCK_MOVE_PITCH_VARIATION * math.random())
        Block.moverSound:play()
    end

    self.moveDirX, self.moveDirY = dirX, dirY
    local querySize = 1 + 1 / G
    local movers = self.level.bumpWorld:queryRect(
        self.x - 0.5 * querySize, self.y - 0.5 * querySize, querySize, querySize,
        function(obj) return obj.isMover and not obj.moveDirUpdated end)

    table.sort(movers, function(a, b)
        if dirX < 0 then return a.x < b.x end
        if dirY < 0 then return a.y < b.y end
        if dirX > 0 then return a.x > b.x end
        if dirY > 0 then return a.y > b.y end
    end)

    for _, mover in ipairs(movers) do
        mover:setMoveDir(dirX, dirY)
    end
end

function Block.stopSounds()
    Block.moverSound:stop()
    Block.movingSound:stop()
end

return Block
