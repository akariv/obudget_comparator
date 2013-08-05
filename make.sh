#!/bin/bash

/usr/local/share/npm/bin/iced -o out/ -I inline -c vis.coffee 

echo "stories_raw = " > out/stories.json
cat out/_stories.json >> out/stories.json
echo ";" >> out/stories.json
echo "explanations_raw = " > out/explanations.json
cat out/_explanations.json >> out/explanations.json
echo ";" >> out/explanations.json

/usr/local/share/npm/bin/uglifyjs out/data.js out/stories.json out/explanations.json out/vis.js -c > out/vis.min.js
/usr/local/share/npm/bin/lessc budget.less > out/budget.css

/usr/local/share/npm/bin/uglifyjs libs/jquery.min.js libs/ie-alert/iealert.js libs/d3.v3.min.js libs/underscore-min.js libs/backbone-min.js libs/native.history.min.js libs/bootstrap.js libs/select2.min.js out/vis.min.js > out/budget.min.js.tmp
cat copyright out/budget.min.js.tmp > out/budget.min.js

gzip out/budget.min.js -c > out/budget.min.js.gz
gzip out/budget.css -c > out/budget.css.gz

