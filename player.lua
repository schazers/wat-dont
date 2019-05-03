Player = Player or {}

Player.rightImage = Player.rightImage or love.graphics.newImage('./player-right.png')
Player.leftImage = Player.leftImage or love.graphics.newImage('./player-left.png')

Player.jumpSound = Player.jumpSound or love.audio.newSource('./jump.wav', 'static')
Player.winSound = Player.winSound or love.audio.newSource('./win.wav', 'static')

function Player:create()
    -- Init
    self = self or {}
    setmetatable(self, { __index = Player })
    assert(self.level, 'need `level`!')
    self.x, self.y = self.x or 0, self.y or 0

    self.isPlayer = true

    self.vx, self.vy = 0, 0

    self.tryLeft, self.tryRight = false, false

    self.canDoubleJump = false

    self.dir = 'right'

    -- Add to bump world
    self.level.bumpWorld:add(self, self.x - 0.5, self.y - 0.5, 1, 1)

    return self
end

function Player:draw()
    love.graphics.stacked('all', function()
        local image
        if self.dir == 'left' then
            image = Player.leftImage
        else
            image = Player.rightImage
        end
        love.graphics.draw(image, self.x, self.y, 0,
            1 / image:getWidth(), 1 / image:getHeight(),
            0.5 * image:getWidth(), 0.5 * image:getHeight())
    end)
end

function Player:update(dt)
    -- Be pushed by mover blocks
    do
        local dp = BLOCK_MOVE_SPEED * dt
        local querySize = 1 + dp
        local movers = self.level.bumpWorld:queryRect(
            self.x - 0.5 * querySize, self.y - 0.5 * querySize, querySize, querySize,
            function(obj) return obj.isMover end)
        local dx, dy = 0, 0
        for _, mover in ipairs(movers) do
            if (mover.x < self.x and mover.moveDirX > 0) or (mover.x > self.x and mover.moveDirX < 0) then
                if math.abs(mover.y - self.y) < 1 then
                    dx = mover.moveDirX * BLOCK_MOVE_SPEED * dt
                end
            end
            if (mover.y < self.y and mover.moveDirY > 0) or (mover.y > self.y and mover.moveDirY < 0) then
                if math.abs(mover.x - self.x) < 1 then
                    dy = mover.moveDirY * BLOCK_MOVE_SPEED * dt
                end
            end
        end
        self.x = self.x + dx
        self.y = self.y + dy
        self.level.bumpWorld:update(self, self.x - 0.5, self.y - 0.5)
        local floors = self.level.bumpWorld:queryRect(
            self.x - 0.5, self.y - 0.5, 1, 1,
            function(obj) return obj.isFloor end)
        if #floors > 0 then
            self.level:die()
            return
        end
    end

    -- Update vx
    self.vx = 0
    if not (self.tryLeft and self.tryRight) then
        if self.tryLeft then
            self.vx = -PLAYER_RUN_SPEED
        end
        if self.tryRight then
            self.vx = PLAYER_RUN_SPEED
        end
    end
    if self.vx < 0 then self.dir = 'left' end
    if self.vx > 0 then self.dir = 'right' end

    -- Integrate acceleration
    self.vy = self.vy + PLAYER_GRAVITY * dt
    self.vy = math.min(self.vy, PLAYER_MAX_SPEED)

    -- Apply velocity, move, recalculate new velocity
    local newX, newY, cols = self.level.bumpWorld:move(
        self, self.x - 0.5 + self.vx * dt, self.y - 0.5 + self.vy * dt)
    newX = newX + 0.5
    newY = newY + 0.5
    self.vx = (newX - self.x) / dt
    self.vy = (newY - self.y) / dt
    self.x, self.y = newX, newY

    -- Notify any mover blocks we've run into
    for _, col in ipairs(cols) do
        if col.other.isMover then
            col.other:setMoveDir(col.normal.x, col.normal.y)
        elseif col.other.isWin then
            Player.winSound:play()
            main.win()
        elseif col.other.isDanger then
            self.level:die()
        end
    end

    -- Figure out whether we can double jump now
    self.canDoubleJump = self.canDoubleJump or self:_floored()
end

function Player:_floored()
    local items = self.level.bumpWorld:queryRect(
        self.x - 0.5, self.y - 0.5 + PLAYER_FLOOR_CHECK_THRESHOLD, 1, 1,
        function(obj) return obj.isFloor end)
    return #items > 0
end

function Player:tryJump()
    local canJump
    if self:_floored() then
        canJump = true
    elseif self.canDoubleJump then
        self.canDoubleJump = false
        canJump = true
    end
    if canJump then
        Player.jumpSound:play()
        self.vy = -PLAYER_JUMP_SPEED
    end
end

return Player
