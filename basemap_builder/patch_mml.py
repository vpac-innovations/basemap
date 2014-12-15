#!/usr/bin/python

'''
Alters values in a CartoCSS .mml file.
'''

import argparse
import json
import sys
import os


def patch_postgis(mml, dbname=None, password=None, user=None, host=None):
    '''
    Add database connection information.
    '''
    for layer in mml['Layer']:
        ds = layer['Datasource']
        if ds.get('type') != 'postgis':
            continue

        if dbname is not None:
            ds['dbname'] = dbname
        if password is not None:
            ds['password'] = password
        if user is not None:
            ds['user'] = user
        if host is not None:
            ds['host'] = host


class HelpOnErrorArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        sys.stderr.write('error: %s\n' % message)
        self.print_help()
        sys.exit(2)


def run():
    # Process command line arguments
    parser = HelpOnErrorArgumentParser(
        description='Utility to adjust parameters of CartoCSS .mml files',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("input", help="CartoCSS input file")
    parser.add_argument("output", help="CartoCSS output file")
    parser.add_argument("-d", "--dbname", help="Database name")
    parser.add_argument("-U", "--username", help="DB user name")
    parser.add_argument("-H", "--host", help="Database host")
    parser.add_argument("-p", "--port", help="Database port")

    args = parser.parse_args()
    password = os.getenv('PGPASSWORD')

    with open(args.input, 'r') as infile:
        mml = json.load(infile)

    patch_postgis(mml, args.dbname, password, args.username, args.host)

    with open(args.output, 'w') as outfile:
        json.dump(mml, outfile, indent=2)


if __name__ == '__main__':
    run()

