all: advent-min.js advent_dat.js

dat: advent_dat.js

advent_dat.js: read_advent_dat.pl advent.dat
	./read_advent_dat.pl > advent_dat.js

advent-min.js: advent.js advent_dat.js advent_cc.js
	java -jar closure-compiler/compiler.jar --js advent.js --js advent_dat.js --js advent_cc.js --js_output_file advent-min.js --compilation_level ADVANCED_OPTIMIZATIONS

clean:
	rm -f advent_dat.js advent-min.js

.PHONY: all dat clean
