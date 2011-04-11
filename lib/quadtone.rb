# system
require 'pp'
require 'yaml'

# gems
require 'color'
require 'gsl'
require 'pathname3'
require 'rvg/rvg'   # includes 'rmagick'
require 'builder'   # for SVG generation

$LOAD_PATH.unshift Pathname.new(ENV['HOME']) + 'src/cupsffi/lib'
require 'cupsffi'

# ours
require 'quadtone/cgats'
require 'quadtone/curve'
require 'quadtone/curve_set'
require 'quadtone/extensions/array'
require 'quadtone/extensions/color/grayscale'
require 'quadtone/extensions/color/lab'
require 'quadtone/extensions/color/lch'
require 'quadtone/extensions/color/qtr'
require 'quadtone/extensions/pathname3'
require 'quadtone/profile'
require 'quadtone/sample'
require 'quadtone/separator'
require 'quadtone/target'
require 'quadtone/tool'
require 'quadtone/tools/add_printer'
require 'quadtone/tools/chart'
require 'quadtone/tools/dump'
require 'quadtone/tools/init'
require 'quadtone/tools/print'
require 'quadtone/tools/profile'
require 'quadtone/tools/separate'
require 'quadtone/tools/test'