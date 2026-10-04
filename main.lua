function love.load()
    -- {{{ THEME COLOUR SETUPS
        COLOURS = {}
        COLOURS.BOLD = {1,1,1}
        COLOURS.FADED = {0.5,0.5,0.5}
        COLOURS.FAINT = {1,1,1,0.25}
        COLOURS.BACKGROUND = {0.15,0.15,0.25}
    -- }}}

    -- {{{ IMAGE OUTPUT
        SCREENBOUNDARY = 100 --px
        IMAGEWIDTH = 1920
        IMAGEHEIGHT = 1080
        SOFTBOTTOM = 0 -- program will try within a reasonable limit to have 0 be the bottom line of the image.
        SOFTBOTTOM_IGNOREDOWN = 3 -- can go down up to this many segments/increments to have the bottom be forced.
        SOFTBOTTOM_IGNOREUP = 0 -- ditto. 0 because it's fucked. should be negative.
        EVILREDLINE = 50 -- draws a red line at the point where a currency crashes
        DISPLAYSEGMENTS = 2 -- soft constant, will get adjusted (should be like 4 usually)
    -- }}}


    -- {{{ LOADING THE FILE
    print("Processing CSV!") -- could be big enough for this to be useful
        info = love.filesystem.getInfo("graph.csv", "file")
        if info then
            entries = {}
            local contents = love.filesystem.lines("graph.csv")
            for line in contents do
                for value in line:gmatch("[^,]+") do
                    if tonumber(value)~=0 then -- the csv i was given is formatted like value, 0. i'm ignoring the 0s here since currencies cant go below 50.
                        table.insert(entries, tonumber(value))
                    end
                end
            end
            
        else love.quit(1)
        end
    print("CSV loaded!")
    --- }}}

    graph = makeGraph(entries) -- returns a canvas with the rendered graph
    image = graph:newImageData():encode('png'):getString() -- string representing a png of the canvas
    io.open("graph.png", "wb"):write(image) -- create png image to the working directory! WILL PROBABLY NOT WORK IF YOU CONVERT THE PROGRAM TO A LOVE FILE
    love.event.quit() --no need to close the io image because we literally shut off the program in like a milisecond.
    
end

function makeGraph(entries)

    -- {{{ Analyse the graph
        DATA = {}
        DATA.count = #entries
        DATA.min = math.huge
        DATA.max = -math.huge
        for i,value in ipairs(entries) do
            if DATA.min > value then DATA.min = value end
            if DATA.max < value then DATA.max = value end
        end
        print("MAX VALUE: "..DATA.max)
        print("MIN VALUE: "..DATA.min)
        -- {{ CALCULATE INCREMENTS ON THE LEFT
        do
            local increments = {1, 5, 10, 50, 100, 500, 1000, 5000, 10000, 50000} --if the currencies ever go higher than 200k that's on you not me.
            local range = DATA.max - DATA.min
            DATA.increment = range/DISPLAYSEGMENTS 
            local distance = math.huge
            local index = 0
            for i, value in ipairs(increments) do
                newDist = math.abs(DATA.increment - value)
                if distance > newDist then
                    distance = newDist 
                    index = i
                end
            end
            DATA.increment = increments[index]
            if index ~= 1 then DATA.minicrement = increments[index-1] end
            print("CHOSEN INCREMENT: "..DATA.increment)
            -- { displayed on the left
                DATA.top = math.floor(DATA.max/DATA.increment + 1)*DATA.increment
                print("TOP VALUE: "..DATA.top)

                DATA.bottom = math.floor(DATA.min/DATA.increment)*DATA.increment
                -- { Attempt to set the bottom to the soft forced bottom 
                    DATA.range = DATA.top-DATA.bottom
                    local segmentsToBottom = (DATA.bottom-SOFTBOTTOM)/DATA.increment
                    print(segmentsToBottom)
                    if segmentsToBottom < SOFTBOTTOM_IGNOREDOWN then if segmentsToBottom >= 0 then DATA.bottom = SOFTBOTTOM end end
                    if segmentsToBottom > SOFTBOTTOM_IGNOREUP then if segmentsToBottom < 0 then data.bottom = SOFTBOTTOM end end
                -- }

                print("BOTTOM VALUE: "..DATA.bottom)
            -- }
            DATA.range = DATA.top-DATA.bottom
            print("CHOSEN RANGE:"..DATA.range)
            DISPLAYSEGMENTS = DATA.range/DATA.increment
        end
        -- }}
    --- }}}

    -- derived drawing constants
    DOWN = IMAGEHEIGHT - SCREENBOUNDARY
    RIGHT = IMAGEWIDTH - SCREENBOUNDARY
    WIDTH = IMAGEWIDTH-2*SCREENBOUNDARY
    HEIGHT = IMAGEHEIGHT-2*SCREENBOUNDARY

    local graph = love.graphics.newCanvas(IMAGEWIDTH, IMAGEHEIGHT)
    love.graphics.setCanvas(graph)

    --- {{{ DRAW
        love.graphics.setColor(COLOURS.BACKGROUND)
        love.graphics.rectangle("fill",0,0,IMAGEWIDTH,IMAGEHEIGHT)

        love.graphics.setColor(COLOURS.BOLD)
        love.graphics.setLineWidth(5)
        love.graphics.line(SCREENBOUNDARY, SCREENBOUNDARY, SCREENBOUNDARY, DOWN) -- vertical line

        love.graphics.line(SCREENBOUNDARY, DOWN, RIGHT, DOWN) -- horizontal line

        love.graphics.setLineWidth(1)
        -- {{{ DRAW THE VALUEGRAPH
            prevHeight = nil
            for i,v in ipairs(entries) do
                if(i ~= 1) then 
                    local h = valToHeight(v)

                    love.graphics.setColor(COLOURS.FADED) 
                    love.graphics.polygon( "fill",        -- draw the underspace
                       indexToWidth(i-1), prevHeight,
                       indexToWidth(i), h,
                       indexToWidth(i),valToHeight(DATA.bottom),
                       indexToWidth(i-1), valToHeight(DATA.bottom)
                    )

                    love.graphics.setColor(COLOURS.BOLD)  -- draw the line
                    love.graphics.line(
                       indexToWidth(i-1), prevHeight,
                       indexToWidth(i), h
                    )

                end

                prevHeight = valToHeight(v)
            end
        -- }}}

        -- {{{ DRAW NUMBER LINES
            local used = {}
            love.graphics.setLineWidth(2)
            for i=DATA.bottom,DATA.top,DATA.increment  do
                used[i]=true
                local y = valToHeight(i)
                love.graphics.print(i, SCREENBOUNDARY/2, y)
                love.graphics.line(indexToWidth(0), y, RIGHT, y)
            end

            if DATA.minicrement then
                love.graphics.setLineWidth(1)
                love.graphics.setColor(COLOURS.FAINT)
                for i=DATA.bottom,DATA.top,DATA.minicrement do
                    if not used[i] then
                        local y = valToHeight(i)
                        love.graphics.print(i, SCREENBOUNDARY/2, y)
                        love.graphics.line(indexToWidth(0), y, RIGHT, y)
                    end
                end
            end
        -- }}}

    --- }}}

    love.graphics.setCanvas()
    return graph
end

-- RENDERING HELPERS

function valToHeight(x) -- converts a value to its height on the graph

    return HEIGHT - (-SCREENBOUNDARY + ((x-DATA.bottom)/(DATA.top-DATA.bottom))*HEIGHT)

end

function indexToWidth(x) -- converts an index to how far along the graph it is
    return SCREENBOUNDARY + ((x-1)/(DATA.count-1))*WIDTH
end

function love.graphics.dottedLine(x1, y1, x2, y2, intervalFill, intervalEmpty)

    local distance = math.sqrt((x2-x1)^2 + (y2-y1)^2)
    if distance == 0 then return end -- one must learn these lessons the hard way
    local normalised = {}
    normalised.x = (x2-x1)/distance
    normalised.y = (y2-y1)/distance

end