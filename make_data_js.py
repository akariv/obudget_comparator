import sys
import json
import Levenshtein

# {u'budget_2012': 66161000, u'budget_2013': 75650000, u'name': u'Benefits Programs', u'positions': {u'department': {u'y': 476, u'x': 225}, u'total': {u'y': 229, u'x': 308}}, u'discretion': u'Mandatory', u'department': u'Veterans Affairs', u'id': 302, u'change': 0.14342286241139}

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
 2013: 1.0,
 2014: 1.0,
}

generated_diffs = [ "2011.net_allocated/2011.net_used",
                    "2012.net_allocated/2012.net_used",
                    "2012.net_allocated/2012.net_used/income",
                    "2011.net_allocated/2012.net_allocated",
                    "2011.net_used/2012.net_used",
                    "2012.net_allocated/2013.net_allocated",
                    "2012.net_allocated/2014.net_allocated",
                    "2013.net_allocated/2014.net_allocated" ]
                    

allowed_changes = ["0016","0014","0011","0036","0019","0027","0067",
                   "0025","0053","0052","0068","0001","0040","0041",
                   "0030","0079","0076","0078","0038","0045"]

dive_in = ["0084", "0045", "0020", "0012", "0007", "0079", "9001", "9014", "9083" ]

skip = ["0094", "0089", "0095", "0098"]

allout = {}
for diff in generated_diffs:

    maincodes = {}
    subsums = {}
    totals = [0,0]
    relative = False
    
    parts = diff.split('/')
    years = [ int(p.split('.')[0]) for p in parts[:2] ]
    fields = [ p.split('.')[1] for p in parts[:2] ]
    incomes = parts[2:3] == ['income']

    print "%s.%s vs. %s.%s" % (years[0],fields[0],years[1],fields[1])

    for j in file("master.json"):
        j = json.loads(j)
        code = j['code']
        if code[:4] in skip: continue
        if not incomes and code.startswith("0000"): continue
        if incomes and not code.startswith("0000"): continue
        if incomes:
            code = code[2:]
            code = "9" + code[1:]
        maincode = code[:4]
        for i in range(2):
            if j['year'] == years[i]:
                if j.get(fields[i],-1) < 0: continue
                if j.get('title','') == '': continue
                if len(code) == 2:
                    totals[i] = j[fields[i]]*INFLATION[years[i]]
                    continue
                elif (len(code) == 4 or
                      (len(code) == 6 and maincode in dive_in)):
                    subsums.setdefault(maincode,{})
                    if code in dive_in:
                        sc = maincodes.get(code)
                    else:
                        sc = subsums[maincode].get(code)
                    if sc == None:
                        sc = {'id':int(code)}
                    sc.setdefault('titles',[u'X',u'X'])
                    sc['budget_%s' % i] = j[fields[i]]*INFLATION[years[i]]
                    sc['titles'][i] = j['title']
                    if code == maincode:
                        maincodes[code] = sc
                    if code not in dive_in:
                        subsums[maincode][code] = sc

    out = []
    for maincode,maincode_budgets in subsums.iteritems():
        maincode_budgets = dict([(k,v) for k,v in maincode_budgets.iteritems() if 'X' not in v['titles']])
        if maincode_budgets:
            toiter = maincode_budgets.iteritems()  
        elif maincode in maincodes:
            toiter = [(maincode,maincodes[maincode])]
        else:
            toiter = []
        for code,budgets in toiter:
            if budgets['titles'][0] != budgets['titles'][1]:
                lratio = Levenshtein.ratio(budgets['titles'][0], budgets['titles'][1])
                print lratio
                if code not in allowed_changes and lratio < 0.5:
                    for title in budgets['titles']:
                        print "!!! ",code,title
                    continue
            if not (('budget_0' in budgets) and ('budget_1' in budgets)):
                for title in budgets['titles']:
                    print "###",code,title,
                print "###", budgets
                continue
            budgets['name']=budgets['titles'][1] + (" (%s)" % code)
            budgets['department']=maincodes[maincode]['titles'][1] + (" %s" % maincode if maincode!=code else "")
            del budgets['titles']
            if relative:
                budgets['change'] = budgets['budget_1']/totals[1] - budgets['budget_0']/totals[0]
            else:
		print code, budgets['budget_1'],'/',budgets['budget_0'], budgets['budget_0'] > 0,
		if budgets['budget_0'] > 0:
	                budgets['change'] = budgets['budget_1']/budgets['budget_0'] - 1
		else:
	                budgets['change'] = 1.0
		print budgets['change']
            out.append(budgets)
    allout[diff] = out
file('data.js','w').write('budget_array_data = %s;\n' % json.dumps(allout))

            

