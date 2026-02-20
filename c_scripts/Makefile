CC      = gcc
CFLAGS  = -O3 -march=native -Wall
CAIRO   = $(shell pkg-config --cflags --libs cairo)
LIBS    = -lm

all: collatz_tree collatz_scatter parity_sft profinite_compat branch_locus v2_danger deficit_analysis v2_danger_5x1 v2_danger_7x1 littlewood_torus littlewood_cfrac furstenberg furstenberg_entropy furstenberg_spectrum

collatz_tree: collatz_tree.c
	$(CC) $(CFLAGS) -o $@ $< $(CAIRO) $(LIBS)

collatz_scatter: collatz_scatter.c
	$(CC) $(CFLAGS) -o $@ $< $(CAIRO) $(LIBS)

parity_sft: parity_sft.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

profinite_compat: profinite_compat.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

branch_locus: branch_locus.c
	$(CC) $(CFLAGS) -fopenmp -o $@ $< $(LIBS)

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

run-branch-100B: branch_locus
	./branch_locus 100000000000

resume-branch-100B: branch_locus
	./branch_locus --resume 100000000000

v2_danger: v2_danger.c
	$(CC) $(CFLAGS) -fopenmp -o $@ $< $(LIBS)

deficit_analysis: deficit_analysis.c
	$(CC) $(CFLAGS) -fopenmp -o $@ $< $(LIBS)

run-deficit-1B: deficit_analysis
	./deficit_analysis 1000000000

run-deficit-10B: deficit_analysis
	./deficit_analysis 10000000000

gpu_branch: gpu_branch_host.c gpu_branch_kernel.cl
	$(CC) $(CFLAGS) -o $@ gpu_branch_host.c -lOpenCL $(LIBS)

run-gpu-compare: gpu_branch
	./gpu_branch --compare 1000000

run-gpu-branch: gpu_branch
	./gpu_branch --branch 100000000

run-gpu-fast: gpu_branch
	./gpu_branch --fast 1000000000

run-gpu-verify: gpu_branch
	./gpu_branch --verify 1000000000

run-v2danger: v2_danger
	./v2_danger --N 100000 --k 5

run-v2danger-1M: v2_danger
	./v2_danger --N 1000000 --k 7

run-v2danger-10M: v2_danger
	./v2_danger --N 10000000 --k 7

# ── 5x+1 targets ──────────────────────────────────────────────────
v2_danger_5x1: v2_danger_5x1.c
	$(CC) $(CFLAGS) -fopenmp -o $@ $< $(LIBS)

run-5x1: v2_danger_5x1
	./v2_danger_5x1 --N 100000 --k 3

run-5x1-1M: v2_danger_5x1
	./v2_danger_5x1 --N 1000000 --k 4

run-5x1-10M: v2_danger_5x1
	./v2_danger_5x1 --N 10000000 --k 4

run-5x1-1B: v2_danger_5x1
	./v2_danger_5x1 --N 1000000000 --k 4

run-5x1-10B: v2_danger_5x1
	./v2_danger_5x1 --N 10000000000 --k 4

# ── 7x+1 targets ──────────────────────────────────────────────────
v2_danger_7x1: v2_danger_7x1.c
	$(CC) $(CFLAGS) -fopenmp -o $@ $< $(LIBS)

run-7x1: v2_danger_7x1
	./v2_danger_7x1 --N 100000 --k 3

run-7x1-1M: v2_danger_7x1
	./v2_danger_7x1 --N 1000000 --k 3

run-7x1-10M: v2_danger_7x1
	./v2_danger_7x1 --N 10000000 --k 3

run-7x1-10B: v2_danger_7x1
	./v2_danger_7x1 --N 10000000000 --k 3

# ── Littlewood targets ───────────────────────────────────────────────
littlewood_torus: littlewood_torus.c
	$(CC) $(CFLAGS) -fopenmp -o $@ $< $(LIBS)

littlewood_cfrac: littlewood_cfrac.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

run-littlewood-torus: littlewood_torus
	./littlewood_torus --N 1000000000 --K 100

run-littlewood-torus-10B: littlewood_torus
	./littlewood_torus --N 10000000000 --K 100

run-littlewood-cfrac: littlewood_cfrac
	./littlewood_cfrac --search-N 100000000

# ── Furstenberg targets ────────────────────────────────────────────────
furstenberg: furstenberg_orbits.c
	$(CC) $(CFLAGS) -fopenmp -o $@ $< $(LIBS)

run-furstenberg: furstenberg
	./furstenberg 100000000

run-furstenberg-1B: furstenberg
	./furstenberg 1000000000

run-furstenberg-all: furstenberg
	./furstenberg --all 100000000

run-furstenberg-convergents: furstenberg
	./furstenberg --convergents

run-furstenberg-resume: furstenberg
	./furstenberg --resume 100000000

run-furstenberg-10B: furstenberg
	./furstenberg 10000000000

# ── Furstenberg Phase 2 (Entropy Bridge) ─────────────────────────────
furstenberg_entropy: furstenberg_entropy.c
	$(CC) $(CFLAGS) -fopenmp -o $@ $< $(LIBS)

run-entropy: furstenberg_entropy
	./furstenberg_entropy --all

run-entropy-atoms: furstenberg_entropy
	./furstenberg_entropy --atoms 20 12

run-entropy-orders: furstenberg_entropy
	./furstenberg_entropy --orders 40

run-entropy-rate: furstenberg_entropy
	./furstenberg_entropy --rate 24

# ── Furstenberg Phase 2 (Spectrum) ────────────────────────────────────
furstenberg_spectrum: furstenberg_spectrum.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

run-spectrum: furstenberg_spectrum
	./furstenberg_spectrum 30

run-spectrum-40: furstenberg_spectrum
	./furstenberg_spectrum 40

furstenberg_straddle: furstenberg_straddle.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

run-straddle: furstenberg_straddle
	./furstenberg_straddle 12

furstenberg_lift: furstenberg_lift.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

run-lift: furstenberg_lift
	./furstenberg_lift

run-lift-3scale: furstenberg_lift
	./furstenberg_lift --3scale

# ── Plotting targets ─────────────────────────────────────────────────
plot-5x1: plot_5x1_danger.py
	python3 plot_5x1_danger.py . ../visualizations

plot-compare: plot_danger_compare.py
	python3 plot_danger_compare.py ../saved_output/10B_data . ../visualizations

plot-7x1: plot_7x1_danger.py
	python3 plot_7x1_danger.py . ../visualizations

clean:
	rm -f collatz_tree collatz_scatter parity_sft profinite_compat branch_locus v2_danger deficit_analysis v2_danger_5x1 v2_danger_7x1 littlewood_torus littlewood_cfrac furstenberg furstenberg_entropy furstenberg_spectrum furstenberg_lift *.png *.csv

.PHONY: all clean run-tree run-scatter run-sft run-profinite run-branch run-branch-10B run-branch-100B resume-branch-100B run-v2danger run-v2danger-1M run-v2danger-10M run-gpu-compare run-gpu-branch run-gpu-fast run-gpu-verify run-deficit-1B run-deficit-10B run-5x1 run-5x1-1M run-5x1-10M run-5x1-1B run-5x1-10B run-7x1 run-7x1-1M run-7x1-10M run-7x1-10B run-littlewood-torus run-littlewood-torus-10B run-littlewood-cfrac run-furstenberg run-furstenberg-1B run-furstenberg-all run-furstenberg-convergents run-furstenberg-resume run-furstenberg-10B run-entropy run-entropy-atoms run-entropy-orders run-entropy-rate run-spectrum run-spectrum-40 run-lift run-lift-3scale plot-5x1 plot-compare plot-7x1
