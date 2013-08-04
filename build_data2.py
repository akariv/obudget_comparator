#!/usr/bin/python
#encoding: utf8

import json
import itertools
import Levenshtein
import re
import pprint
import csv

INFLATION = {1992: 2.338071159424868,
 1993: 2.1016785142253185,
 1994: 1.8362890269054741,
 1995: 1.698638328862775,
 1996: 1.5360153664058611,
 1997: 1.4356877762122495,
 1998: 1.3217305991625745,
 1999: 1.3042057718241757,
 2000: 1.3042057718241757,
 2001: 1.2860800081392196,
 2002: 1.2076314957018655,
 2003: 1.2308469660644752,
 2004: 1.2161648953888384,
 2005: 1.1878270593983091,
 2006: 1.1889814138002117,
 2007: 1.1499242230869946,
 2008: 1.1077747422214268,
 2009: 1.0660427753379829,
 2010: 1.0384046275616676,
 2011: 1.0163461588107117,
 2012: 1.0,
 2013: 1.0/1.017,
 2014: 1.0/(1.017*1.023),
}

strings = []
strings_rev = {}
no_ws = re.compile('[ ]+')

def get_string_id(s):
    s=s.strip()
    s=no_ws.sub(' ',s)
    if s in strings_rev.keys():
        return strings_rev[s]
    ret = len(strings)
    strings_rev[s] = ret
    strings.append(s)
    return ret

def budget_file():
    for line in file('master.json'):
        if line.strip():
            data = json.loads(line)
            z = dict([ (k,v) for k,v in data.iteritems() if v is not None ])
            yield z

def copy_node_no_children(node):
    return { 'code': node['code'],
             'title': node['title'],
             'value': node['value'],
             'group': node.get('group',""),
             'parent_value': node.get('parent_value'),
             'nchildren': len(node.get('children')) if 'children' in node.keys() else node.get('nchildren', 0),
             'children': {} }

def filter_tree(node,func):
    orig_node = copy_node_no_children(node)
    new_node = copy_node_no_children(node)
    for step, child in node.get('children',{}).iteritems():
        new_child = filter_tree(child,func)
        if new_child:
            new_node['children'][step] = new_child 
    if not func(new_node): 
        return orig_node
    return new_node

def merge_trees(root1, root2):
    new_node = copy_node_no_children(root1)
    new_node['value'] = [ new_node['value'] ]
    new_node['value'].append(root2['value'])
    new_node['parent_value'] = root2.get('parent_value')

    roots = [ root1, root2 ]
    codesets = [ set(root['children'].keys()) for root in roots ]
    shared_codes = codesets[0].intersection(codesets[1])
    other_codes = [ codeset - shared_codes for codeset in codesets ]
    group = ""
    parent_value = None
    report = { 'only':[[],[]] }
    for code in shared_codes:
        child_nodes = [ root['children'][code] for root in roots ]
        titles = [ node['title'] for node in child_nodes ]
        lratio = Levenshtein.ratio(*titles)
        if lratio < 0.5:
            for codes in other_codes: codes.add(code)
            continue
        new_node['children'][code], _report = merge_trees(*child_nodes)
        group = child_nodes[1]['group']
        parent_value = child_nodes[1].get('parent_value')
        for i in range(2):
            report['only'][i].extend(_report['only'][i])

    for i in range(2):
        report['only'][i].extend(root1['code']+x for x in other_codes[i])
    
    if sum([len(x) for x in other_codes]) > 0:
        others_node = { 'code' : root1['code']+'**',
                        'title' : u'סעיפים שונים',
                        'value' : [0,0] }
        for i in range(2):
            for code in other_codes[i]:
                others_node['value'][i] += roots[i]['children'][code]['value']
    
        new_node['children']['**'] = others_node

    return new_node, report

def build_tree( data, year, field, income=False ):
    def item_filter(item):
        return (int(item.get('year',0))==year and 
                int(item.get(field,-1))>=0 and 
                income == item.get('code','').startswith('0000') and
                item.get('title','') != '')
    filtered_items = ( item for item in data if item_filter(item) )
    filtered_items = ( { 'code':item['code'][4 if income else 2:], 
                         'title':item['title'], 
                         'value':int(item[field]) } 
                       for item in filtered_items )
    filtered_items = [ item for item in filtered_items if len(item['code'])<=6 ]
    filtered_items.sort( key=lambda item: item['code'] )

    if len(filtered_items) == 0: return {}
    root = filtered_items[0]
    root['title'] = u"תקציב המדינה" if not income else u"הכנסות המדינה"
    assert(root['code']== "")

    for item in filtered_items[1:]:
        node = root
        code = item['code']
        group = None
        parent_value = node['value']
        try:
            while len(code)>2:
                step = code[:2]
                node = node['children'][step]
                code = code[2:]
                group = "%s (%s)" % (node['title'], node['code'])
                parent_value = node['value']
        except KeyError:
            continue
        item['group'] = group if group else "תקציב המדינה"
        item['parent_value'] = parent_value
        node.setdefault('children',{})[code] = item

    root = filter_tree(root, lambda node: len(node.get('children',{}))>1 )

    return root

def extract_by_depth(node,target_depth,depth=0):
    if depth > 0:
        ret = copy_node_no_children(node)
        ret['depth'] = depth
        yield ret
    if depth==target_depth: 
        return
    if len(node.get('children',{})) == 0: 
        #yield copy_node_no_children(node)
        return
    keys = node.get('children').keys()
    keys.sort()
    for key in keys:
        child = node.get('children')[key]
        for x in extract_by_depth(child,target_depth,depth+1): yield x

def traverse_by_depth(node,max_depth,depth=0,breadcrumbs=[]):
    yield node, breadcrumbs + [node['title']]
    if depth == max_depth: return
    keys = node.get('children').keys()
    keys.sort()
    for key in keys:
        child = node.get('children')[key]
        for x in traverse_by_depth(child,max_depth,depth+1,breadcrumbs + [node['title']]): yield x
    

def key_for_diff(year1,field1,year2,field2,income,divein):
    def year(y):  return ' pkxw'[y%10]
    def field(f): return f.split('_')[1][1]
    key = "%s%s%s%s%s%s" % ( year(year1), field(field1), year(year2), field(field2), "v" if income else "q", get_string_id(divein) )
    return key

def adapt_for_js(drilldown, items, inflation):
    for item in items:
        if item['value'] != [0,0]:
            ret= { 'b0'  : item['value'][0],
                    'b1'  : item['value'][1],
                    'n'   : get_string_id(item['title']),
                    'p'   : get_string_id(item['group']),
                    'pv'  : item.get('parent_value'),
                    'id'  : get_string_id(item['code']),
                    'c'   : int(100*inflation*item['value'][1] / item['value'][0] - 100) if item['value'][0] > 0 else 99999,
                }
            if item.get('nchildren',0) > 0:
                ret['d'] = drilldown(item['code'])
            yield ret


def describe(year,field):
    title = u"תכנון" if field.endswith("allocated") else u"ביצוע"
    title += " %d" % year
    return title

def get_titles(items, year, income):
    return dict((x['code'][4 if income else 2:],x['title']) for x in items if x['year']==year)

def get_items_for(year1,field1,year2,field2,income):
    tree1 = build_tree(budget_file(), year1, field1, income)
    tree2 = build_tree(budget_file(), year2, field2, income)
    titles = [ get_titles(budget_file(), year1, income), get_titles(budget_file(), year2, income) ]
    merged, report = merge_trees(tree1, tree2) 

    inflation = INFLATION[year2] / INFLATION[year1]

    merged = filter_tree(merged, lambda node: node['value'][0] > 0)
    merged = filter_tree(merged, lambda node: sum([ (node['value'][i] > 0) and
                                                    1.0 * node.get('children',{}).get('**',{'value':[0,0]})['value'][i] / node['value'][i] < 0.5 
                                                    for i in range(2)]
                                              ) == 2)
    merged = filter_tree(merged, lambda node: len(node.get('children',{}))>1 )

    title_prefix = u"%s: %s לעומת %s" % ( u"הכנסות" if income else u"הוצאות", describe(year1,field1), describe(year2,field2) )

    only = []
    for i,r in enumerate(report['only']):
        processed = []
        for code in r:
            processed.append(("%s: %s" % ( code, titles[i][code] )).encode('utf8'))
        processed.sort()
        only.append(processed)
    reportfile = file("reports/"+title_prefix+".html","w")
    reportfile.write("<body style='direction:rtl'><table><tr><th>%s</th><th>%s</th></tr>" % (year1, year2))
    reportfile.write("<tr>%s</tr>" % "".join(["<td>%s</td>" % "".join(["<p>%s</p>" % x for x in r]) for r in only]) )
    reportfile.write("</table></body>")

    for node,breadcrumbs in traverse_by_depth(merged,2):
        diff = list(adapt_for_js(lambda (c): key_for_diff(year1,field1,year2,field2,income,c),extract_by_depth(node,1),inflation))
        if len(diff) > 1:
            up = None
            title = u"%s - %s" % (title_prefix, node['title'],  )
            if len(node['code']) > 0:
                up = key_for_diff(year1,field1,year2,field2,income,node['code'][:-2])
                title += " (%s)" % node['code']
            yield key_for_diff(year1,field1,year2,field2,income,node['code']), up, diff, node['code'], title, ' | '.join(breadcrumbs)

#    for part in merged['children'].keys():
#        key = key_for_diff(year1,field1,year2,field2,income,merged['code']+part)
#        diff = list(adapt_for_js(extract_by_depth(merged['children'][part],2)))
#        if len(diff) > 1:
#            yield key, diff

def writeProxyHtml( key, title, description="" ):
    html = u"""<!DOCTYPE html>
<html lang="he">
<head>
<meta charset="utf-8">
<title>תקציב המדינה 2014 מול 2012 - %(title)s</title>
<meta property="og:title" content="%(title)s" />
<meta property="og:type" content="cause" />
    <meta property="og:description" content="הסדנא לידע ציבורי וכלכליסט מציגים: כך הממשלה מתכוונת להוציא מעל 400 מיליארד שקלים. העבירו את העכבר מעל לעיגולים וגלו כמה כסף מקדישה הממשלה לכל מטרה. לחצו על עיגול בשביל לצלול לעומק התקציב ולחשוף את הפינות החבויות שלו" />
<meta property="og:image" content="http://compare.open-budget.org.il/images/large/%(key)s.jpg" />
<meta property="og:image:width" content="959" />
<meta property="og:image:height" content="800" />
<meta property="og:site_name" content="התקציב הפתוח" />
<meta property="fb:admins" content="100000025217694" />
<script type="text/javascript">
document.addEventListener('DOMContentLoaded', function() {
    window.setTimeout( function () { window.location = "http://compare.open-budget.org.il/?%(key)s"; }, 1000 );
});
</script>
</head>
<body>
</body>
</html>""" % { 'key': key, 'title' : title, 'description': description }
    file("of/%s.html" % key,"w").write(html.encode('utf8'))

if __name__=="__main__" and False:
    generated_diffs = [ #(2011, "net_allocated", 2011, "net_used", False),
                        (2012, "net_allocated", 2012, "net_used", False),
                        #(2011, "net_allocated", 2011, "net_used", True),
                        (2012, "net_allocated", 2012, "net_used", True),
                        #(2011, "net_used",      2012, "net_used", False),
                        #(2011, "net_used",      2012, "net_used", True),
                        #(2011, "net_allocated", 2012, "net_allocated", False),
                        (2012, "net_allocated", 2013, "net_allocated", False),
                        (2012, "net_allocated", 2014, "net_allocated", False),
                        (2013, "net_allocated", 2014, "net_allocated", False), 
                        # (2011, "net_allocated", 2012, "net_allocated", True),
                        (2012, "net_allocated", 2013, "net_allocated", True),
                        (2012, "net_allocated", 2014, "net_allocated", True),
                        (2013, "net_allocated", 2014, "net_allocated", True), 
                        ]
    diffs = itertools.chain( *( get_items_for(*diff) for diff in generated_diffs ) )
    diffsDict = {}
    urls = []
    for key,up,diff,code,title,breadcrumbs in diffs:
        diffsDict[key] = { 't': title, 'd' : diff, 'u' : up, 'b' : breadcrumbs, 'c' : code }
        urls.append((key,title))
    out = file('data.js','w')
    out.write('budget_array_data = %s;\n' % json.dumps(diffsDict))
    out.write('strings = %s;\n' % json.dumps(strings))
    urlsFile = file('all.html','w')
    urlsFile.write("<!DOCTYPE html><html><head><meta charset='utf-8'><title>כל ההשוואות</title></head><body><ul style='direction:rtl;'>")
    for x in urls: urlsFile.write(("<li><a href='vis.html?%s'>%s</a></li>" % x).encode('utf8'))
    urlsFile.write("</ul></body></html>")
    
    imagesScript = file('load_images.sh','w')
    imagesScript.write("#!/bin/bash\n")
    commands = []
    for key, title in urls:
        commands.append( "phantomjs images/rasterize.js http://localhost:8000/vis.html?%(url)s s images/small/%(url)s.jpg" % { 'url' : key } )
        commands.append( "phantomjs images/rasterize.js http://localhost:8000/vis.html?%(url)s m images/medium/%(url)s.jpg" % { 'url' : key } )
        commands.append( "phantomjs images/rasterize.js http://localhost:8000/vis.html?%(url)s l images/large/%(url)s.jpg" % { 'url' : key } )

        writeProxyHtml( key, title ) 

    while len(commands) > 0:
        towrite = commands[:8]
        commands = commands[8:]
        imagesScript.write( "".join([ "sleep 3 ; for x in `pgrep phantomjs | sed '1,8d' | head -n1` ; do wait $x ; done ; %s &\n" % (cmd,) for i, cmd in enumerate(towrite)]) )
                            


def tree_from_items(items):
    tree = items[0]
    tree['bc'] = [ u"תקציב המדינה" ]
    for item in items[1:]:
        code = item['code']
        node = tree
        bc = []
        for i in range(4,len(code),2):
            try:
                node = [ x for x in node['children'].values() if x['code'] == code[:i] ][0]
            except:
                print "ERROR: failed to dive in for item %s" % code
                continue
            bc.append(node['title'])
        node.setdefault('children',{})[code] = item
        bc.append(item['title'])
        item['bc'] = bc
        
    return tree

def join_items(items,tojoin):
    for fromcode,tocode in tojoin.iteritems():
        try:
            toitem = [ x for x in items if x['code'] == tocode][0]
            fromitem_parent = [ x for x in items if x['code'] == fromcode[:-2]][0]
            fromitem = fromitem_parent['children'][fromcode]
        except IndexError:
            print "FAIL: Failed to find join candidates for %s-->%s" % (fromcode, tocode)
            continue
        del fromitem_parent['children'][fromcode]
        toitem.setdefault('joincode',toitem['code'])
        toitem['joincode'] += " + "+fromcode
        toitem['net_allocated']+=fromitem['net_allocated']
        toitem['children'].update(fromitem['children'])
        del fromitem['children']

def get_groups(items):
    return [ (x['code'],x['title'],x['code'][:-2] if x['code'] != '0000' else None," / ".join(x['bc']),x['children'].values()) for x in items if 'children' in x ]

performance_aid = dict([("%s/%s" % (x['year'],x['code']),x) for x in budget_file()])

def past_performance(items):
    performance = []
    for year in range(2009,2013):
        used = 0
        allocated = 0
        num = 0
        for item in items:
            key = "%s/%s" % (year,item['code'])
            past = performance_aid.get(key)
            if not past: continue
            _used = past.get('net_used')
            _allocated = past.get('net_allocated')
            if _allocated is None or _used is None or _allocated <= 0 or _used < 0: continue
            used += _used
            allocated += _allocated
            num += 1
        if num > 0:
            performance.append(int((100.0 * used) / allocated - 100))
    if len(performance) > 0:
        return sum(performance) / len(performance)
    else:
        print "WARN: past performance for %r is undefined" % [x['code'] for x in items]
        return None

def get_translations():
    trasnslations_source = [ ("translations.csv", 6, 10), ("translations2.csv", 5, 8) ]
    translations = []
    digitsre = re.compile("[0-9]+")
    already_in = []
    for src in trasnslations_source:
        translations_csv = csv.reader(file(src[0]))
        all_froms = set()
        for row in translations_csv:
            try:
                fromcodes = [x.strip() for x in row[src[2]].replace('"','').split(',') if x.strip() != '' ]
                fromcodes = [ x for x in fromcodes if digitsre.match(x) != None ]
                for x in fromcodes:
                    if x in all_froms:
                        print "ERROR: %s already in translation" % x
                        already_in.append(x)
                    all_froms.add(x)
                tocode = row[src[1]].replace('"','').strip()
                if tocode != '' and len(fromcodes)>0:
                    translations.append((tocode,fromcodes))
            except:
                pass
    translations = dict(translations)
    print "ERROR\n%s" % '\n'.join(already_in)
    return translations

translations = get_translations()

def get_prev_candidates(code,items):
    candidates = []
    translation = translations.get(code,[code])
    for code in translation:
        candidates.extend([x for x in items if x['code'] == code])
    return candidates

def get_prefixes(codes):
    to_remove = []
    for code in codes:
        to_remove.extend(x for x in codes if x!=code and x.startswith(code))
    return codes - set(to_remove)

def flattened_tree_for_code(code,items):
    item = [ x for x in items if x['code'] == code ][0]
    def _traverse(node):
        yield node
        if 'children' in node:
            for x in node['children'].values():
                for y in _traverse(x):
                    yield y
    for x in _traverse(item):
        yield x

def get_prev_value(code,candidates,field):
    prev_value = sum([x[field] for x in candidates])
    return prev_value

if __name__=="__main__":

    toremove_prefixes = [ "0089", "0095", "0098", "0000", "0094" ]
    items2014 = [ x for x in budget_file() if x['year'] == 2014 and x['code'][:4] not in toremove_prefixes and len(x['code'])<=8 ]
    items2012 = [ x for x in budget_file() if x['year'] == 2012 and x['code'][:4] not in toremove_prefixes and len(x['code'])<=8 ]
    inc_items2014 = [ x for x in budget_file() if x['year'] == 2014 and x['code'][:4] == "0000" and len(x['code'])<=10 ]
    inc_items2012 = [ x for x in budget_file() if x['year'] == 2012 and x['code'][:4] == "0000" and len(x['code'])<=10 ]

    items2012.extend(inc_items2012)

    tree2014 = tree_from_items(items2014)
    tree2012 = tree_from_items(items2012)
    inc_tree2014 = tree_from_items(inc_items2014)

    renames = { "0025" : u"הרשות לזכויות ניצולי השואה",
                "00" : u"תקציב המדינה" }

    #                -->
    tojoin = { "0067" : "0024",
               "0060" : "0020",
               "0079" : "0040",
               "0052" : "0007",
               "0053" : "0008",
               "0078" : "0037",
               "0070" : "0029",
               "0073" : "0041",
               "0076" : "0036", 
               "004053" : "007952",
    }

    join_items(items2014,tojoin)
    join_items(items2012,tojoin)

    groups = get_groups(items2014)
    groups.extend( get_groups(inc_items2014) )

    links = csv.reader(file('links.csv'))
    links = [ ("%04d" % (int(x[0])), x[2]) for x in links ]
    links = dict(links)

    ignoreitems = []
    for x in translations.values():
        ignoreitems.extend(x)

    urls=[]
    out_groups = []
    for c,t,u,bc,group in groups:
        field2012 = "net_allocated" if not c.startswith("0000") else "net_used"
        out_group = []
        for item in group:
            candidates = get_prev_candidates(item['code'],items2012)
            prev_value = get_prev_value(item['code'],candidates,field2012)
            if prev_value <= 0 and item['net_allocated'] <= 0: continue
            if item['code'] in ignoreitems and item['net_allocated'] <= 0: continue
            change = (100*item['net_allocated'])/prev_value - 100 if prev_value > 0 else 99999
            out_group.append( { 'id':item['code'],
                                'jc':item.get('joincode',item['code']),
                                'n':renames.get(item['code'],item['title']),
                                'b1':item['net_allocated'],
                                'b0':prev_value,
                                'bc': [(x.get('joincode',x['code']),x['title']) for x in candidates],
                                'pp':past_performance(candidates),
                                'c':change, } )
            if 'children' in item:
                out_group[-1]['d'] = out_group[-1]['id']
            urls.append((c+';'+item['code'],t))
        if len(out_group)>0:
            out_groups.append((c,{'c':c,'t':renames.get(c,t),'d':out_group,'u':u,'l':links.get(c[:4])}))#'b':bc}))
        else:
            print "WARN: group %s is empty!" % c
        urls.append((c,t))

    actual_fields = {}
    expected_fields = {}
    all_candidates = {}
    sumerr = file("sumerr.csv","w")
    sumerr = csv.writer(sumerr)
    for c,t,u,bc,group in groups:
        field2012 = "net_allocated" if not c.startswith("0000") else "net_used"
        all_candidates[c] = [x['code'] for x in get_prev_candidates(c,items2012) if x[field2012] > 0]
        actual_fields[c] = []
        expected_fields[c] = []
        for x in all_candidates[c]:
            descendants = [ i['code'] for i in flattened_tree_for_code(x,items2012) if i[field2012] > 0 ]
            expected_fields[c].extend(descendants)
        for item in group:
            candidates = [ x['code'] for x in get_prev_candidates(item['code'],items2012) if x[field2012] > 0 ]
            print ">>> %s > %s => %r" % (c,item['code'], candidates)
            for x in candidates:
                descendants = [ i['code'] for i in flattened_tree_for_code(x,items2012) if i[field2012] > 0 ]
                print "\t\t %s => %r" % (x,descendants)
                actual_fields[c].extend(descendants)
    for c,t,u,bc,group in groups:
        extra = set(actual_fields[c]) - set(expected_fields[c])
        extra = get_prefixes(extra)
        missing = set(expected_fields[c]) - set(actual_fields[c]) - set(all_candidates[c])
        missing = get_prefixes(missing)
        if len(extra) > 0 or len(missing) > 0:
            row = ['"%s"' % c,'"%s"' % ",".join(missing), '"%s"' % ",".join(extra)]
            sumerr.writerow(row)
            print "CODE: %s" % c
            #print "actual: %r, expected: %r, candidates: %r" % (actual_fields[c],expected_fields[c], all_candidates[c])
            if len(missing) > 0:
                print "\tMISSING: %r" % missing
            if len(extra) > 0:
                print "\tEXTRA: %r" % extra

        # field2012 = "net_allocated" if not c.startswith("0000") else "net_used"
        # for item in group:
        #     if 'children' in item:
        #         candidates = get_prev_candidates(item['code'],items2012)
        #         if group_sums[item['code']] != get_prev_value(item['code'],candidates,field2012):
        #             print "ERROR: subitems for %s don't sum up (%d != %d)" % (item['code'], item['net_allocated'], group_sums[item['code']])
        #             to_write = ['"%s"' % item['code'],
        #                              item['title'].encode('utf8'),
        #                              ",".join([x['code'] for x in candidates]), 
        #                              get_prev_value(item['code'],candidates,field2012), 
        #                              group_sums[item['code']]]
        #             sumerr.writerow(to_write)

    diffs = dict(out_groups)

    out = file('data.js','w')
    out.write('budget_array_data = %s;\n' % json.dumps(diffs))
   

    imagesScript = file('load_images.sh','w')
    imagesScript.write("#!/bin/bash\n")
    commands = []
    for i,x in enumerate(urls):
        key = x[0]
        title = x[1]
        fn = 'images/large/%(url)s.jpg' % { 'url' : key }
        cmd = "phantomjs images/rasterize.js 'http://localhost:8000/vis.html?%(url)s' m 'images/large/%(url)s.jpg'" % { 'url' : key }
        imagesScript.write("if [ ! -f '%(fn)s.synced' ]; then %(cmd)s ; fi \n" % {'cmd': cmd,'fn':fn, 'wait': 4*i} )
        writeProxyHtml( key, title ) 

