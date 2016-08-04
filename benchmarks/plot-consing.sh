#!/bin/bash

source=consing.dat

gnuplot <<EOF
set terminal pngcairo \
size 1200,480 font 'Source Sans Pro,16.8' lw 1.8 crop
set output 'consing.png'
set key outside
set xlabel "=sexp | bench-=destructure | bench-=destructure/bare"
set xtics ("master" 1.75, "special-case" 6.25, "consfree-input" 10.75, "consfree-input+special-case" 15.25)
set xtics nomirror
set grid
set grid noxtics
set style fill solid
set boxwidth 0.5

plot "$source" every 2    using 1:2 with boxes ls 3 title "Execution time",\
     "$source" every 2::1 using 1:2 with boxes ls 4 title "GC time (%)"
EOF
