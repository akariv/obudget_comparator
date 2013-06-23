L = (x...) -> console.log x...

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
                title: "?"
                link: null
        initialize: ->
                @on 'change:field', () ->
                        field = @get 'field'
                        data = budget_array_data[field]
                        if data
                                @set 'code', data.c
                                @set 'link', data.l
                                @set 'title', data.t
                                @set 'data', data.d

globalSelectedItem = null
globalTooltipItem = null
globalTooltipShown = false
showTooltip = (d,xpos,ypos,that) ->
        if not globalTooltipItem
                d3.select("#tooltip").style('display','none')
                globalTooltipShown = false
                return
        svgPos = $("div.chart:last").offset()
        tail = 107.5
        xpos += that.centerX
        if xpos < 135
                tail += 135 - xpos
                xpos = 135
        if xpos > (that.width - 135)
                tail -= xpos - (that.width - 135)
                xpos = (that.width - 135)
        xpos += 4 # instead of left
        if ypos > -that.height/4
                ypos = ypos - d.radius - 10 +svgPos.top+that.centerY
                $("#tooltipContainer").css("bottom",0)
                d3.select("#tooltip .arrow.top").style("display","none")
                d3.select("#tooltip .arrow.bottom").style("display","block")
        else
                ypos = ypos + d.radius + 10 +svgPos.top+that.centerY
                $("#tooltipContainer").css("bottom","")
                d3.select("#tooltip .arrow.top").style("display","block")
                d3.select("#tooltip .arrow.bottom").style("display","none")
        d3.select("#tooltip")
                .style('top',ypos+"px")
                .style('left',xpos+"px")
                
        if globalTooltipShown then return

        d3.select("#tooltip")
                .style('display','block')
                .classed('plus', (d.changeCategory > 0))
                .classed('minus', (d.changeCategory < 0))
                .classed('newitem', d.newitem)
                .classed('disappeared', d.disappeared)
                
        d3.select("#tooltip .name").html(d.name)
        itemNumber = d.code
        if d.bcodes.length > 0
                bcodes = _.map(d.bcodes, ((x) -> x[0]))
                if (bcodes.length!=1) or (bcodes[0]!=d.code)
                        itemNumber += " ("+(bcodes.join(","))+" ב-2012)"
        d3.select("#tooltip .itemNumber").text(itemNumber)
        d3.select("#tooltip .explanation").html(getExplanation(d.sid,2014,d.name))
        if d.history
                if d.history > 0
                        d3.select("#tooltip .history")
                                .text("מ2009 ההוצאות חורגות ב#{d.history}%+ בממוצע מהתכנון")
                                .classed("plus",true)
                                .classed("minus",false)
                                .attr("data-categories","#{d.changeCategory}:#{d.projectedChangeCategory}")
                else if d.history < 0
                        d3.select("#tooltip .history")
                                .text("מ-2009 בממוצע #{-d.history}% מהתקציב אינו מנוצל")
                                .classed("plus",false)
                                .classed("minus",true)
                                .attr("data-categories","#{d.changeCategory}:#{d.projectedChangeCategory}")
        else
                d3.select("#tooltip .history").text("")
                                
        d3.select("#tooltip .value").html(formatNumber(d.value*1000)+" \u20aa")
        d3.selectAll("#tooltip .arrow").style("right",tail+"px")
        if d?.changestr
                pctchngout = d.changestr
        else
                pctchngout = if (d.change == "N.A.") then "N.A" else that.pctFormat(Math.abs(d.change))
        pctchngout = pctchngout + (if d.change < 0 then "-" else "+")
        d3.select("#tooltip .change").html( pctchngout)
        globalTooltipShown = true
        

class BubbleChart extends Backbone.View


        # Colors
        fillColor: (changeCategory) -> 
                _fillColor = d3.scale.ordinal().domain([-4,-3,-2,-1,0,1,2,3,4]).range (["#9F7E01", "#dbae00", "#eac865","#f5dd9c","#AAA","#bfc3dc", "#9ea5c8", "#7b82c2", "#464FA1"])
                _fillColor(changeCategory)

        strokeColor: (code, changeCategory) ->
                if code == globalSelectedItem then return "#FF0"
                _strokeColor = d3.scale.ordinal().domain([-4,-3,-2,-1,0,1,2,3,4]).range(["#796001", "#c09100", "#e7bd53","#d9c292","#999","#a7aed3", "#7f8ab8", "#4f5fb0","#1A2055"])
                _strokeColor(changeCategory);

        getFillColor: (d) -> @fillColor(d.changeCategory)

        getStrokeColor: (d) -> @strokeColor(d.sid, d.changeCategory)

        getProjFillColor: (d) -> @fillColor(d.projectedChangeCategory)

        getProjStrokeColor: (d) -> @strokeColor(null, d.projectedChangeCategory)


        strokeWidth: (d) ->
                if d.code == globalSelectedItem then 5 else 1

        # Formatting
        pctFormat: (p) ->
                pFormat = d3.format(".1%")
                if (p == Infinity || p == -Infinity)  then "N.A" else pFormat(p)

        # Force Layout
        defaultCharge:
                (d) -> if (d.value < 0) then 0 else -Math.pow(d.radius,2.0)/8  


        totalSort: (alpha) ->
                return (d) =>
                        cat = @budget_categories[d.sid] 
                        targetX = targetY = 0
                        bump = 0.02
                        radiusx = 10
                        radiusy = 0
                        if @showSplit
                                radiusx = @width*0.2
                                radiusy = @height*0.15
                                bump = 0.04
                        if cat and cat != 7
                                cat = cat * Math.PI * 0.333
                                targetY = radiusy * Math.sin(cat)
                                targetX = radiusx * Math.cos(cat)
                        if d.isNegative
                                if d.changeCategory > 0
                                        d.x = -200
                                else 
                                        d.x = 1100
                        d.y = d.y + (targetY - d.y) * (@defaultGravity + bump) * alpha
                        d.x = d.x + (targetX - d.x) * (@defaultGravity + bump) * alpha
                        
        buoyancy: (alpha) ->
                return (d) =>
                        targetY = - (d.changeCategory / 3) * @boundingRadius
                        d.y = d.y + (targetY - d.y) * (@defaultGravity) * alpha * alpha * alpha * 500

        # Data handling
        categorizeChange: (c) ->
                if isNaN(c)     then return 0
                if c < -0.5    then return -4
                if c < -0.25    then return -3
                if c < -0.05    then return -2
                if c < -0.001   then return -1
                if c <= 0.001   then return 0
                if c <= 0.05    then return 1
                if c <= 0.25    then return 2
                if c <= 0.5    then return 3
                return 4
         
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
                @showSplit = false
                @categories = null

        	# d3 settings
                @defaultGravity = 0.1
                               
                @force = @svg = @circle = null
                
                # chart settings
                @centerX = @width / 2
                @centerY = @height / 2

                @model.bind 'change:data', =>
                        @updateData( @model.get 'data' )

                d3.select(@el).html("")
                @svg = d3.select(@el)
                         .append("svg:svg")
                         #.attr("width", @width)
                @svg.on("click", ->
                        removeState()
                        false
                )
                $("div[data-id='#{@id}'] .btnSpend").click =>
                        state.querys = [ "00" ] 
                        History.pushState(state,null,"?" + state.querys.join("/") )
                        false
                $("div[data-id='#{@id}'] .btnIncome").click =>
                        state.querys = [ "0000" ] 
                        History.pushState(state,null,"?" + state.querys.join("/") )
                        false
                $("div[data-id='#{@id}'] .splitter").click =>
                        @showSplit = not @showSplit
                        @svg.selectAll("g.splitter circle").transition()
                                .duration(500)
                                .style("opacity",if @showSplit then 1 else 0)
                        @svg.selectAll("g.splitter text").transition()
                                .duration(500)
                                .style("opacity",if @showSplit then 1 else 0)
                        $("div[data-id='#{@id}'] .splitter").toggleClass("on", @showSplit)
                        @force.start()
                        console.log "LL", @showSplit
                        false
                @budget_categories = {"0001": 2, "0002": 2, "0003": 2, "0004": 2, "0005": 2, "0006": 2, "0007": 1, "0008": 2, "0009": 2, "0010": 1, "0011": 2, "0012": 6, "0013": 2, "0014": 2, "0015": 1, "0016": 1, "0017": 1, "0018": 2, "0019": 4, "0020": 3, "0021": 3, "0023": 3, "0024": 3, "0025": 3, "0026": 4, "0027": 3, "0029": 5, "0030": 3, "0032": 4, "0033": 4, "0034": 5, "0035": 4, "0036": 4, "0037": 4, "0038": 4, "0039": 4, "0040": 5, "0041": 5, "0042": 5, "0043": 5, "0045": 6, "0046": 1, "0051": 3, "0052": 1, "0053": 2, "0054": 4, "0056": 3, "0060": 3, "0067": 3, "0068": 2, "0070": 5, "0073": 5, "0076": 4, "0078": 4, "0079": 5, "0083": 5, "0084": 6, "0055": 1 , "0047": 7}
                await setTimeout((defer _),100) # allow DOM to settle
                that = this
                search = $("div[data-id='#{@id}'] .mysearch")
                $("div[data-id='#{@id}'] .mysearch-open").click( ->
                        search.select2("open")
                        false
                )
                search.select2(
                        placeholder: "חפשו סעיף ספציפי"
                        allowClear: true
                        data: () =>
                                console.log "Titles: ",@titles
                                { 'results': @titles }
                )
                search.on("select2-open",
                        (e) ->
                                $("div[data-id='#{that.id}'] .breadcrumbs").css("visibility","hidden")
                ).on("select2-close",
                        (e) ->
                                $("div[data-id='#{that.id}'] .breadcrumbs").css("visibility","visible")
                ).on("select2-highlight",
                        (e) ->
                                that.selectItem(code: e.choice.id)
                ).on("change",
                        (e) ->
                                if e.added
                                        that.selectItem(code: e.added.id)
                                        for x in e.added.state
                                                addState(x)
                                        search.select2("val", "")
                                else
                                        that.selectItem(null)
                )

        collectTitles: (titles, field, prefix = '', _state = []) ->
                if not field then return
                data = budget_array_data[field]
                if data
                        for n in data.d
                                code = n.id
                                name = n.n
                                if name and code
                                        titles.push( id:code, text:prefix + name, code:code, state:_state, fullpath:data.c+";"+code )
                                @collectTitles( titles, n.d, prefix + name + ' | ', _state.concat([n.d]) )
        
        updateData: (data) ->
                oldNodes = []

                sum = 0
                for x in data
                        sum += x.b1
                @totalValue = sum ? 400000000
                if @?.nodes
                        for node in @nodes
                                oldNodes.push(node)
                @nodes = []
                @titles = []
                @collectTitles( @titles, @model.get 'field' )
                
                rScale = d3.scale.pow().exponent(0.5).domain([0,@totalValue]).range([7,165])
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
                        out.code = n.jc
                        out.radius = radiusScale(n[currentYearDataColumn])
                        out.change = n.c/100.0
                        out.changeCategory = @categorizeChange(n.c/100.0)
                        out.value = n[currentYearDataColumn]
                        out.name = n.n
                        out.isNegative = (n[currentYearDataColumn] < 0)
                        out.positions = n.positions
                        out.drilldown = n.d
                        out.history = n.pp
                        out.bcodes = n.bc
                        if out.history
                                out.projectedValue = out.value*(out.history+100)/100.0
                                out.projectedRadius = radiusScale(out.projectedValue)
                                out.projectedChangeCategory = @categorizeChange(((n.c+100)*(n.pp+100)-10000)/10000.0)

                        ###
                        #  if (n.positions.total) 
        	    	#     out.x = n.positions.total.x + (n.positions.total.x - (@width / 2)) * 0.5
        	    	#     out.y = n.positions.total.y + (n.positions.total.y - (150)) * 0.5
        	    	###

                        if ((n[currentYearDataColumn] > 0) && (n[previousYearDataColumn] < 0))
                                out.changestr = "הפך מהכנסה להוצאה"
                                out.changeCategory = 4
                        if ((n[currentYearDataColumn] < 0) && (n[previousYearDataColumn] > 0))
                                out.changestr = "הפך מהוצאה להכנסה"
                                out.changeCategory = -4
                        out.newitem = false
                        out.disappeared = false
                        if (n.c==99999)
                                out.changestr = "תוקצב מחדש"
                                out.changeCategory = 4
                                out.newitem = true
                        if (out.value == 0)
                                out.disappeared = true
                                out.value = n[previousYearDataColumn]
                                out.radius = radiusScale(n[previousYearDataColumn])


                        @nodes.push(out)

                @nodes.sort( (a,b) -> Math.abs(b.value) - Math.abs(a.value) )
                @titles.sort( (a,b) -> if a.code > b.code then 1 else -1 )
                        
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
                origin = "translate(#{@centerX},#{@centerY})rotate(0)translate(1,1)scale(1)"
                target = "translate(#{@centerX},#{@centerY})rotate(120)translate(#{-node.x*scale},#{-node.y*scale})scale(#{scale})"

                if @transitiontime == 0
                        @svg.selectAll("circle,text").attr("transform",target)
                else
                        @svg.selectAll("circle,text")
                                .transition()
                                        .duration(@transitiontime)
                                        .attrTween("transform",
                                                   -> d3.interpolateString( origin, target )
                                                )
                $("#tooltip").hide()

        overlayRemoved: ->
                @setOverlayed(false)
                @overlayShown = false
                
                origin = @svg.select("circle").attr("transform")
                target = "translate(#{@centerX},#{@centerY})rotate(0)translate(1,1)scale(1)"

                @svg.selectAll("circle,text")
                        .transition()
                                .duration(@transitiontime)
                                .attrTween("transform",
                                           -> d3.interpolateString( origin, target )
                                        )
                @circle.attr("r", (d) -> d.radius )

        selectItem: (d) ->
                globalSelectedItem = d.code
                @circle.style("stroke-width",@strokeWidth)
                @circle.style("stroke", @getStrokeColor)

        open_modal: (select) ->
                that = this
                $(".modal").remove()
                $(".modal-template").clone().appendTo('body')
                $(".modal-template:last").toggleClass("modal-template",false).toggleClass("modal",true)
                $(".modal .tab-pane").each( (e) ->
                        $(@).attr("id",$(@).attr("data-id"))
                )
                $(".modal nav-pills a").tab()
                $(".modal li").toggleClass("active",false)
                $(".modal a[href='#{select}']").parent().toggleClass("active",true)
                $(".modal .tab-pane").toggleClass("active",false)
                $(".modal #{select}").toggleClass("active",true)

                $('.modal .modal-footer .btn-primary').css("display","none")
                $('.modal .modal-footer [data-rel="'+select+'"]').css("display","inherit")
                $('.modal a[data-toggle="tab"]').on('shown', (e) ->
                        _select = $(e.target).attr("href")
                        $('.modal .modal-footer .btn-primary').css("display","none")
                        $('.modal .modal-footer [data-rel="'+_select+'"]').css("display","inherit")
                )
                                                
                field = that.model.get('field')

                $(".modal .shareItemDetails h3").text(@model.get('title'))
                $(".modal .shareItemDetails p").html(getExplanation(field))

                titles = _.map(that.nodes,(d)->{id:d.sid,text:d.name,title:d.name,path:field+";"+d.sid})
                titles.unshift({id:field,text:"בחירת התרשים כמות שהוא",title:that.model.get('title'),path:field})
                await setTimeout((defer _),100) # allow DOM to settle
                item_select = $(".modal .item-select")
                set_path = (path,title,code) ->
                        $(".modal .embed-code").val("<iframe src='http://compare.open-budget.org.il/?#{path}' width='640' height='900'/>")
                        $(".modal .direct-link").val("http://compare.open-budget.org.il/?#{path}")
                        $(".modal .facebook-share").click( ->
                                sharer = "https://www.facebook.com/sharer/sharer.php?u=http://compare.open-budget.org.il/of/#{path}.html"
                                window.open(sharer, 'sharer', 'width=626,height=436')
                                window.ga('send', 'event', 'share', 'facebook')
                                false
                        )
                        $(".modal .shareItemDetails h3").text(title)
                        $(".modal .shareItemDetails p").html(getExplanation(code))
                        $(".modal .shareThumb").attr("src","http://compare.open-budget.org.il/images/large/#{path}.jpg")
                        $(".modal .shareThumb").attr("alt",title)
                        $(".modal .photo-download").click( ->
                                sharer = "http://compare.open-budget.org.il/images/large/#{path}.jpg"
                                window.open(sharer, 'sharer')
                                window.ga('send', 'event', 'share', 'photo')
                                false
                        )
                item_select.select2(
                        placeholder: "שיתוף התרשים הנוכחי"
                        allowClear: false
                        data: titles
                ).on("change", (e) ->
                        if e.added
                                path = e.added.path
                                title = e.added.title
                                code = e.added.id
                                console.log "AAA",path
                                item_select.select2("close")
                                set_path(path,title,code)
                )
                set_path(field)
                first = true
                $(".modal").modal()
                $(".modal").modal("show")
                $(".modal").on("shown", ->
                        await setTimeout((defer _),100) # allow DOM to settle
                        if first
                                item_select.select2("open")
                                first = false
                ).on("hide", ->
                        item_select.select2("close")
                )

        render: () ->

                that = this

                field = @model.get 'field'
        
                $("div[data-id='#{@id}'] .btnSpend").css("display", "none")
                $("div[data-id='#{@id}'] .btnIncome").css("display", "none")
                $("div[data-id='#{@id}'] .splitter").css("display", "none")

                if field.indexOf("0000") == 0
                        moreinfo = "הכנסות בפועל 2012 לעומת תחזית הכנסות 2014, שיעור השינוי הוא ריאלי"
                else
                        moreinfo = "תקציב מקורי 2012 לעומת תקציב מקורי 2014, שיעור השינוי הוא ריאלי"
                $("div[data-id='#{@id}'] .moreinfo").text(moreinfo)
                
                if field == "0000"
                        $("div[data-id='#{@id}'] .btnSpend").css("display", "inherit")
                                
                if field == "00"
                        $("div[data-id='#{@id}'] .btnIncome").css("display", "inherit")
                        $("div[data-id='#{@id}'] .splitter").css("display", "inherit")
                else
                        console.log "LLL", field
        
                @setBreadcrumbs = (dd = null) =>
                        bc = $("div[data-id='#{@id}'] .breadcrumbs")
                        bc.find(".breadpart").remove()

                        actual_querys = []
                        for query in state.querys
                                actual_querys.push query
                                if query == @model.get 'field'
                                        break
                        depth = actual_querys.length
                        for query in actual_querys
                                depth -= 1
                                title = budget_array_data[query].t
                                if depth > 0
                                        bc.append("<span class='breadpart breadcrumbsParent' data-up='#{depth}'>#{title}</span>")
                                        bc.append("<span class='breadpart breadcrumbsSeparator'></span>")
                                else
                                        bc.append("<span class='breadpart breadcrumbsCurrent'>#{title}</span>")

                        bc.find(".breadcrumbsParent").click( ->
                                up_count = parseInt($(@).attr('data-up'))
                                removeState(up_count)
                                false
                                )

                        mshLinkCode = null
                        if not dd
                                mshLinkCode = @model.get 'code' 
                        else
                                bc.append("<span class='breadpart breadcrumbsSeparator'></span>")
                                bc.append("<span class='breadpart breadcrumbsChild'>#{dd.name}</span>")
                                mshLinkCode = dd.sid

                        if mshLinkCode
                                bc.append('<span class="breadpart breadcrumbsMsh"><a class="breadcrumbsLink" target="_new" href="http://budget.msh.gov.il/#'+mshLinkCode+
                                ',2014,0,1,1,1,0,0,0,0,0,0" class="active" data-toggle="tooltip" data-placement="bottom" title="מידע היסטורי אודות הסעיף הנוכחי">'+
                                '<i class="icon-bar-chart icon"></i></a></span><!--i class="icon-book icon-flip-horizontal icon"></i-->')

                        link = @model.get 'link'
                        if link
                                bc.append('<span class="breadpart breadcrumbsGov"><a class="breadcrumbsLink" target="_new" href="'+link+'" '+
                                'class="active" data-toggle="tooltip" data-placement="bottom" title="עיון בספר התקציב במשרד האוצר">'+
                                '<i class="icon-book icon-flip-horizontal icon"></i></a></span>')
                        $("div[data-id='#{@id}'] .breadcrumbsLink").click( ->
                                window.ga('send', 'event', 'learn', $(@).attr("href"))
                                true
                        )
                        $("div[data-id='#{@id}'] .breadcrumbsLink").tooltip()
                @setBreadcrumbs()
                $("div[data-id='#{@id}'] .splitter").tooltip()
                $("div[data-id='#{@id}'] .btnIncome").tooltip()
                $("div[data-id='#{@id}'] .btnSpend").tooltip()
                $("div[data-id='#{@id}'] .btnBack").tooltip()
                $("div[data-id='#{@id}'] .share-button").tooltip()
                $("div[data-id='#{@id}'] .share-button").click( ->
                        that.open_modal($(@).attr('data-tab-href'))
                )

                $("div[data-id='#{@id}'] .color-index").tooltip()
                
                if false
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
                                                false
                                        )
                container = $("div[data-id='#{@id}'] .overlayContainer")
                chartContainer = $("div[data-id='#{@id}'] .chartContainer")
                overlay = $("div[data-id='#{@id}'] .overlay")
                frame = $("div[data-id='#{@id}'] .frame")

                resizeFrame = () =>
                        @width = $(window).width() - 8
                        if @width > 900 then @width = 900
                        @centerX = @width/2 +4
                        @svg.attr "width", @width
                        @svg.style "width", @width+"px"
                        if not @overlayShown and @circle
                                @svg.selectAll("circle").attr("transform","translate(#{@centerX},#{@centerY})rotate(0)translate(0,0)scale(1)")
                        overlay.css("height",(chartContainer.height())+"px")
                        if chartContainer.offset()
                                overlay.css("top",(chartContainer.offset().top)+"px")

                $(window).resize resizeFrame
                                
                resizeFrame()
                                                
                if @transitiontime > 0
                        overlay
                                .css("opacity",0)
                                .animate({opacity:0.9},@transitiontime)
                else
                        overlay
                                .css("opacity",0.9)

                @circle = @svg.selectAll("circle.regular")
                              .data(@nodes, (d) -> d.sid );
                        
                that = @
                @circle.enter()
                        .append("svg:circle")
                        .attr("transform","translate(#{@centerX},#{@centerY})rotate(0)translate(0,0)scale(1)")
                        .attr("data-title", (d) -> d.name )
                        .style("stroke-width", @strokeWidth )
                        .style("fill", @getFillColor )
                        .style("stroke", @getStrokeColor )
                        .style("cursor",(d) => if budget_array_data[d.drilldown] then "pointer" else "default")
                        .classed('regular',true)
                        .classed('newitem', (d) -> d.newitem)
                        .classed('disappeared', (d) -> d.disappeared)
                        .on("click", (d,i) ->
                                if budget_array_data[d.drilldown]
                                        addState(d.drilldown)
                                #else
                                #        that.setBreadcrumbs(d)
                                d3.event.stopPropagation()
                                false
                                )
                        .on("mouseover", (d,i) ->
                                el = d3.select(@)
                                if false and not d.newitem and not d.disappeared 
                                        anim = that.svg.insert("svg:circle",":first-child")
                                                .attr("cx",el.attr("cx"))
                                                .attr("cy",el.attr("cy"))
                                                .attr("transform",el.attr("transform"))
                                                .attr("r",el.attr("r"))
                                                .style("stroke",el.style("stroke"))
                                                .style("fill",el.style("fill"))
                                                .classed("tooltiphelper-"+d.sid,true)
                                        anim.transition().duration(500)
                                                .attr("r", d.projectedRadius )
                                                .style("fill", that.getProjFillColor(d) )
                                        el.style("stroke-dasharray","5,5")
                                          .style("fill","rgba(255,255,255,0)")
                                if d.drilldown
                                        el.style("stroke","#000").style("stroke-width",3)                                      
                                globalTooltipItem = d.sid
                                showTooltip(d,Number(el.attr('cx')), Number(el.attr('cy')),that)
                                )
                        .on("mouseout", (d,i) ->
                                globalTooltipItem = null
                                d3.selectAll("circle.tooltiphelper-"+d.sid).remove()
                                d3.select(@)
                                        .attr("r", d.radius )
                                        .style("stroke-width", that.strokeWidth )
                                        .style("stroke", that.getStrokeColor(d) )
                                        .style("stroke-dasharray",null)
                                        .style("fill", that.getFillColor(d) )
                                showTooltip()
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
                #fb_iframe = '<iframe src="http://www.facebook.com/plugins/like.php?locale=he_IL&href=http%3A%2F%2Fcompare.open-budget.org.il%2Fp%2F'+(@model.get 'field')+'.html&amp;send=false&amp;layout=button_count&amp;width=200&amp;show_faces=false&amp;font&amp;colorscheme=light&amp;action=like&amp;height=21&amp;appId=469139063167385" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:200px; height:21px;" allowTransparency="true"></iframe>'
                #$("div[data-id='#{@id}'] .btnShareContainer").append("<div class='fb-like' data-href='http://compare.open-budget.org.il/p/#{@model.get 'field'}.html' data-send='false' data-layout='button_count' data-width='200' data-show-faces='false'></div>")
                #$("div[data-id='#{@id}'] .btnShareContainer").append(fb_iframe)
                @force = d3.layout
                                .force()
                                .nodes(@nodes)
                		.size([@width, @height])
                		.gravity(-0.01)
                		.charge(@defaultCharge)
                		.friction(0.9)
                                .on("tick", (e) =>
                                        maxx = -1000
                                        minx = 1000
                                        maxy = -1000
                                        miny = 1000 
                                        avgx = 0
                                        avgy = 0
                                        maxcatx = {}
                                        mincatx = {}
                                        maxcaty = {}
                                        mincaty = {}
                                        for i in [1..7]
                                                maxcatx[i] = maxcaty[i] = -1000
                                                mincatx[i] = mincaty[i] = 1000
                                        num = @nodes.length
                                        @circle .each(@totalSort(e.alpha))
                                                .each(@buoyancy(e.alpha))
                                                .each((d) ->
                                                        _maxx = d.x + d.radius
                                                        _minx = d.x - d.radius
                                                        _maxy = d.y + d.radius
                                                        _miny = d.y - d.radius
                                                        maxx = if _maxx > maxx then _maxx else maxx
                                                        minx = if _minx < minx then _minx else minx
                                                        maxy = if _maxy > maxy then _maxy else maxy
                                                        miny = if _miny < miny then _miny else miny
                                                        avgx = (maxx + minx) / 2.0
                                                        avgy = that.centerY + miny - 10
                                                        cat = that.budget_categories[d.sid]
                                                        if that.showSplit and cat
                                                                maxcatx[cat] = if _maxx > maxcatx[cat] then _maxx else maxcatx[cat]
                                                                mincatx[cat] = if _minx < mincatx[cat] then _minx else mincatx[cat]
                                                                maxcaty[cat] = if _maxy > maxcaty[cat] then _maxy else maxcaty[cat]
                                                                mincaty[cat] = if _miny < mincaty[cat] then _miny else mincaty[cat]
                                                )
                                                .attr("cx", (d) -> d.x - avgx )
                                                .attr("cy", (d) -> d.y - avgy )
                                                .each((d) ->
                                                        if d.sid == globalTooltipItem
                                                                showTooltip(d,d.x-avgx, d.y,that)
                                        )
                                        if that.showSplit
                                                for i in [1..7]
                                                        radius = if (maxcaty[i]  - mincaty[i]) > (maxcatx[i] - mincatx[i]) then (maxcaty[i]  - mincaty[i]) else (maxcatx[i] - mincatx[i])
                                                        radius = radius / 2 + 5
                                                        @svg.select("circle[data-category='#{i}']")
                                                            .attr("cx", (maxcatx[i] + mincatx[i])/2-avgx)
                                                            .attr("cy", (maxcaty[i] + mincaty[i])/2-avgy)
                                                            .attr("r",  radius)
                                                        @svg.selectAll("text[data-category='#{i}']")
                                                            .attr("x", (maxcatx[i] + mincatx[i])/2-avgx)
                                                            .attr("y", (maxcaty[i] + mincaty[i])/2-avgy + radius)

                                ).start()
                @initCategories()

        initCategories: () ->
                if @categories?
                        return
                @categories = [ [ 1, ['הביטחון','והסדר הציבורי' ]],
                               [ 2, ['המשרדים','המנהליים' ]],
                               [ 3, ['השירותים','החברתיים' ]],
                               [ 4, [ 'ענפי המשק' ]],
                               [ 5, [ 'תשתיות','ובינוי' ]],
                               [ 6, [ 'הוצאות','מרכזיות','אחרות' ]],
                               [ 7, [ 'רזרבות' ]] ]
                @split_cats = @svg.append("svg:g")
                @split_groups = @split_cats.selectAll("g").data(@categories)
                        .enter()
                        .append("svg:g")
                        .classed("splitter",true)
                @split_groups.append("circle")
                                .attr("transform","translate(#{@centerX},#{@centerY})rotate(0)translate(0,0)scale(1)")
                                .attr("r",1)
                                .attr("cx", 0)
                                .attr("cy", 0)
                                .style("fill","none")
                                .style("stroke","#999")
                                .style("stroke-width",1)
                                .style("stroke-dasharray","5,5")
                                .style("opacity",0)
                                .attr("data-category", (d) -> d[0])
                for i in [0..2]
                        @split_groups.append("text")
                                        .attr("transform","translate(#{@centerX},#{@centerY})rotate(0)translate(0,0)scale(1)")
                                        .text((d) -> d[1][i])
                                        .attr("dy",(1.0*(i+1))+"em")
                                        .attr("width","100px")
                                        .attr("height","20px")
                                        .style("font-size", "1.2em")
                                        .style("stroke","#000")
                                        .attr("y",0)
                                        .attr("x",0)
                                        .style("opacity",0)
                                        .attr("text-anchor","middle")
                                        .attr("data-category", (d) -> d[0])


state = { querys: [], selectedStory: null }
charts = []
first_time = true

addState = (toAdd) ->
        if not state?.querys
                state.querys = []
        state.querys.push(toAdd)
        History.pushState(state,null,"?" + state.querys.join("/") )

removeState = (amount = 1)->
        globalTooltipItem = null
        showTooltip()
        if state.querys.length > amount
                for i in [0...amount]
                        state.querys.pop()
                History.pushState(state,null,"?" + state.querys.join("/") )

handleNewState = () ->
        state = History.getState()
        state = state.data
        query = "00"
        if not state.querys or state.querys.length == 0
                state.querys = ["00"]
        console.log "New state: ",state.querys
        if not state.selectedStory
                state.selectedStory = { 'title':"כך נראה תקציב המדינה בשנתיים הקרובות",
                'subtitle':null}
        for i in [0...state.querys.length]
                query = state.querys[i]
                nextquery = state.querys[i+1]
                id = "id"+i
                el = $("div[data-id='#{id}'] .chart")
                if el.size() == 0
                        title = state.selectedStory?.title or "התקציב הדו שנתי 2013-2014 לעומת תקציב 2012"
                        default_subtitle ='כך הממשלה מתכוונת להוציא מעל 400 מיליארד שקלים. העבירו את העכבר מעל לעיגולים וגלו כמה כסף מקדישה הממשלה לכל מטרה. לחצו על עיגול בשביל לצלול לעומק התקציב ולחשוף את הפינות החבויות שלו'
                        explanation = getExplanation(query)
                        if explanation != null
                                default_subtitle = explanation
                        subtitle = state.selectedStory.subtitle or default_subtitle
                        template = _.template( $("#chart-template").html(),{ id: id, title:title, subtitle:subtitle, code:query } )
                        $("#charts").append template
                        el =$("div[data-id='#{id}'] .chart")                       
                        charts[i] = new BubbleChart
                                el: el
                                model: new CompareData
                                id: id

        max = if state.querys.length > charts.length then state.querys.length else charts.length
        for i in [max-1..0]
                if i >= state.querys.length
                        charts[i].updateData([])
                        charts.pop()
                        continue

                query = state.querys[i]
                overlaid = false
                if (i < state.querys.length - 2) or (first_time and (i < state.querys.length - 1))
                        overlaid = true
                charts[i].setOverlayed( overlaid )
                charts[i].model.set "field", query
                if i < state.querys.length - 1
                        charts[i].showOverlay(state.querys[i+1])                       
        if max > state.querys.length
                if charts.length > 0
                        charts[charts.length-1].overlayRemoved()
        first_time = false
        $(".btnBack:first").css("display","none")
        window.ga('send', 'pageview', state.querys.join("/"))
        

explanations = {}
getExplanation = (code,year,title) ->
        years = explanations[code]
        explanation = null
        if years
                year = parseInt(year)
                explanation = years[year]
                if not explanation
                        explanation = years[Object.keys(years)[0]]
        if code != "0047" and title and title.indexOf("רזרבה") >= 0
                if not explanation
                        explanation = ""
                explanation += "<b>- תקציב זה מהווה רזרבה לפעילות המשרד/היחידה. אם בסוף השנה היקף הרזרבה יורד ב-100%, זה סימן שהמשרד/היחידה ניצלו את הרזרבה עד תום</b>"
        return explanation

gotStories = false
gotExplanations = false

window.handleExplanations = (data) ->
        row = 1
        code = null
        explanation = null
        years = null
        row = null

        handle_explanation = (code,explanation,years) ->
                years = years.split(",")
                for _year in years
                        year = parseInt(_year)
                        curCodeExpl = explanations[code]
                        if not curCodeExpl
                                explanations[code] = {}
                                explanations[code][year] = explanation
        
        for entry in data.feed.entry
                title = entry.title.$t
                newrow = title.substring(1)
                if newrow != row and code != null and explanation != null
                        handle_explanation(code, explanation, years or "")
                        code = explanation = years = null
                if title.search( /B[0-9]+/ ) == 0
                        code = entry.content.$t
                        code = if code.indexOf("00") == 0 then code else "00"+code
                        code = if code.indexOf("00X") == 0 or code.indexOf("00x") == 0 then "00"+code.substring(3) else code
                if title.search( /D[0-9]+/ ) == 0
                        explanation = entry.content.$t
                if title.search( /F[0-9]+/ ) == 0
                        years = entry.content.$t
        gotExplanations = true
        if gotStories and gotExplanations then init()
        
stories = {}
window.handleStories = (data) ->
        row = 1
        code = null
        title = null
        subtitle = null
        chartid = null
        for entry in data.feed.entry
                range = entry.title.$t
                if range.search( /B[0-9]+/ ) == 0
                        code = entry.content.$t
                if range.search( /C[0-9]+/ ) == 0
                        title = entry.content.$t
                if range.search( /D[0-9]+/ ) == 0
                        subtitle = entry.content.$t
                if range.search( /G[0-9]+/ ) == 0
                        chartid = entry.content.$t
                        stories[chartid] = { code:code, title:title, subtitle:subtitle }
                        code = title = subtitle = chartid = null
        gotStories = true
        if gotStories and gotExplanations then init()

init = () ->
        History.Adapter.bind window, 'statechange', handleNewState
        query = "00"
        ret_query = window.location.search.slice(1)
        if ret_query.length == 0
                ret_query = window.location.hash
                if ret_query.length > 0
                        ret_query = query.split("?")
                        if ret_query.length > 1
                                query = ret_query[1]
        else
                query = ret_query
        if stories[query]
                state.selectedStory = stories[query]
                query = state.selectedStory.code
        else
                state.selectedStory = null

        parse = query.split(";")
        if parse.length > 1
                query = parse[0]
                globalTooltipItem = globalSelectedItem = parse[1]
        state.querys = query.split("/")
        if state.querys.length == 1
                while budget_array_data[state.querys[0]]
                        up = budget_array_data[state.querys[0]].u
                        if up
                                state.querys.unshift up
                        else
                                break
        firstquery = state.querys[0]
        if !state.selectedStory
                state.selectedStory = { 'title':"התקציב הדו שנתי 2013-2014 לעומת תקציב 2012", 'subtitle':null }
        
        _state = History.getState()
        if _state.data?.querys and _state.data.querys.length> 0
                handleNewState()
        else
                History.pushState(state,null,"?"+state.querys.join("/"))
        $(document).keyup (e) ->
                if e.keyCode == 27
                        removeState()
                false
        $(".btnBack:last").live("click", ->
                removeState()
                false
        )
     
$( ->
        if document.createElementNS? and document.createElementNS('http://www.w3.org/2000/svg', "svg").createSVGRect?
                handleStories(stories_raw)
                handleExplanations(explanations_raw)
        )
                                

