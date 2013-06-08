formatNumber = (n,decimals) ->
        suffix = ""
        negativePrefix = ""
        negativeSuffix = ""
        if (n < 0)
                negativePrefix = " הכנסה של"
                negativeSuffix = ""
                n = -n
        if (n >= 1000000000000)
                suffix = " trillion"
                n = n / 1000000000000
                decimals = 2
        else if n >= 1000000000
                suffix = " מיליארד"
                n = n / 1000000000
                decimals = 1
        else if n >= 1000000
                suffix = " מיליון"
                n = n / 1000000
                decimals = 1	   
        prefix = ""
        if decimals > 0
                if (n<1)
                        prefix = "0"
                s = String(Math.round(n * (Math.pow(10,decimals))));
                if (s < 10)
                    remainder = "0" + s.substr(s.length-(decimals),decimals)
                    num = "";
                else
                    remainder = s.substr(s.length-(decimals),decimals)
                    num = s.substr(0,s.length - decimals)               
                return negativePrefix + prefix + num.replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1,") + "." + remainder + suffix + negativeSuffix
        else
                s = String(Math.round(n))
                s = s.replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1,")
                return negativePrefix + s + suffix + negativeSuffix

class CompareData extends Backbone.Model
        defaults:
                data: []
                field: ""
        initialize: ->
                @on 'change:field', () ->
                        field = @get 'field'
                        data = budget_array_data[field]
                        if data
                                console.log('setting field ' + field)
                                @set 'data', budget_array_data[field].d
                                @set 'title', budget_array_data[field].t
                        else
                                console.log('field '+field+' is '+data)

class BubbleChart extends Backbone.View


        # Colors
        getFillColor: (d) -> 
                fillColor = d3.scale.ordinal().domain([-3,-2,-1,0,1,2,3]).range (["#ddad13", "#eeca7c","#e4d0ae","#AAA","#bfc3dc", "#9ea5c8", "#7b82c2"])
                if (d.isNegative) then "#fff" else fillColor(d.changeCategory)

        getStrokeColor: (d) ->
                if d.name == @selectedItem then return "#FF0"
                strokeColor = d3.scale.ordinal().domain([-3,-2,-1,0,1,2,3]).range(["#c09100", "#e7bd53","#d9c292","#999","#a7aed3", "#7f8ab8", "#4f5fb0"])
                strokeColor(d.changeCategory);

        strokeWidth: (d) ->
                if d.name == @selectedItem then 5 else 1

        # Formatting
        pctFormat: (p) ->
                pFormat = d3.format(".1%")
                if (p == Infinity || p == -Infinity)  then "N.A" else pFormat(p)

        # Force Layout
        defaultCharge:
                (d) -> if (d.value < 0) then 0 else -Math.pow(d.radius,2.0)/8  

        totalSort: (alpha) ->
                return (d) =>
                        targetY = 0
                        targetX = 0
                        if d.isNegative
                                if d.changeCategory > 0
                                        d.x = -200
                                else 
                                        d.x = 1100
                        d.y = d.y + (targetY - d.y) * (@defaultGravity + 0.02) * alpha
                        d.x = d.x + (targetX - d.x) * (@defaultGravity + 0.02) * alpha
                        
        buoyancy: (alpha) ->
                return (d) =>
                        targetY = - (d.changeCategory / 3) * @boundingRadius
                        d.y = d.y + (targetY - d.y) * (@defaultGravity) * alpha * alpha * alpha * 500

        # Data handling
        categorizeChange: (c) ->
                if isNaN(c)     then return 0
                if c < -0.25    then return -3
                if c < -0.05    then return -2
                if c < -0.001   then return -1
                if c <= 0.001   then return 0
                if c <= 0.05    then return 1
                if c <= 0.25    then return 2
                return 3
         
        # Chart stuff
        setOverlayed: (overlayed) ->
                overlayed = if overlayed then true else false
                if overlayed
                        @transitiontime = 0
                else
                        @transitiontime = 1000               

        initialize: (@options) ->
                _.bindAll @

                
                @width = 970
                @height = 550
                @id = @options.id
                @overlayShown = false

                console.log "BubbleChart:initialize", @id

        	# d3 settings
                @defaultGravity = 0.1
                               
                @force = @svg = @circle = null
                @changeTickValues = [-0.25, -0.15, -0.05, 0.05, 0.15, 0.25]
                
                # chart settings
                @centerX = @width / 2
                @centerY = @height / 2

                @model.bind 'change:data', =>
                        @updateData( @model.get 'data' )

                d3.select(@el).html("")
                @svg = d3.select(@el)
                         .append("svg:svg")
                         #.attr("width", @width)
                @svg.on("click", -> removeState() )

                console.log "init done", @id
        
        updateData: (data) ->
                oldNodes = []

                @selectedItem = null

                sum = 0
                for x in data
                        sum += x.b1
                @totalValue = sum ? 400000000
                console.log "Totalvalue: "+@totalValue
                if @?.nodes
                        for node in @nodes
                                oldNodes.push(node)
                @nodes = []
                @titles = []

                rScale = d3.scale.pow().exponent(0.5).domain([0,@totalValue]).range([1,200])
                radiusScale = (n) -> rScale( Math.abs(n) )
                @boundingRadius = radiusScale(@totalValue)

                currentYearDataColumn = 'b1'
                previousYearDataColumn = 'b0'


                # Builds the nodes data array from the original data
                for n in data
                        out = null
                        sid = n.id
                        for node in oldNodes
                                if node.sid == sid
                                        out = node
                        if out == null
                                out =
                                        x               : -150+Math.random() * 300
                                        y               : -150+Math.random() * 300

                        out.sid = n.id
                        out.code = strings[n.id]
                        out.radius = radiusScale(n[currentYearDataColumn])
                        out.group = strings[n.p]
                        out.groupvalue = n.pv
                        out.change = n.c/100.0
                        out.changeCategory = @categorizeChange(n.c/100.0)
                        out.value = n[currentYearDataColumn]
                        out.name = strings[n.n]
                        out.isNegative = (n[currentYearDataColumn] < 0)
                        out.positions = n.positions
                        out.drilldown = n.d

                        @titles.push( out.name )
                        ###
                        #  if (n.positions.total) 
        	    	#     out.x = n.positions.total.x + (n.positions.total.x - (@width / 2)) * 0.5
        	    	#     out.y = n.positions.total.y + (n.positions.total.y - (150)) * 0.5
        	    	###

                        if ((n[currentYearDataColumn] > 0) && (n[previousYearDataColumn] < 0))
                                out.changestr = "הפך מהכנסה להוצאה"
                                out.changeCategory = 3
                        if ((n[currentYearDataColumn] < 0) && (n[previousYearDataColumn] > 0))
                                out.changestr = "הפך מהוצאה להכנסה"
                                out.changeCategory = 3
                        if (n.c==99999)
                                out.changestr = "תוקצב מחדש"
                                out.changeCategory = 3
                                

                        @nodes.push(out)

                @nodes.sort( (a,b) -> Math.abs(b.value) - Math.abs(a.value) )
                @titles.sort()
                        
                if data.length > 0
                        @render()
                else
                        container = $("div[data-id='#{@id}']")
                        if @transitiontime > 0
                                @circle.transition().duration(@transitiontime)
                                        .attr("r", (d) -> 0)
                                container.find(".overlay")
                                        .css("opacity",0.9)
                                        .animate({opacity:0},@transitiontime, -> container.remove())
                        else
                                container.remove()
                                

        showOverlay: (id) ->
                if @overlayShown then return
                @overlayShown = true
                node = null
                for _node in @nodes
                        if _node.drilldown == id
                                node = _node
                if node == null
                        return
                scale = @height / node.radius / 3
                console.log "showOverlay: ", node.radius, @height, scale
                origin = "translate(#{@centerX},#{@centerY})rotate(0)translate(1,1)scale(1)"
                target = "translate(#{@centerX},#{@centerY})rotate(120)translate(#{-node.x*scale},#{-node.y*scale})scale(#{scale})"

                if @transitiontime == 0
                        @svg.selectAll("circle").attr("transform",target)
                else
                        @svg.selectAll("circle")
                                .transition()
                                        .duration(@transitiontime)
                                        .attrTween("transform",
                                                   -> d3.interpolateString( origin, target )
                                                )
                
                                console.log("TRANSITION "+origin+" -> "+target)
                $("#tooltip").hide()

        overlayRemoved: ->
                @setOverlayed(false)
                @overlayShown = false
                
                origin = @svg.select("circle").attr("transform")
                target = "translate(#{@centerX},#{@centerY})rotate(0)translate(1,1)scale(1)"

                @svg.selectAll("circle")
                        .transition()
                                .duration(@transitiontime)
                                .attrTween("transform",
                                           -> d3.interpolateString( origin, target )
                                        )
                @circle.attr("r", (d) -> d.radius )

        selectItem: (item) ->
                @selectedItem = item
                @circle.style("stroke-width",@strokeWidth)
                @circle.style("stroke", @getStrokeColor)

        render: () ->

                that = this
                typeahead = $("div[data-id='#{@id}'] .search")
                typeahead.typeahead(
                        source: =>
                                @selectItem(null)
                                @selectedItem = null
                                @circle.style("stroke-width",@strokeWidth)
                                @circle.style("stroke", @getStrokeColor)
                                @titles
                        updater: (item) =>
                                @selectItem(item)
                                return item
                )
                tags = $("div[data-id='#{@id}'] .tag")
                tagClicked = false
                tags.mouseenter( () ->
                                        that.selectItem( $(@).text() )
                                        tagClicked = false
                                )
                        .mouseleave( () -> if not tagClicked then that.selectItem( null ) )
                        .click     ( () ->
                                        that.selectItem( $(@).text() )
                                        tagClicked = true
                                )
                container = $("div[data-id='#{@id}'] .overlayContainer")
                overlay = $("div[data-id='#{@id}'] .overlay")
                frame = $("div[data-id='#{@id}'] .frame")
                overlay.css("height",frame.height()+"px")
                $(window).resize () =>
                        console.log "frame resize"
                        @width = $(window).width() - 8
                        if @width > 900 then @width = 900
                        @centerX = @width/2
                        if not @overlayShown and @circle
                                @svg.attr "width", @width
                                @circle.attr("transform","translate(#{@centerX},#{@centerY})rotate(0)translate(1,1)scale(1)")
                        overlay.css("height",frame.height()+"px")

                @width = $(window).width() - 8
                if @width > 900 then @width = 900
                @centerX = @width/2

                if @transitiontime > 0
                        overlay
                                .css("opacity",0)
                                .animate({opacity:0.9},@transitiontime)
                else
                        overlay
                                .css("opacity",0.9)

                @circle = @svg.selectAll("circle")
                              .data(@nodes, (d) -> d.sid );
                        
                that = @
                @circle.enter()
                        .append("svg:circle")
                        .attr("transform","translate(#{@centerX},#{@centerY})rotate(0)translate(1,1)scale(1)")
                        .attr("data-title", (d) -> d.name )
                        .style("stroke-width", @strokeWidth )
                        .style("fill", @getFillColor )
                        .style("stroke", @getStrokeColor )
                        .style("cursor",(d) => if budget_array_data[d.drilldown] then "pointer" else "default")
                        .on("click", (d,i) ->
                                if budget_array_data[d.drilldown]
                                        addState(d.drilldown)
                                d3.event.stopPropagation()
                                )
                        .on("mouseover", (d,i) ->
                                el = d3.select(@)
                                svgPos = $(that.el).find("svg").offset()
                                console.log svgPos.top, svgPos.left, that.width
                                xpos = Number(el.attr('cx'))+that.centerX
                                tail = 100
                                if xpos < 125
                                        tail += 125 - xpos
                                        xpos = 125
                                if xpos > (that.width - 125)
                                        tail -= xpos - (that.width - 125)
                                        xpos = (that.width - 125)
                                xpos += svgPos.left
                                ypos = Number(el.attr('cy'))
                                console.log "YPOS "+ypos
                                if ypos > 0
                                        ypos = ypos - d.radius - 10 +svgPos.top+that.centerY
                                        $("#tooltipContainer").css("bottom",0)
                                        d3.select("#tooltip .arrow.top").style("display","none")
                                        d3.select("#tooltip .arrow.bottom").style("display","block")
                                else
                                        ypos = ypos + d.radius + 10 +svgPos.top+that.centerY
                                        $("#tooltipContainer").css("bottom","")
                                        d3.select("#tooltip .arrow.top").style("display","block")
                                        d3.select("#tooltip .arrow.bottom").style("display","none")                                        
                                el.style("stroke","#000").style("stroke-width",3)
                                d3.select("#tooltip")
                                        .style('top',ypos+"px")
                                        .style('left',xpos+"px")
                                        .style('display','block')
                                        .classed('plus', (d.changeCategory > 0))
                                        .classed('minus', (d.changeCategory < 0))
                                d3.select("#tooltip .name").html(d.name)
                                d3.select("#tooltip .department").text(d.group)
                                d3.select("#tooltip .explanation").text(getExplanation(d.code,2012))
                                d3.select("#tooltip .history").text("Hello there")
                                d3.select("#tooltip .value").html(formatNumber(d.value*1000)+" \u20aa")
                                d3.selectAll("#tooltip .arrow").style("right",tail+"px")
                                if d?.changestr
                                        pctchngout = d.changestr
                                else
                                        pctchngout = if (d.change == "N.A.") then "N.A" else that.pctFormat(Math.abs(d.change))
                                        pctchngout = pctchngout + (if d.change < 0 then "-" else "+")
                                d3.select("#tooltip .change").html( pctchngout)
                                )
                        .on("mouseout", (d,i) ->
                                d3.select(@)
                                        .style("stroke-width", that.strokeWidth )
                                        .style("stroke", (d) -> that.getStrokeColor(d) )
                                d3.select("#tooltip").style('display','none')
                                )
                if @transitiontime > 0
                        @circle.transition().duration(@transitiontime)
                                .attr("r", (d) -> d.radius )
                                .style("fill", (d) => @getFillColor(d) )
                                .style("stroke", (d) => @getStrokeColor(d) )
                        @circle.exit().transition().duration(@transitiontime)
                                .attr("r", (d) -> 0)
                                .remove()
                else
                        @circle.attr("r", (d) -> d.radius )
                                .style("fill", (d) => @getFillColor(d) )
                                .style("stroke", (d) => @getStrokeColor(d) )
                        @circle.exit().remove()

                if @force != null
                        @force.stop()
                @force = d3.layout
                                .force()
                                .nodes(@nodes)
                		.size([@width, @height])
                		.gravity(-0.01)
                		.charge(@defaultCharge)
                		.friction(0.9)
                                .on("tick", (e) =>
                                        @circle .each(@totalSort(e.alpha))
                                                .each(@buoyancy(e.alpha))
                                                .attr("cx", (d) -> d.x )
                                                .attr("cy", (d) -> d.y )
                                        )
                		.start()

querys = []
charts = []
first_time = true

addState = (toAdd) ->
        querys.push(toAdd)
        History.pushState(querys,null,"?" + querys.join("/") )

removeState = ->
        if querys.length > 1
                querys.pop()
                History.pushState(querys,null,"?" + querys.join("/") )

handleNewState = () ->
        state = History.getState()
        querys = state.data
        console.log "state changed: ",state
        for i in [0...querys.length]
                query = querys[i]
                nextquery = querys[i+1]
                id = "id"+i
                el = $("div[data-id='#{id}'] .chart")
                if el.size() == 0
                        console.log "creating chart "+id
                        template = _.template( $("#chart-template").html(),{ id: id } )
                        $("#charts").append template
                        el =$("div[data-id='#{id}'] .chart")                       
                        console.log "creating BubbleChart "+id
                        charts[i] = new BubbleChart
                                el: el
                                model: new CompareData
                                id: id

        max = if querys.length > charts.length then querys.length else charts.length
        console.log "max: "+max
        for i in [max-1..0]
                console.log "setting field for "+i
                if i >= querys.length
                        console.log "removing chart #"+i
                        charts[i].updateData([])
                        charts.pop()
                        continue

                query = querys[i]
                overlaid = false
                if (i < querys.length - 2) or (first_time and (i < querys.length - 1))
                        overlaid = true
                charts[i].setOverlayed( overlaid )
                charts[i].model.set "field", query
                if i < querys.length - 1
                        charts[i].showOverlay(querys[i+1])                       
        if max > querys.length
                if charts.length > 0
                        console.log "chart "+(charts.length-1)+": overlay removed"
                        charts[charts.length-1].overlayRemoved()
        first_time = false

explanations = {}
getExplanation = (code,year) ->
        years = explanations[code]
        console.log "got years ",years
        if years
                year = parseInt(year)
                explanation = years[year]
                if not explanation
                        explanation = years[Object.keys(years)[0]]
                #console.log explanations                        
                return explanation
        return null
                
window.handleExplanations = (data) ->
        row = 1
        code = null
        explanation = null
        years = null
        for entry in data.feed.entry
                title = entry.title.$t
                if title.search( /B[0-9]+/ ) == 0
                        code = entry.content.$t
                if title.search( /D[0-9]+/ ) == 0
                        explanation = entry.content.$t
                if title.search( /F[0-9]+/ ) == 0
                        years = entry.content.$t
                        years = years.split(",")
                        if code != null and explanation != null
                                for _year in years
                                        year = parseInt(_year)
                                        curCodeExpl = explanations[code]
                                        if not curCodeExpl
                                                explanations[code] = {}
                                        explanations[code][year] = explanation
                        code = explanation = null
        console.log explanations
                       
     
if document.createElementNS? and document.createElementNS('http://www.w3.org/2000/svg', "svg").createSVGRect?
        $( ->
                History.Adapter.bind window, 'statechange', handleNewState
                query = window.location.search.slice(1)
                if query.length == 0
                        query = "plpsq1"
                querys = query.split("/")
                console.log "Q",querys
                if querys.length == 1
                        while budget_array_data[querys[0]]
                                up = budget_array_data[querys[0]].u
                                if up
                                        querys.unshift up
                                else
                                        break
                state = History.getState()
                if state.data?.length and state.data.length> 0
                        handleNewState()
                else
                        console.log "xxx",state.data.length
                        History.replaceState(querys,null,"?"+querys.join("/"))
                        console.log "pushed "+querys
                $(document).keyup (e) ->
                        if e.keyCode == 27
                                removeState()
                $(".btnCancel:last").live("click", -> removeState())
                
                $("body").append('<script type="text/javascript" src="http://spreadsheets.google.com/feeds/cells/0AqR1sqwm6uPwdDJ3MGlfU0tDYzR5a1h0MXBObWhmdnc/od6/public/basic?alt=json-in-script&callback=window.handleExplanations"></script>')

                )
else
        $("#charts").hide()
