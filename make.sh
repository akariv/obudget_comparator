#!/bin/bash

/usr/local/share/npm/bin/iced -I inline -c vis.coffee
/usr/local/share/npm/bin/uglifyjs data.js vis.js -c > vis.min.js
/usr/local/share/npm/bin/lessc budget.less > budget.css

/usr/local/share/npm/bin/uglifyjs libs/jquery.min.js libs/d3.v3.min.js libs/underscore-min.js libs/backbone-min.js libs/native.history.min.js libs/bootstrap.js libs/select2.min.js vis.min.js > budget.min.js

gzip budget.min.js -c > budget.min.js.gz
gzip budget.css -c > budget.css.gz

