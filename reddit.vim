python << EOS

import vim
import webbrowser
import os
import re, htmlentitydefs, codecs

from urllib2 import urlopen
from BeautifulSoup import BeautifulSoup

####### START OF (html2text.py - Aaron Swartz) ########### 
####### (C) 2004-2008 Aaron Swartz. GNU GPL 3. #########

regex = re.compile("\[(\d+)\]*")

UNICODE_SNOB = 0

def name2cp(k):
    if k == 'apos': return ord("'")
    if hasattr(htmlentitydefs, "name2codepoint"): # requires Python 2.3
        return htmlentitydefs.name2codepoint[k]
    else:
        k = htmlentitydefs.entitydefs[k]
        if k.startswith("&#") and k.endswith(";"): return int(k[2:-1]) # not in latin-1
        return ord(codecs.latin_1_decode(k)[0])

unifiable = {'rsquo':"'", 'lsquo':"'", 'rdquo':'"', 'ldquo':'"', 
'copy':'(C)', 'mdash':'--', 'nbsp':' ', 'rarr':'->', 'larr':'<-', 'middot':'*',
'ndash':'-', 'oelig':'oe', 'aelig':'ae',
'agrave':'a', 'aacute':'a', 'acirc':'a', 'atilde':'a', 'auml':'a', 'aring':'a', 
'egrave':'e', 'eacute':'e', 'ecirc':'e', 'euml':'e', 
'igrave':'i', 'iacute':'i', 'icirc':'i', 'iuml':'i',
'ograve':'o', 'oacute':'o', 'ocirc':'o', 'otilde':'o', 'ouml':'o', 
'ugrave':'u', 'uacute':'u', 'ucirc':'u', 'uuml':'u'}

unifiable_n = {}

for k in unifiable.keys():
    unifiable_n[name2cp(k)] = unifiable[k]

def charref(name):
    if name[0] in ['x','X']:
        c = int(name[1:], 16)
    else:
        c = int(name)
    
    if not UNICODE_SNOB and c in unifiable_n.keys():
        return unifiable_n[c]
    else:
        return unichr(c)

def entityref(c):
    if not UNICODE_SNOB and c in unifiable.keys():
        return unifiable[c]
    else:
        try: name2cp(c)
        except KeyError: return "&" + c
        else: return unichr(name2cp(c))

def replaceEntities(s):
    s = s.group(1)
    if s[0] == "#": 
        return charref(s[1:])
    else: return entityref(s)

r_unescape = re.compile(r"&(#?[xX]?(?:[0-9a-fA-F]+|\w{1,8}));")

def unescape(s):
    return r_unescape.sub(replaceEntities, s)

####### END OF (html2text.py - Aaron Swartz) ########### 

# html processing end

def get_buffer(name):
	for b in vim.buffers:
		if name == b.name:
			vim.command("bd! " + name)
			return b
	vim.command("tabnew " + name)
	return vim.current.buffer

success = False

#Proggit links
database = {}

EOS


function! Proggit()
python << EOS

try:
    h = urlopen("http://www.reddit.com/r/programming/top")
    success = True
except IOError, e:
    vim.command("echomsg 'Error occurred while establishing connection to Reddit!'")

if success:
    soup = BeautifulSoup(h.read())

    titles = soup.findAll("p", attrs={"class" : "title"})
    ranks = soup.findAll("div", attrs={"class" : "score unvoted"})
    comments = soup.findAll("a", attrs={"class" : re.compile("comment*")})

    output = get_buffer("TopProggit")

    if titles and ranks and len(titles) == len(ranks) and len(titles) == len(comments):
        length = len(titles)
        for i in range(0, length):
            database[i] = {'url' : titles[i].a['href'], 'comments' : comments[i]['href']}
            output.append("[" + str(i+1) + "] " + unescape(titles[i].a.string).encode('utf-8') + " [[" + unescape(ranks[i].string).encode('utf-8') + "]]")
    else:
        vim.command("echomsg 'problem in titles and ranks size equality'")

EOS
endfunction

function! ProggitOpenLink() 
python << EOS

line = vim.current.line
if len(line) > 0:
    match = regex.search(line)
    if match:
        index = match.groups()[0]

        saveout = os.dup(1)
        os.close(1)
        os.open(os.devnull, os.O_RDWR)

        try:
            if 'open_new_tab' in dir(webbrowser):
                webbrowser.open_new_tab(database[int(index)-1]['url'])
            else:
                webbrowser.open_new(database[int(index)-1]['url'])
        finally:
            os.dup2(saveout, 1)
    else:
        vim.command("echomsg 'Invalid line'")
else:
     vim.command("echomsg 'Invalid line'")
  
EOS
endfunction

function! ProggitOpenComments() 
python << EOS

line = vim.current.line
if len(line) > 0:
    match = regex.search(line)
    if match:
        index = match.groups()[0]

        saveout = os.dup(1)
        os.close(1)
        os.open(os.devnull, os.O_RDWR)

        try:
            if 'open_new_tab' in dir(webbrowser):
                webbrowser.open_new_tab(database[int(index)-1]['comments'])
            else:
                webbrowser.open_new(database[int(index)-1]['comments'])
        finally:
            os.dup2(saveout, 1)

    else:
        vim.command("echomsg 'Invalid line'")
else:
     vim.command("echomsg 'Invalid line'")

EOS
endfunction


" Maps
noremap <silent> <F5>p :call Proggit()<CR>
noremap <silent> <F5>o :call ProggitOpenLink()<CR>
noremap <silent> <F5>c :call ProggitOpenComments()<CR>
