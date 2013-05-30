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
                                @set 'data', budget_array_data[field]
                        else
                                console.log('field '+field+' is '+data)

class FieldSelector extends Backbone.View
        initialize: (@options) ->
                _.bindAll @
                @template = $(@el).attr('data-template')

        render: () ->

        select: () ->
                @$(".btn").click()
                        
        events:
                "click .btn": (e) ->
                        template = @template
                        await setTimeout((defer _), 10)
                        @$(".btn-toolbar").each((idx) ->
                                el = $(@)
                                for i in ["1","2"]
                                        field = el.attr("data-field"+i)
                                        value = el.find(".btn.active:first").attr("data-value"+i)
                                        if not value
                                                value = ""
                                        if field 
                                                console.log field,"-->",value
                                                template = template.replace(new RegExp(field, 'g'),value)
                        )
                        @model.set 'field',  template
                

class BubbleChart extends Backbone.View
        initialize: (@options) ->
                _.bindAll @

                console.log "BubbleChart:initialize", @model
                
                @width = 970
                @height = 550
                @groupPadding = 10
                @totalValue = @options.totalValue ? 400000000
                console.log "totalValue !!! ",@totalValue
        	        
        	# d3 settings
                @defaultGravity = 0.1
                @defaultCharge = (d) -> if (d.value < 0) then 0 else -Math.pow(d.radius,2.0)/8

                @links = []
                @force = {}
                @svg = {}
                @circle = {}
                @gravity = null
                @charge = null
                @changeTickValues = [-0.25, -0.15, -0.05, 0.05, 0.15, 0.25]
                @fillColor = d3.scale.ordinal().domain([-3,-2,-1,0,1,2,3]).range (["#ddad13", "#eeca7c","#e4d0ae","#AAA","#a3aad3", "#747fba", "#3e48b5"])
                @strokeColor = d3.scale.ordinal().domain([-3,-2,-1,0,1,2,3]).range(["#c09100", "#e7bd53","#d9c292","#999","#7d88c6", "#4659a5", "#00199f"])
                @getFillColor = (d) -> if (d.isNegative) then "#fff" else @fillColor(d.changeCategory)

                @getStrokeColor = (d) -> @strokeColor(d.changeCategory);

                @pFormat = d3.format(".1%")
                @pctFormat = (p) -> if (p == Infinity || p == -Infinity)  then "N.A" else @pFormat(p)
                @tickChangeFormat = d3.format("%")
                @simpleFormat = d3.format(",")
                @simpleDecimal = d3.format(",.2f")
                @bigFormat = (n) -> formatNumber(n*1000)
                @nameFormat = (n) -> n
                
                @rScale = d3.scale.pow().exponent(0.5).domain([0,@totalValue]).range([1,200])
                @radiusScale = (n) -> @rScale( Math.abs(n) )
                @changeScale = d3.scale.linear().domain([-0.28,0.28]).range([620,180]).clamp(true)
                @sizeScale = d3.scale.linear().domain([0,110]).range([0,1])
                
                @categorizeChange = (c) ->
                        if isNaN(c)     then return 0
                        if c < -0.25    then return -3
                        if c < -0.05    then return -2
                        if c < -0.001   then return -1
                        if c <= 0.001   then return 0
                        if c <= 0.05    then return 1
                        if c <= 0.25    then return 2
                        return 3
                @totalSort = (alpha) ->
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
                @buoyancy = (alpha) ->
                                return (d) =>
                                        targetY = - (d.changeCategory / 3) * @boundingRadius
                                        d.y = d.y + (targetY - d.y) * (@defaultGravity) * alpha * alpha * alpha * 500
                # data settings
                @currentYearDataColumn = 'budget_1'
                @previousYearDataColumn = 'budget_0'
                
                # chart settings
                @boundingRadius = @radiusScale(@totalValue)
                @maxRadius = null
                @centerX = @width / 2
                @centerY = @height / 2

                @model.bind 'change:data', @updateData

                d3.select(@el).html("")
                @svg = d3.select(@el)
                         .append("svg:svg")
                         .attr("width", @width)
                @force = null
                @nodes = []
                console.log "init done"
        
        updateData: () ->
                oldNodes = @nodes
                @nodes = []

                # Builds the nodes data array from the original data
                for n in @model.get 'data'
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
                        out.code = n.id
                        out.radius = @radiusScale(n[@currentYearDataColumn])
                        out.group = strings[n.p]
                        out.groupvalue = n.pv
                        out.change = n.change/100.0
                        out.changeCategory = @categorizeChange(n.change/100.0)
                        out.value = n[@currentYearDataColumn]
                        out.name = strings[n.name]
                        out.isNegative = (n[@currentYearDataColumn] < 0)
                        out.positions = n.positions
                        ###
                        #  if (n.positions.total) 
        	    	#     out.x = n.positions.total.x + (n.positions.total.x - (@width / 2)) * 0.5
        	    	#     out.y = n.positions.total.y + (n.positions.total.y - (150)) * 0.5
        	    	###

                        if ((n[@currentYearDataColumn] > 0) != (n[@previousYearDataColumn] > 0))
                                out.change = "N.A."
                                out.changeCategory = 0
                        if (n.change==99999)
                                out.change = "N.A."
                                out.changeCategory = 3
                                

                        @nodes.push(out)
	    
                #@nodes.sort( (a, b) -> Math.abs(b.value) - Math.abs(a.value) )
	    
                @render()

        showOverlay: (d,el) ->
                x = Number(el.attr('cx'))
                y = Number(el.attr('cy'))
                scale = @height / d.radius / 3
                console.log d.radius, @height, scale
                origin = "translate(#{@centerX},#{@centerY})rotate(0)translate(1,1)scale(1)"
                target = "translate(#{@centerX},#{@centerY})rotate(120)translate(#{-x*scale},#{-y*scale})scale(#{scale})"
                console.log "origin:",origin
                console.log "target:",target

                $("#overlayContainer")
                        .css("display","block")

                @svg.selectAll("circle")
                        .transition()
                                .duration(1000)
                                .attrTween("transform",
                                           -> d3.interpolateString( origin, target )
                                        )

                $("#overlayContainer div")
                        .css("opacity",0)
                        .stop(true)
                        .animate({opacity:0.9},1000, ->
                                                     $("#overlayContainer").css("display","block")
                                )

                $("#overlayContainer #close").click @removeOverlay
                $("#overlayContainer .name").html "#{d.group}"
                #$("#overlayContainer .department").html "#{d.group}"
                $("#tooltip").hide()
                chart = $("#overlayContainer .chart")
                drilldownData = new CompareData
                console.log "DDD",d.groupvalue
                @drilldown = new BubbleChart
                        el: chart
                        model: drilldownData
                        totalValue: d.groupvalue
                drilldownData.set 'field', (@model.get 'field')+"/"+d.code.slice(0,4)

        removeOverlay: ->
                origin = @svg.select("circle").attr("transform")
                target = "translate(#{@centerX},#{@centerY})rotate(0)translate(1,1)scale(1)"
                console.log "origin:",origin
                console.log "target:",target
                @svg.selectAll("circle")
                        .transition()
                                .duration(1000)
                                .attrTween("transform",
                                           -> d3.interpolateString( origin, target )
                                        )
                $("#overlayContainer div")
                        .stop(true)
                        .animate({opacity:0},1000, ->
                                                   $("#overlayContainer").css("display","none")
                                )
                @drilldown.svg.selectAll("circle")
                        .transition()
                                .duration(1000)
                                .attr("r",0)
                                .each("end", -> $("#overlayContainer svg").remove() )
                $("#overlay #close").off 'click'

        render: () ->
                @circle = @svg.selectAll("circle")
                              .data(@nodes, (d) -> d.sid );

                that = @
                @circle.enter()
                        .append("svg:circle")
                         .attr("transform","translate(#{@centerX},#{@centerY})rotate(0)translate(1,1)scale(1)")
                        .style("stroke-width", 1)
                        .style("fill", (d) => @getFillColor(d) )
                        .style("stroke", (d) => @getStrokeColor(d) )
                        .on("click", (d,i) ->
                                el = d3.select(@)
                                that.showOverlay(d,el)
                                )
                        .on("mouseover", (d,i) ->
                                console.log "mouseover"
                                el = d3.select(@)
                                svgPos = $(that.el).find("svg").position()
                                xpos = Number(el.attr('cx'))+svgPos.left+that.centerX
                                ypos = (el.attr('cy') - d.radius - 10)+svgPos.top+that.centerY
                                console.log "tooltip ",xpos,ypos
                                el.style("stroke","#000").style("stroke-width",3)
                                d3.select("#tooltip")
                                        .style('top',ypos+"px")
                                        .style('left',xpos+"px")
                                        .style('display','block')
                                        .classed('plus', (d.changeCategory > 0))
                                        .classed('minus', (d.changeCategory < 0))
                                d3.select("#tooltip .name").html(that.nameFormat(d.name))
                                d3.select("#tooltip .department").text(d.group)
                                d3.select("#tooltip .value").html(that.bigFormat(d.value)+" \u20aa")
                                pctchngout = if (d.change == "N.A.") then "N.A" else that.pctFormat(d.change)
                                d3.select("#tooltip .change").html(pctchngout)
                                console.log "mouseover out"
                                )
                        .on("mouseout", (d,i) ->
                                d3.select(@)
                                        .style("stroke-width",1)
                                        .style("stroke", (d) -> that.getStrokeColor(d) )
                                d3.select("#tooltip").style('display','none')
                                )

                @circle.transition().duration(1000)
                        .attr("r", (d) -> d.radius )
                        .style("fill", (d) => @getFillColor(d) )
                        .style("stroke", (d) => @getStrokeColor(d) )
                @circle.exit().transition().duration(1000)
                        .attr("r", (d) -> 0)
                        .remove()

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
                #@circle.call(@force.drag)

	# getCirclePositions: function(){
	#     var that = this
	#     var circlePositions = {};
	#     this.circle.each(function(d){
		
	# 	circlePositions[d.sid] = {
	# 	    x:Math.round(d.x),
	# 	    y:Math.round(d.y)
	# 	}
		
		
	#     });
	#     return JSON.stringify(circlePositions)
	# },

createFrame = (id) ->
        compareData = new CompareData
        bubbleChart = new BubbleChart
                el: $("#"+id+" .chart")
                model: compareData
        selector = new FieldSelector
                el: $("#"+id+" .selector")
                model: compareData
        selector.select()

if document.createElementNS? and document.createElementNS('http://www.w3.org/2000/svg', "svg").createSVGRect?
        $( ->
                $("#charts").carousel( interval: false)
                createFrame( "TBFrame" )
                createFrame( "TTFrame" )
                createFrame( "BBFrame" )
                )
else
        $("#charts").hide()
