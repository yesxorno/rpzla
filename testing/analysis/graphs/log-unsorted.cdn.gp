set terminal png size 600,400 enhanced font "Vera,10"
set title 'Difference analysis: Unsorted'
set output "./png/log-diff-unsorted.cdn.png"
set datafile separator " "
set yrange [0:40]
set ylabel 'Number of events
set style fill solid 1.00 border lt -1.0
plot '../data/bucket/cdn.iciba.ccgslb.com.cn.txt.2.trial.unsorted.txt' using 1:2 with boxes lc rgb"green" title ''
