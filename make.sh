#!/bin/bash

/usr/local/share/npm/bin/iced -I inline -c vis.coffee

echo "stories_raw = " > stories.json
cat _stories.json >> stories.json
echo ";" >> stories.json
echo "explanations_raw = " > explanations.json
cat _explanations.json >> explanations.json
echo ";" >> explanations.json

/usr/local/share/npm/bin/uglifyjs data.js stories.json explanations.json vis.js -c > vis.min.js
/usr/local/share/npm/bin/lessc budget.less > budget.css

/usr/local/share/npm/bin/uglifyjs libs/jquery.min.js libs/ie-alert/iealert.js libs/d3.v3.min.js libs/underscore-min.js libs/backbone-min.js libs/native.history.min.js libs/bootstrap.js libs/select2.min.js vis.min.js > budget.min.js.tmp
cat copyright budget.min.js.tmp > budget.min.js

gzip budget.min.js -c > budget.min.js.gz
gzip budget.css -c > budget.css.gz

