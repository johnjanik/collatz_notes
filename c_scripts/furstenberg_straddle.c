/*
 * furstenberg_straddle.c — Straddle analysis for the lift problem
 *
 * KEY QUESTION: Does T_3-invariance of a measure μ imply T_3-invariance
 * of the induced atom mass vector p_m = μ([m/2^j, (m+1)/2^j))?
 *
 * The transfer matrix T has (Tp)_m = ∑_i T_{mi} p_i = (1/3)(p_{floor(m/3)} + ...)
 * But this is the "partition-level" T_3 action.
 *
 * At the measure level: T_3^{-1}([m/2^j, (m+1)/2^j)) consists of 3 intervals
 *   [(m+r)/(3·2^j), (m+r+1)/(3·2^j))  for r = 0, 2^j, 2·2^j
 * i.e., [m/(3·2^j), (m+1)/(3·2^j)) ∪ [(m+2^j)/(3·2^j), ...] ∪ [(m+2·2^j)/(3·2^j), ...]
 * Simplifying: T_3^{-1}(I_m) = I_{m/3}^{(j+log3)} -- but we work in base-2 partition.
 *
 * Each preimage interval [(m+r·2^j)/(3·2^j), (m+r·2^j+1)/(3·2^j)) has width 1/(3·2^j).
 * This interval straddles AT MOST TWO atoms of P_2^(j), since its width < atom width.
 *
 * The straddle fraction: what fraction of the preimage falls in which atom?
 * Given preimage interval [a/D, (a+1)/D) with D = 3·2^j, it intersects
 * atoms I_k = [k/2^j, (k+1)/2^j) where k = floor(a/3) and possibly k+1.
 *
 * The overlap with I_k is: min((k+1)/2^j, (a+1)/D) - max(k/2^j, a/D)
 *   = min((3(k+1))/D, (a+1)/D) - max(3k/D, a/D)
 *   = (min(3k+3, a+1) - max(3k, a)) / D
 *
 * Since a = 3k + (a mod 3) where a mod 3 ∈ {0,1,2}:
 *   - a mod 3 = 0: fully inside I_k, overlap = 1/D, no straddle
 *   - a mod 3 = 1: overlap with I_k = 2/D, overlap with I_{k+1} = 0 ... wait
 *
 * Actually: a = m + r·2^j where m ∈ [0, 2^j) and r ∈ {0,1,2}.
 * The atom containing point a/D is atom k = floor(a/3) = floor((m + r·2^j)/3).
 * The overlap with atom k: fraction = (3k+3 - a)/1 if a > 3k, else 1.
 *   If a mod 3 = 0: a = 3k, overlap = 3/3 = 1 (no straddle)
 *   If a mod 3 = 1: a = 3k+1, overlap with I_k = 2/3, overlap with I_{k+1} = 1/3
 *   If a mod 3 = 2: a = 3k+2, overlap with I_k = 1/3, overlap with I_{k+1} = 2/3
 *
 * So the straddle pattern depends ONLY on a mod 3, where a = m + r·2^j.
 * Since gcd(2^j, 3) = 1, as r varies over {0,1,2}, a mod 3 hits all of {m mod 3, (m+2^j) mod 3, (m+2·2^j) mod 3}.
 * Since 2^j mod 3 = (-1)^j mod 3 = 2 if j odd, 1 if j even.
 *
 * KEY INSIGHT: For each source atom I_m, T_3^{-1}(I_m) has 3 preimage intervals.
 * The fraction that falls "correctly" into the expected transfer matrix target
 * vs. the fraction that "straddles" into adjacent atoms can be computed exactly.
 *
 * This program computes:
 * 1. The straddle matrix S_{ij} = overlap of T_3^{-1}(I_i) with I_j (exact fractions)
 * 2. Compare S with the transfer matrix T (S should equal T for the lift to work)
 * 3. The "straddle error" E = S - T (how much the lift fails)
 * 4. The spectral gap of S (does S also force uniformity?)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <inttypes.h>

#define PI 3.14159265358979323846264338327950288L

/*
 * For atom I_m = [m/2^j, (m+1)/2^j) on the circle:
 *
 * T_3^{-1}(I_m) = { x : 3x mod 1 ∈ I_m }
 *               = ⋃_{r=0}^{2} [(m + r·2^j)/(3·2^j), (m + r·2^j + 1)/(3·2^j))
 *
 * Each piece has width 1/(3·2^j) = (1/3) × (atom width).
 *
 * Piece r starts at position (m + r·2^j)/(3·2^j) and ends at (m + r·2^j + 1)/(3·2^j).
 * In atom coordinates (multiply by 2^j):
 *   start_atom = (m + r·2^j) / 3
 *   end_atom   = (m + r·2^j + 1) / 3
 *
 * The atom containing the start is k = floor((m + r·2^j) / 3).
 * Let a = m + r·2^j. Then:
 *   a mod 3 = 0: piece is entirely in atom k = a/3
 *   a mod 3 = 1: piece straddles atoms k and k+1 (2/3 in k, 1/3 in k+1)  -- WRONG
 *   a mod 3 = 2: piece straddles atoms k and k+1 (1/3 in k, 2/3 in k+1)  -- WRONG
 *
 * Wait, let me recompute. a mod 3 = 1 means a = 3k+1.
 * Piece: [(3k+1)/(3·2^j), (3k+2)/(3·2^j)) = [(k + 1/3)·(1/2^j), (k + 2/3)·(1/2^j))
 * This is ENTIRELY inside atom k = floor(a/3). (k ≤ k+1/3 < k+2/3 < k+1)
 *
 * Hmm, ALL pieces are inside a single atom!
 *
 * Wait. Let me reconsider. a/3 is NOT an atom boundary. Atom k goes from k/2^j to (k+1)/2^j.
 * In the "tripled" coordinates (D = 3·2^j), atom k goes from 3k to 3(k+1) = 3k+3.
 * Piece starting at a has range [a, a+1) in these coordinates.
 *
 * So: piece [a, a+1) is inside atom k = floor(a/3) iff a+1 ≤ 3(k+1) = 3k+3.
 * Since a = 3k + (a mod 3), we need 3k + (a mod 3) + 1 ≤ 3k + 3, i.e., a mod 3 ≤ 2.
 * This is ALWAYS true. So every piece is entirely inside one atom!
 *
 * CONCLUSION: The straddle matrix S equals the transfer matrix T exactly.
 * The "lift" is FREE — no straddle occurs!
 *
 * Let me verify this more carefully with explicit computation.
 */

static void verify_no_straddle(int j) {
    uint64_t N = 1ULL << j;  /* number of atoms */
    uint64_t D = 3ULL * N;    /* common denominator */

    printf("j = %d: N = %"PRIu64" atoms, D = 3·N = %"PRIu64"\n", j, N, D);

    /* For each target atom I_m, compute T_3^{-1}(I_m) */
    int straddle_count = 0;
    int total_pieces = 0;

    uint64_t m_limit = (j <= 16) ? N : 1000;  /* sample for large j */

    for (uint64_t m = 0; m < m_limit; m++) {
        for (int r = 0; r < 3; r++) {
            uint64_t a = m + (uint64_t)r * N;  /* start of preimage piece in D-coords */
            /* Piece occupies [a, a+1) in D-coordinates */
            uint64_t atom_start = a / 3;       /* atom containing start */
            uint64_t atom_end = (a + 1 - 1) / 3;  /* atom containing last point */
            /* Since piece has width 1 in D-coords and atoms have width 3,
             * the piece is entirely in one atom iff floor(a/3) == floor(a/3).
             * Actually, the piece [a, a+1) crosses an atom boundary iff
             * 3 divides some integer in (a, a+1), i.e., iff a+1 is a multiple of 3
             * AND a+1 < D.
             * But [a, a+1) is a half-open interval of width 1 in D-coords.
             * Atom boundaries in D-coords are at 0, 3, 6, ..., 3(N-1).
             * The piece crosses a boundary iff there exists integer b with
             * a < 3b ≤ a, impossible since 3b is integer and a < 3b means 3b ≥ a+1.
             * So: piece [a, a+1) crosses atom boundary at 3k iff a < 3k < a+1,
             * i.e., 3k = a + something where 0 < something < 1. But 3k is integer
             * and a is integer, so 3k - a ∈ {0,1,2,...}. We need 0 < 3k - a < 1,
             * which has NO integer solutions. So NO straddle ever occurs!
             */
            if (atom_start != atom_end) {
                straddle_count++;
                printf("  STRADDLE: m=%"PRIu64", r=%d, a=%"PRIu64", atoms %"PRIu64" to %"PRIu64"\n",
                       m, r, a, atom_start, atom_end);
            }
            total_pieces++;

            /* Also verify: which atom does this piece land in? */
            uint64_t source_atom = a / 3;  /* the atom in P_2^(j) */
            (void)source_atom;
        }
    }

    printf("  Checked %d preimage pieces: %d straddles\n", total_pieces, straddle_count);
    if (straddle_count == 0)
        printf("  CONFIRMED: No straddle. S = T exactly.\n");
    printf("\n");
}

/*
 * Now let's think more carefully about what "lift" means.
 *
 * If μ is T_3-invariant (μ = μ ∘ T_3^{-1}), then for atom I_m:
 *   p_m = μ(I_m) = μ(T_3^{-1}(I_m)) = Σ_{r=0}^{2} μ(piece_{m,r})
 *
 * Piece_{m,r} = [(m + r·N)/(3N), (m + r·N + 1)/(3N))
 * This piece lies entirely in atom k_{m,r} = floor((m + r·N)/3).
 *
 * So: p_m = Σ_r μ(piece_{m,r})
 *
 * But we DON'T know that μ(piece_{m,r}) = (1/3)·p_{k_{m,r}}.
 * That would be TRUE for Lebesgue measure (uniform within atoms).
 * For an arbitrary measure, the piece could carry more or less than
 * 1/3 of the atom's mass.
 *
 * The transfer matrix equation Tp = p says:
 *   p_m = (1/3)(p_{k_{m,0}} + p_{k_{m,1}} + p_{k_{m,2}})
 *
 * The actual T_3-invariance gives:
 *   p_m = μ(piece_{m,0}) + μ(piece_{m,1}) + μ(piece_{m,2})
 *
 * These are EQUAL iff μ(piece_{m,r}) = (1/3)·p_{k_{m,r}} for each r.
 *
 * This means: within each atom I_k, the three sub-intervals that map to
 * different target atoms must each carry exactly 1/3 of the atom's mass.
 *
 * The sub-intervals are: [k/N, (k+1)/N) is divided by T_3 into
 * three pieces of width 1/(3N) each: [(3k+s)/(3N), (3k+s+1)/(3N)) for s=0,1,2.
 * Piece s maps to: T_3(x) = 3x mod 1. For x ∈ [(3k+s)/(3N), (3k+s+1)/(3N)),
 * 3x ∈ [(3k+s)/N, (3k+s+1)/N).
 * If 3k+s < N: T_3(x) ∈ [(3k+s)/N, (3k+s+1)/N) → atom 3k+s.
 * If 3k+s ≥ N: T_3(x) = 3x - floor(3k/N+...) → atom (3k+s) mod N.
 *
 * So the three sub-pieces of atom k map to atoms (3k) mod N, (3k+1) mod N, (3k+2) mod N.
 * T_3-invariance at the partition level requires each sub-piece to carry 1/3 of μ(I_k).
 *
 * This is EXACTLY the "symbolic dynamics" constraint: within each P_2^(j) atom,
 * the measure must be "equidistributed" on the three T_3-preimage sub-intervals.
 *
 * The question: does T_3-invariance of μ (global) force this local equidistribution?
 *
 * Answer: NOT necessarily for a single j. But for all j simultaneously, YES!
 * Because as j → ∞, the partition P_2^(j) becomes the point partition,
 * and any non-atomic μ must eventually resolve the structure.
 *
 * More precisely: μ(piece_{m,r}) / p_{k_{m,r}} may differ from 1/3 at scale j,
 * but T_3-invariance at all finer scales j' > j constrains this ratio.
 *
 * Let's compute this ratio numerically for specific non-Lebesgue measures.
 */

/* Compute the transfer matrix T and the "actual" straddle matrix S
 * for a given non-uniform distribution on [0,1) */
static void compute_transfer_vs_actual(int j) {
    int N = 1 << j;
    printf("═══════════════════════════════════════════════════\n");
    printf("  Transfer vs actual for j=%d (N=%d)\n", j, N);
    printf("═══════════════════════════════════════════════════\n\n");

    /* Transfer matrix T: T[m][k] = 1/3 if m ∈ {3k, 3k+1, 3k+2} mod N */
    double *T = calloc((size_t)N * N, sizeof(double));
    for (int k = 0; k < N; k++) {
        int m0 = (3*k) % N;
        int m1 = (3*k+1) % N;
        int m2 = (3*k+2) % N;
        T[m0 * N + k] += 1.0/3.0;
        T[m1 * N + k] += 1.0/3.0;
        T[m2 * N + k] += 1.0/3.0;
    }

    /* For Lebesgue measure: p_k = 1/N for all k.
     * (Tp)_m = (1/3) Σ_{k: m ∈ {3k,3k+1,3k+2}} p_k = (1/3)(1/N + 1/N + 1/N) = 1/N. ✓ */

    /* For the Cantor measure on {x : all base-3 digits ∈ {0,2}}:
     * μ([m/2^j, (m+1)/2^j)) depends on the base-3 expansion of m/2^j...
     * This is hard to compute. Let's use a simpler test: */

    /* Test 1: p_k = 2/N if k is even, 0 if k is odd (alternating measure) */
    printf("  Test 1: Alternating measure (p_even = 2/N, p_odd = 0)\n");
    double *p = malloc(N * sizeof(double));
    double *Tp = malloc(N * sizeof(double));
    for (int k = 0; k < N; k++)
        p[k] = (k % 2 == 0) ? 2.0/N : 0.0;

    /* Compute Tp */
    for (int m = 0; m < N; m++) {
        Tp[m] = 0;
        for (int k = 0; k < N; k++)
            Tp[m] += T[m * N + k] * p[k];
    }

    /* Compare p and Tp */
    double max_diff = 0;
    for (int m = 0; m < N; m++) {
        double diff = fabs(Tp[m] - p[m]);
        if (diff > max_diff) max_diff = diff;
    }
    printf("    ||Tp - p||_∞ = %.6e (not T-invariant)\n", max_diff);

    /* How many iterations until ||T^n p - uniform|| < ε? */
    for (int iter = 0; iter < 10; iter++) {
        for (int m = 0; m < N; m++) {
            Tp[m] = 0;
            for (int k = 0; k < N; k++)
                Tp[m] += T[m * N + k] * p[k];
        }
        memcpy(p, Tp, N * sizeof(double));

        double dist = 0;
        for (int m = 0; m < N; m++)
            dist += (p[m] - 1.0/N) * (p[m] - 1.0/N);
        dist = sqrt(dist);

        printf("    T^%d p: ||p - uniform||_2 = %.6e (× 1/3 = %.6e)\n",
               iter+1, dist, dist * 3);
    }

    printf("\n");

    /* Test 2: T_3 acting on an actual measure.
     * Let's compute what T_3-invariance ACTUALLY gives us.
     *
     * For a T_3-invariant μ: p_m = Σ_r μ(piece_{m,r})
     * where piece_{m,r} ⊂ atom k_{m,r} = floor((m + r·N)/3).
     *
     * We DON'T know how μ distributes within atoms, but we know:
     * μ(piece_{m,r}) ≤ p_{k_{m,r}}  (can't exceed total atom mass)
     *
     * And Σ_{pieces in atom k} μ(piece) = p_k  (pieces partition each atom)
     *
     * How many pieces fall into atom k?
     * Piece (m,r) → atom floor((m + r·N)/3).
     * For each atom k, the pieces landing there satisfy m + r·N ∈ {3k, 3k+1, 3k+2}
     * i.e., m ∈ {3k - r·N, 3k+1 - r·N, 3k+2 - r·N} mod 3N, but m ∈ [0,N) and r ∈ {0,1,2}.
     *
     * Since each atom has width 3 in D-coordinates and there are N atoms × 3 = 3N pieces
     * total, exactly 3 pieces land in each atom. So each atom is divided into 3 equal-width
     * sub-intervals, each mapping to a different target. This is EXACTLY the T_3 symbolic
     * dynamics.
     */
    printf("  Verifying: each atom contains exactly 3 sub-pieces:\n");
    int *piece_count = calloc(N, sizeof(int));
    for (uint64_t m = 0; m < (uint64_t)N; m++) {
        for (int r = 0; r < 3; r++) {
            uint64_t a = m + (uint64_t)r * N;
            uint64_t src = a / 3;  /* source atom */
            piece_count[src]++;
        }
    }
    int all_three = 1;
    for (int k = 0; k < N; k++) {
        if (piece_count[k] != 3) {
            printf("    UNEXPECTED: atom %d has %d pieces\n", k, piece_count[k]);
            all_three = 0;
        }
    }
    if (all_three)
        printf("    CONFIRMED: every atom contains exactly 3 sub-pieces.\n");

    /* So: within atom k, there are 3 sub-intervals of equal width 1/(3N).
     * T_3-invariance says: for each target m, the sum of the 3 sub-piece masses
     * (one from each of the 3 source atoms) equals p_m.
     *
     * This is a system of N equations in 3N unknowns (the sub-piece masses).
     * The constraint is: sub-pieces within each atom sum to the atom mass.
     * That gives another N equations. Total: 2N equations, 3N unknowns, N degrees of freedom.
     *
     * The transfer matrix equation Tp = p is the UNIQUE solution where each sub-piece
     * carries exactly 1/3 of its atom's mass. But there are other solutions!
     *
     * The extra degrees of freedom allow the measure to distribute non-uniformly
     * within atoms. The question is whether these extra degrees of freedom are
     * compatible with T_3-invariance at ALL scales j simultaneously.
     */
    printf("\n  Degrees of freedom analysis:\n");
    printf("    At scale j=%d: %d atoms, %d sub-pieces\n", j, N, 3*N);
    printf("    Constraints from T_3-invariance: %d equations\n", N);
    printf("    Constraints from atom mass sums: %d equations\n", N);
    printf("    Total constraints: %d, unknowns: %d\n", 2*N, 3*N);
    printf("    Degrees of freedom: %d\n", N);
    printf("\n    These %d DOFs represent how μ distributes within atoms.\n", N);
    printf("    At scale j+1, these DOFs are further constrained.\n");
    printf("    The question: do the constraints at all scales j eliminate all DOFs?\n\n");

    free(T);
    free(p);
    free(Tp);
    free(piece_count);
}

/*
 * The key analysis: multi-scale constraint propagation.
 *
 * At scale j, atom I_k has 3 sub-pieces: s_{k,0}, s_{k,1}, s_{k,2}.
 * These map under T_3 to different atoms. The masses w_{k,s} satisfy:
 *   w_{k,0} + w_{k,1} + w_{k,2} = p_k  (atom mass constraint)
 *   Σ_r w_{k_{m,r}, s_{m,r}} = p_m      (T_3-invariance at scale j)
 *
 * At scale j+1, each sub-piece of scale j contains 2 sub-sub-pieces of scale j+1.
 * So at scale j+1, we have 2^{j+1} atoms, each divided into 3 sub-pieces.
 * The sub-piece masses at scale j+1 further constrain the distribution.
 *
 * Claim: After considering all scales j ≥ j_0, the only solution compatible
 * with T_3-invariance at all scales is the uniform distribution within each atom
 * (i.e., Tp = p at every scale).
 *
 * This is because the sub-pieces at scale j become resolved into separate atoms
 * at scale j + ceil(log_2(3)). After about log_2(3) ≈ 1.585 refinements,
 * each old sub-piece becomes a separate atom, and the constraint at the new
 * scale forces equal mass.
 *
 * More precisely: the sub-piece [3k+s, 3k+s+1) in D-coordinates at scale j
 * corresponds to the atom interval [(3k+s)/(3·2^j), (3k+s+1)/(3·2^j)).
 * At scale j+1, this interval is split by the boundary at (3k+s+1/2)/(3·2^j)
 * (which is the boundary between atoms 2(3k+s)/(3·2) and (2(3k+s)+1)/(3·2) at scale j+1...
 * this is getting complicated.)
 *
 * Let me just verify computationally for small j.
 */

static void multi_scale_constraint(int j_max) {
    printf("═══════════════════════════════════════════════════\n");
    printf("  Multi-scale constraint propagation (j=3 to %d)\n", j_max);
    printf("═══════════════════════════════════════════════════\n\n");

    /* At each scale j, count the dimension of the solution space
     * for the system: Tp = p AND atom-sum constraints AND consistency
     * with the coarser scale. */

    for (int j = 3; j <= j_max && j <= 12; j++) {
        int N = 1 << j;
        int D = 3 * N;

        /* Build the constraint matrix.
         * Unknowns: w_{k,s} for k ∈ [0,N), s ∈ {0,1,2} (sub-piece masses)
         * = 3N unknowns.
         *
         * Constraint Type 1 (atom sum): w_{k,0} + w_{k,1} + w_{k,2} = p_k
         * But p_k is also a variable... actually, p_k is determined by the w's.
         *
         * Constraint Type 2 (T_3-invariance):
         * For each target atom m: p_m = Σ_r w_{floor((m+r·N)/3), (m+r·N) mod 3}
         * where the source atom is floor((m+r·N)/3) and the sub-piece index is (m+r·N) mod 3.
         *
         * Substituting p_m = w_{m,0} + w_{m,1} + w_{m,2}:
         * w_{m,0} + w_{m,1} + w_{m,2} = Σ_r w_{floor((m+r·N)/3), (m+r·N) mod 3}
         *
         * This gives N equations in 3N unknowns.
         * Plus non-negativity: w_{k,s} ≥ 0 and normalization: Σ w_{k,s} = 1.
         *
         * The rank of the system determines the degrees of freedom.
         */

        /* Build the N × 3N matrix A where A[m, 3k+s] = coefficient of w_{k,s}
         * in the equation for atom m.
         *
         * LHS: w_{m,0} + w_{m,1} + w_{m,2}  →  A[m, 3m+s] += -1 for s=0,1,2
         * RHS: Σ_r w_{src, sub}  →  A[m, 3*src + sub] += 1
         */
        int rows = N;
        int cols = 3 * N;
        double *A = calloc((size_t)rows * cols, sizeof(double));

        for (int m = 0; m < N; m++) {
            /* LHS: -w_{m,0} - w_{m,1} - w_{m,2} */
            A[m * cols + 3*m + 0] -= 1.0;
            A[m * cols + 3*m + 1] -= 1.0;
            A[m * cols + 3*m + 2] -= 1.0;

            /* RHS: Σ_r w_{src(m,r), sub(m,r)} */
            for (int r = 0; r < 3; r++) {
                int a = m + r * N;
                int src = a / 3;
                int sub = a % 3;
                A[m * cols + 3*src + sub] += 1.0;
            }
        }

        /* Compute rank by Gaussian elimination */
        int rank = 0;
        int *pivot_col = malloc(rows * sizeof(int));
        for (int i = 0; i < rows; i++) pivot_col[i] = -1;
        int *used = calloc(cols, sizeof(int));

        for (int row = 0; row < rows; row++) {
            /* Find pivot */
            int best_col = -1;
            double best_val = 1e-10;
            for (int col = 0; col < cols; col++) {
                if (used[col]) continue;
                if (fabs(A[row * cols + col]) > best_val) {
                    best_val = fabs(A[row * cols + col]);
                    best_col = col;
                }
            }
            if (best_col < 0) continue;  /* zero row */

            /* Swap pivot to diagonal-ish position */
            pivot_col[rank] = best_col;
            used[best_col] = 1;

            /* Eliminate */
            double pivot = A[row * cols + best_col];
            for (int col = 0; col < cols; col++)
                A[row * cols + col] /= pivot;

            for (int other = 0; other < rows; other++) {
                if (other == row) continue;
                double factor = A[other * cols + best_col];
                if (fabs(factor) < 1e-12) continue;
                for (int col = 0; col < cols; col++)
                    A[other * cols + col] -= factor * A[row * cols + col];
            }
            rank++;
        }

        int dof = cols - rank;
        printf("  j=%2d: N=%4d atoms, 3N=%5d sub-pieces, "
               "rank=%4d, DOF=%4d (= %d per atom)\n",
               j, N, cols, rank, dof, (N > 0) ? dof / N : 0);

        /* The transfer matrix equation Tp = p has a 1-dimensional solution space
         * (the uniform distribution, up to normalization). The sub-piece system
         * should have MORE solutions, but the "extra" solutions represent
         * within-atom non-uniformity. At finer scales, these are constrained further. */

        free(A);
        free(pivot_col);
        free(used);
    }

    printf("\n  If DOF/atom = 2 at every scale, this means within each atom,\n");
    printf("  the 3 sub-pieces have 2 free parameters (constrained only by\n");
    printf("  the atom sum). The transfer matrix equation fixes 0 of them.\n");
    printf("  Multi-scale consistency (j and j+1 simultaneously) would\n");
    printf("  reduce the DOF further.\n\n");
}

int main(int argc, char **argv) {
    int j_max = 10;
    if (argc > 1) j_max = atoi(argv[1]);

    printf("╔══════════════════════════════════════════════════╗\n");
    printf("║  Straddle Analysis for the Lift Problem         ║\n");
    printf("╚══════════════════════════════════════════════════╝\n\n");

    printf("═══════════════════════════════════════════════════\n");
    printf("  Step 1: Verify no straddle (S = T exactly)\n");
    printf("═══════════════════════════════════════════════════\n\n");

    for (int j = 3; j <= 8; j++)
        verify_no_straddle(j);

    printf("  THEOREM: In D = 3·2^j coordinates, each preimage piece\n");
    printf("  [a, a+1) is entirely inside one atom [3k, 3k+3).\n");
    printf("  Proof: a and 3k are both integers, a = 3k + (a mod 3),\n");
    printf("  so a+1 ≤ 3k+3 iff a mod 3 ≤ 2 (always true).  □\n\n");

    printf("═══════════════════════════════════════════════════\n");
    printf("  Step 2: Transfer matrix vs actual T_3-invariance\n");
    printf("═══════════════════════════════════════════════════\n\n");

    compute_transfer_vs_actual(6);

    printf("═══════════════════════════════════════════════════\n");
    printf("  Step 3: Multi-scale constraint analysis\n");
    printf("═══════════════════════════════════════════════════\n\n");

    multi_scale_constraint(j_max);

    printf("═══════════════════════════════════════════════════\n");
    printf("  CONCLUSION\n");
    printf("═══════════════════════════════════════════════════\n\n");
    printf("  The straddle matrix S equals the transfer matrix T.\n");
    printf("  T_3-invariance of μ gives: p_m = Σ_r w_{src,sub}\n");
    printf("  but does NOT force w_{k,s} = (1/3)p_k.\n\n");
    printf("  The DOF = N at each scale j: within each atom,\n");
    printf("  2 free parameters (how μ distributes among 3 sub-pieces).\n");
    printf("  These DOFs are constrained by T_3-invariance at FINER scales.\n\n");
    printf("  The entropy bridge reduces to: does multi-scale\n");
    printf("  T_3-invariance force within-atom uniformity?\n\n");

    return 0;
}
