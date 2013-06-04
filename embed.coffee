document.addEventListener( 'DOMContentLoaded', ->
        images = document.getElementsByTagName("img")
        console.log( images )
        to_convert = []
        for el in images
                console.log( el )
                src = el.getAttribute("src")
                console.log( src )
                match = src.match( /compare.open-budget.org.il\/images\/([a-z]+)\/([a-z-0-9]+)\.jpg/ )
                console.log( match )
                if match
                        chart_size = match[1]
                        chart_id = match[2]
                        
                        to_convert.push([el,chart_size,chart_id])
                        
        for tuple in to_convert
                el = tuple[0]
                chart_size = tuple[1]
                chart_id = tuple[2]
                console.log chart_id, chart_size, el
                width = null
                height = null
                if chart_size == "small"
                        width = 460
                        height = 800
                if chart_size == "medium"
                        width = 637
                        height = 725
                if chart_size == "large"
                        width = 959
                        height = 650
                if width and height
                        el.outerHTML = "<iframe src='//compare.open-budget.org.il/vis.html?#{chart_id}' width='#{width}' height='#{height}'>#{el.outerHTML}</iframe>"                       
)
