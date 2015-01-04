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
    parser.add_argument("--t_srs", help="Target spatial reference system")
    parser.add_argument(
        "--extents", nargs=4,
        help="Export extents in target SRS. One corner will be adjusted to " +
            "be a whole number of tiles from the other.")
    parser.add_argument(
        "--size", help="The width and height of the tiles, in pixels.",
        default=256)
    parser.add_argument("--nproc", help="Number of concurrent tasks to run.",
        default=1)

    args = parser.parse_args()

    export(args.style, args.output)


if __name__ == '__main__':
    run()

