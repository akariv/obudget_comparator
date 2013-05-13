formatNumber = function(n,decimals) {
    var s, remainder, num, negativePrefix, negativeSuffix, prefix, suffix;
    suffix = ""
    negativePrefix = ""
    negativeSuffix = ""
    if (n < 0) {
	negativePrefix = "";
	negativeSuffix = " in income"
	n = -n
    };
    
    if (n >= 1000000000000) {
        suffix = " trillion"
        n = n / 1000000000000
        decimals = 2
    } else if (n >= 1000000000) {
        suffix = " מיליארד"
        n = n / 1000000000
        decimals = 1
    } else if (n >= 1000000) {
        suffix = " מיליון"
        n = n / 1000000
        decimals = 1
    } 
    
    
    prefix = ""
    if (decimals > 0) {
        if (n<1) {prefix = "0"};
        s = String(Math.round(n * (Math.pow(10,decimals))));
        if (s < 10) {
            remainder = "0" + s.substr(s.length-(decimals),decimals);
            num = "";
        } else{
            remainder = s.substr(s.length-(decimals),decimals);
            num = s.substr(0,s.length - decimals);
        }
        
        
        return  negativePrefix + prefix + num.replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1,") + "." + remainder + suffix + negativeSuffix;
    } else {
        s = String(Math.round(n));
        s = s.replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1,");
        return  negativePrefix + s + suffix + negativeSuffix;
    }
};

Chart = function(fieldname){
    return {
	$ : jQuery,
	//defaults
	width           : 970,
	height          : 850,
	groupPadding    : 10,
	totalValue      : 400000000,
	
	//will be calculated later
	boundingRadius  : null,
	maxRadius       : null,
	centerX         : null,
	centerY         : null,
        
	//d3 settings
	defaultGravity  : 0.1,
	defaultCharge   : function(d){
            if (d.value < 0) {
                return 0
            } else {
                return -Math.pow(d.radius,2.0)/8 
            };
        },
	links           : [],
	nodes           : [],
	positiveNodes   : [],
	force           : {},
	svg             : {},
	circle          : {},
	gravity         : null,
	charge          : null,
	changeTickValues: [-0.25, -0.15, -0.05, 0.05, 0.15, 0.25],
	categorizeChange: function(c){
            if (isNaN(c)) { return 0;
                          } else if ( c < -0.25) { return -3;
						 } else if ( c < -0.05){ return -2;
								       } else if ( c < -0.001){ return -1;
											      } else if ( c <= 0.001){ return 0;
														     } else if ( c <= 0.05){ return 1;
																	   } else if ( c <= 0.25){ return 2;
																				 } else { return 3; }
        },
	fillColor       : d3.scale.ordinal().domain([-3,-2,-1,0,1,2,3]).range(["#d84b2a", "#ee9586","#e4b7b2","#AAA","#beccae", "#9caf84", "#7aa25c"]),
	strokeColor     : d3.scale.ordinal().domain([-3,-2,-1,0,1,2,3]).range(["#c72d0a", "#e67761","#d9a097","#999","#a7bb8f", "#7e965d", "#5a8731"]),
	getFillColor    : null,
	getStrokeColor  : null,
	pFormat         : d3.format("+.1%"),
	pctFormat       : function(){return false},
	tickChangeFormat: d3.format("+%"),
	simpleFormat    : d3.format(","),
	simpleDecimal   : d3.format(",.2f"),

	bigFormat       : function(n){return formatNumber(n*1000)},
	nameFormat      : function(n){return n},
	
	rScale          : d3.scale.pow().exponent(0.5).domain([0,100000000]).range([1,90]),
	radiusScale     : null,
	changeScale     : d3.scale.linear().domain([-0.28,0.28]).range([620,180]).clamp(true),
	sizeScale       : d3.scale.linear().domain([0,110]).range([0,1]),
	groupScale      : {},
	
	//data settings
	currentYearDataColumn   : 'budget_1',
	previousYearDataColumn  : 'budget_0',
	data                    : budget_array_data[fieldname],
	categoryPositionLookup  : {},
	categoriesList          : [],
	
	// 
	// 
	// 
	init: function() {
	    var that = this;
	    
	    this.pctFormat = function(p){
		if (p === Infinity ||p === -Infinity) {
		    return "N.A."
		} else {
		    return that.pFormat(p)
		}
		
	    }
	    
	    this.radiusScale = function(n){ return that.rScale(Math.abs(n)); };
	    this.getStrokeColor = function(d){
		return that.strokeColor(d.changeCategory);
	    };
	    this.getFillColor = function(d){
		if (d.isNegative) {
		    return "#fff"
		}
		return that.fillColor(d.changeCategory);
	    };
	    
	    this.boundingRadius = this.radiusScale(this.totalValue);
	    this.centerX = this.width / 2;
	    this.centerY = 300;
	    
	    //
	    this.groupScale = d3.scale.ordinal().domain(this.categoriesList).rangePoints([0,1]);
	    
	    // Builds the nodes data array from the original data
	    for (var i=0; i < this.data.length; i++) {
	    	var n = this.data[i];
	    	var out = {
	    	    sid: n['id'],
	    	    radius: this.radiusScale(n[this.currentYearDataColumn]),
	    	    group: n['department'],
	    	    change: n['change'],
	    	    changeCategory: this.categorizeChange(n['change']),
	    	    value: n[this.currentYearDataColumn],
	    	    name: n['name'],
	    	    discretion: n['discretion'],
	    	    isNegative: (n[this.currentYearDataColumn] < 0),
	    	    positions: n.positions,
	    	    x:Math.random() * 1000,
	    	    y:Math.random() * 1000
	    	}
	    	// if (n.positions.total) {
	    	//     out.x = n.positions.total.x + (n.positions.total.x - (that.width / 2)) * 0.5;
	    	//     out.y = n.positions.total.y + (n.positions.total.y - (150)) * 0.5;
	    	// };
	    	if ((n[this.currentYearDataColumn] > 0)!==(n[this.previousYearDataColumn] > 0)) {
	    	    out.change = "N.A.";
	    	    out.changeCategory = 0;
	    	};
	    	this.nodes.push(out)
	    };
	    
	    this.nodes.sort(function(a, b){  
	    	return Math.abs(b.value) - Math.abs(a.value);  
	    });
	    
	    for (var i=0; i < this.nodes.length; i++) {
	    	if(!this.nodes[i].isNegative ){
	    	    this.positiveNodes.push(this.nodes[i])
	    	}
	    };
	    
	    d3.select("#chartCanvas").html("");
	    this.svg = d3.select("#chartCanvas").append("svg:svg")
	    	.attr("width", this.width);
	    
	    // This is the every circle
	    this.circle = this.svg.selectAll("circle")
		.data(this.nodes, function(d) { return d.sid; });
            
	    this.circle.enter().append("svg:circle")
		.attr("r", function(d) { return 0; } )
		.style("fill", function(d) { return that.getFillColor(d); } )
		.style("stroke-width", 1)
		.attr('id',function(d){ return 'circle'+d.sid })
		.style("stroke", function(d){ return that.getStrokeColor(d); })
		.on("mouseover",function(d,i) { 
		    var el = d3.select(this)
		    var xpos = Number(el.attr('cx'))
		    var ypos = (el.attr('cy') - d.radius - 10)
		    el.style("stroke","#000").style("stroke-width",3);
		    d3.select("#tooltip").style('top',ypos+"px").style('left',(xpos)+"px").style('display','block')
			.classed('plus', (d.changeCategory > 0))
			.classed('minus', (d.changeCategory < 0));
		    d3.select("#tooltip .name").html(that.nameFormat(d.name))

		    //d3.select("#tooltip .discretion").text(that.discretionFormat(d.discretion))
		    d3.select("#tooltip .department").text(d.group)
		    d3.select("#tooltip .value").html(that.bigFormat(d.value)+" \u20aa")
		    
		    var pctchngout = that.pctFormat(d.change)
		    if (d.change == "N.A.") {
			pctchngout = "N.A."
		    };
		    d3.select("#tooltip .change").html(pctchngout) })
		.on("mouseout",function(d,i) { 
		    d3.select(this)
			.style("stroke-width",1)
			.style("stroke", function(d){ return that.getStrokeColor(d); })
		    d3.select("#tooltip").style('display','none')});
	    
            
	    this.circle.transition().duration(2000).attr("r", function(d){return d.radius})
	    
	},
	
	getCirclePositions: function(){
	    var that = this
	    var circlePositions = {};
	    this.circle.each(function(d){
		
		circlePositions[d.sid] = {
		    x:Math.round(d.x),
		    y:Math.round(d.y)
		}
		
		
	    });
	    return JSON.stringify(circlePositions)
	},
	
	// 
	start: function() {
	    var that = this;

	    this.force = d3.layout.force()
		.nodes(this.nodes)
		.size([this.width, this.height])
            
	    this.circle.call(this.force.drag)
	    
	},

	// 
	totalLayout: function() {
	    var that = this;
	    this.force
		.gravity(-0.01)
		.charge(that.defaultCharge)
		.friction(0.9)
		.on("tick", function(e){
		    that.circle
			.each(that.totalSort(e.alpha))
			    .each(that.buoyancy(e.alpha))
				.attr("cx", function(d) { return d.x; })
			.attr("cy", function(d) { return d.y; });
		})
		.start();
	},
	
	
	// 
	totalSort: function(alpha) {
	    var that = this;
	    return function(d){
		var targetY = that.centerY;
		var targetX = that.width / 2;
		
		
		if (d.isNegative) {
		    if (d.changeCategory > 0) {
			d.x = - 200
		    } else {
			d.x =  1100
		    }
		}
		
		// if (d.positions.total) {
		//   targetX = d.positions.total.x
		//   targetY = d.positions.total.y
		// };
		
		// 
		d.y = d.y + (targetY - d.y) * (that.defaultGravity + 0.02) * alpha
		d.x = d.x + (targetX - d.x) * (that.defaultGravity + 0.02) * alpha
		
	    };
	},

	// 
	buoyancy: function(alpha) {
	    var that = this;
	    return function(d){
		// d.y -= 1000 * alpha * alpha * alpha * d.changeCategory
		
		// if (d.changeCategory >= 0) {
		//   d.y -= 1000 * alpha * alpha * alpha
		// } else {
		//   d.y += 1000 * alpha * alpha * alpha
		// }
		
		
		var targetY = that.centerY - (d.changeCategory / 3) * that.boundingRadius
		d.y = d.y + (targetY - d.y) * (that.defaultGravity) * alpha * alpha * alpha * 500
		
		
		
	    };
	},
	
    }
};

updateChart = function(fieldname) {
    c = new Chart(fieldname);
    c.init();
    c.start();
    
    this.highlightedItems = [];
    
    c.totalLayout();
    this.currentOverlay = $("#totalOverlay");
    this.currentOverlay.delay(300).fadeIn(500);
    $("#chartFrame").css({'height':550});   
}

ready = function() {
    $(".button-selector").click( function() { 
	console.log($(this).attr("data-field"));
	$("#what").html($(this).html());
	updateChart($(this).attr("data-field")); 
    } );
    $(".button-selector:first").click();
}

if (!!document.createElementNS && !!document.createElementNS('http://www.w3.org/2000/svg', "svg").createSVGRect){
    $(document).ready($.proxy(ready, this));
} else {
    $("#chartFrame").hide();
}


