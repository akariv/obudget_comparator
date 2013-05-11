import sys
import json

# {u'budget_2012': 66161000, u'budget_2013': 75650000, u'name': u'Benefits Programs', u'positions': {u'department': {u'y': 476, u'x': 225}, u'total': {u'y': 229, u'x': 308}}, u'discretion': u'Mandatory', u'department': u'Veterans Affairs', u'id': 302, u'change': 0.14342286241139}

allowed_changes = ["0016","0014","0011","0036","0019","0027","0067",
                   "0025","0053","0052","0068","0001","0040","0041",
                   "0030","0079","0076","0078","0038","0045"]


sums = {}
totals = [0,0]

if __name__=="__main__":
    
    years = [0,0]
    fields = [0,0]
    years[0], fields[0], years[1], fields[1] = sys.argv[1:]
    print "%s.%s vs. %s.%s" % (years[0],fields[0],years[1],fields[1])
    years = [ int(x) for x in years ]

    for j in file("master.json"):
        j = json.loads(j)
        code = j['code']
        if len(code)>4:continue
        for i in range(2):
            if j['year'] == years[i]:
                if len(code) == 2:
                    totals[i] = j[fields[i]]
                    continue
                sums.setdefault(code,{'id':int(code)})
                sums[code].setdefault('titles',['X','X'])
                if j.get(fields[i],0) == 0: continue
                sums[code]['budget_%s' % i] = j[fields[i]]
                sums[code]['titles'][i] = j['title']
# ratio = 1.0*totals[0]/totals[1] (for comparing the relative part in the budget)
ratio = 1.0
print ratio
out = []
for code,budgets in sums.iteritems():
    if budgets['titles'][0] != budgets['titles'][1]:
        if not code in allowed_changes:
            for title in budgets['titles']:
                print "!!! ",code,title
            continue
    if not (('budget_0' in budgets) and ('budget_1' in budgets)):
        for title in budgets['titles']:
            print "### ",code,title
        print "###", budgets
        continue
    budgets['name']=budgets['department']=budgets['titles'][1]
    del budgets['titles']
    budgets['change'] = ratio*budgets['budget_1']/budgets['budget_0'] - 1
    out.append(budgets)

file('data.js','w').write('budget_array_data = %s;\n' % json.dumps(out))

            

