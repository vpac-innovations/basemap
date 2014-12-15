#!/usr/bin/python

import argparse
import sys

import mapnik


def export(stylesheet, image):
    m = mapnik.Map(600, 300)
    mapnik.load_map(m, stylesheet)
    m.zoom_all()
    mapnik.render_to_file(m, image)

    print "rendered image to '%s'" % image


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
    parser.add_argument("style", help="Mapnik stylesheet")
    parser.add_argument("output", help="Output image")

    args = parser.parse_args()

    export(args.style, args.output)


if __name__ == '__main__':
    run()

