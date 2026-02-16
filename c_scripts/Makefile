CC      = gcc
CFLAGS  = -O3 -march=native -Wall
CAIRO   = $(shell pkg-config --cflags --libs cairo)
LIBS    = -lm

all: collatz_tree collatz_scatter parity_sft profinite_compat branch_locus

collatz_tree: collatz_tree.c
	$(CC) $(CFLAGS) -o $@ $< $(CAIRO) $(LIBS)

collatz_scatter: collatz_scatter.c
	$(CC) $(CFLAGS) -o $@ $< $(CAIRO) $(LIBS)

parity_sft: parity_sft.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

profinite_compat: profinite_compat.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

branch_locus: branch_locus.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

run-sft: parity_sft
	./parity_sft 1000000

run-profinite: profinite_compat
	./profinite_compat 10000000

run-tree: collatz_tree
	./collatz_tree 5000 1000000 42

run-scatter: collatz_scatter
	./collatz_scatter 100000000 1

run-branch: branch_locus
	./branch_locus 10000000

run-branch-10B: branch_locus
	./branch_locus 10000000000

clean:
	rm -f collatz_tree collatz_scatter parity_sft profinite_compat branch_locus *.png *.csv

.PHONY: all clean run-tree run-scatter run-sft run-profinite run-branch run-branch-10B
