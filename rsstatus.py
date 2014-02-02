#!/usr/bin/python

# check mongodb replica sets
# alexis_g * feb 2014

# NOTE: as of feb 1, 2014, indentation here is incorrect and possibly syntax

import pymongo
from pymongo import MongoClient
import datetime
from optparse import OptionParser

parser = OptionParser()
parser.add_option("-s", "--srchost", dest="srchost",
 help="Source Mongo To Check", metavar="srchost")
(options, args) = parser.parse_args()

print options.srchost

uri = 'mongodb://'+options.srchost+'/admin'
client = MongoClient(uri)
db = client["admin"]

rstatus = db.command("replSetGetStatus")

 for rs in rstatus["members"]:
 try:
 rs["optimeDate"]
 except:
 continue
 else:
 print "%s %s" % ( rs["name"].split('.')[0], datetime.datetime.utcnow() - rs["optimeDate"] )
