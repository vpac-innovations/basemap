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


def patch_url(mml, replacement_files):
    for layer in mml['Layer']:
        ds = layer['Datasource']
        path = ds.get('file', '')
        if not path.startswith('http'):
            continue

        for remote, local in replacement_files:
            if remote in path:
                ds['file'] = os.path.abspath(local)
                break


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
    parser.add_argument("-f", "--replace-file", help="Files to patch URLs with",
        action="append", nargs=2)

    args = parser.parse_args()
    password = os.getenv('PGPASSWORD')

    with open(args.input, 'r') as infile:
        mml = json.load(infile)

    patch_postgis(mml, args.dbname, password, args.username, args.host)
    if args.replace_file is not None:
        patch_url(mml, args.replace_file)

    with open(args.output, 'w') as outfile:
        json.dump(mml, outfile, indent=2)


if __name__ == '__main__':
    run()

