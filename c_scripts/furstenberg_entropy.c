/*
 * furstenberg_entropy.c — Phase 2: Entropy bridge for Furstenberg ×2, ×3
 *
 * Computes entropy-related quantities for the joint partition
 * P_2^(j) ∨ P_3^(k) on the circle T = R/Z.
 *
 * The partition P_2^(j) has boundary points at {m/2^j : 0 ≤ m < 2^j}.
 * The partition P_3^(k) has boundary points at {m'/3^k : 0 ≤ m' < 3^k}.
 * The joint partition P_2^(j) ∨ P_3^(k) overlays both sets of boundaries.
 *
 * In common denominator D = 2^j · 3^k, all boundaries become integers:
 *   2-adic: {m · 3^k : 0 ≤ m < 2^j}     (equally spaced by 3^k)
 *   3-adic: {m' · 2^j : 0 ≤ m' < 3^k}   (equally spaced by 2^j)
 *
 * Key computations:
 *   1. Atom width spectrum (sort boundaries, compute gaps)
 *   2. Entropy H(P_2^(j) ∨ P_3^(k)) under Lebesgue measure
 *   3. Minimum atom width and Baker bound comparison
 *   4. Multiplicative orders ord_{2^j}(3) and ord_{3^k}(2)
 *   5. Entropy deficit: log(#atoms) - H (measures atom non-uniformity)
 *
 * Baker's theorem gives: min |m/2^j - m'/3^k| ≥ 1/(2^j · 3^k)
 * (trivially from coprimality).  The sharper question is: how thin can
 * atoms get relative to the mean width 1/(2^j + 3^k)?
 *
 * Modes:
 *   --atoms J K       Full atom analysis for P_2^J ∨ P_3^K
 *   --sweep JMAX      Sweep (j,k) pairs up to j=JMAX, output entropy table
 *   --orders JMAX     Multiplicative orders up to 2^JMAX, 3^JMAX
 *   --all             All of the above (default JMAX=24)
 *
 * Build: make furstenberg_entropy
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <inttypes.h>
#include <omp.h>

/* ═══════════════════════════════════════════════════════════════════
 * Constants
 * ═══════════════════════════════════════════════════════════════════ */

#define LOG2_3  1.5849625007211561814537389439478165286L

static const char *ATOMS_CSV   = "furstenberg_atoms.csv";
static const char *ENTROPY_CSV = "furstenberg_entropy.csv";
static const char *ORDERS_CSV  = "furstenberg_orders.csv";

/* Maximum j,k for full atom analysis (bounded by memory) */
#define MAX_J_ATOMS  24   /* 2^24 = 16.7M boundary points */
#define MAX_K_ATOMS  15   /* 3^15 = 14.3M boundary points */

/* ═══════════════════════════════════════════════════════════════════
 * Modular arithmetic (128-bit intermediate)
 * ═══════════════════════════════════════════════════════════════════ */

static inline uint64_t mulmod(uint64_t a, uint64_t b, uint64_t m) {
    return (unsigned __int128)a * b % m;
}

static uint64_t powmod(uint64_t base, uint64_t exp, uint64_t mod) {
    uint64_t r = 1;
    base %= mod;
    while (exp > 0) {
        if (exp & 1) r = mulmod(r, base, mod);
        base = mulmod(base, base, mod);
        exp >>= 1;
    }
    return r;
}

/* ═══════════════════════════════════════════════════════════════════
 * Comparison for qsort (uint64_t)
 * ═══════════════════════════════════════════════════════════════════ */

static int cmp_u64(const void *a, const void *b) {
    uint64_t va = *(const uint64_t *)a;
    uint64_t vb = *(const uint64_t *)b;
    return (va > vb) - (va < vb);
}

/* Comparator for TaggedPt (compare by val field, which is first) */
typedef struct { uint64_t val; uint8_t type; } TaggedPt;

static int cmp_tagged(const void *a, const void *b) {
    uint64_t va = ((const TaggedPt *)a)->val;
    uint64_t vb = ((const TaggedPt *)b)->val;
    return (va > vb) - (va < vb);
}

/* ═══════════════════════════════════════════════════════════════════
 * Compute 3^k as uint64_t (returns 0 on overflow)
 * ═══════════════════════════════════════════════════════════════════ */

static uint64_t pow3(int k) {
    uint64_t r = 1;
    for (int i = 0; i < k; i++) {
        if (r > UINT64_MAX / 3) return 0;
        r *= 3;
    }
    return r;
}

static uint64_t pow2(int j) {
    if (j >= 64) return 0;
    return 1ULL << j;
}

/* ═══════════════════════════════════════════════════════════════════
 * Full atom analysis for P_2^(j) ∨ P_3^(k)
 *
 * Generates all boundary points in common denominator D = 2^j · 3^k,
 * sorts them, computes gap distribution and entropy.
 * ═══════════════════════════════════════════════════════════════════ */

typedef struct {
    int j, k;
    uint64_t n_atoms;      /* 2^j + 3^k - 1 (minus shared 0) */
    double min_width;      /* minimum atom width (as fraction of circle) */
    double max_width;      /* maximum atom width */
    double mean_width;     /* = 1 / n_atoms */
    double entropy;        /* H = -Σ w_i log w_i (natural log) */
    double max_entropy;    /* log(n_atoms) */
    double entropy_deficit;/* max_entropy - entropy */
    double min_width_ratio;/* min_width / mean_width */
    uint64_t min_gap;      /* minimum gap in integer units */
    uint64_t max_gap;      /* maximum gap in integer units */
    double baker_ratio;    /* min_width / (1/D) where D = 2^j · 3^k */
} AtomStats;

static AtomStats compute_atoms(int j, int k) {
    AtomStats s;
    memset(&s, 0, sizeof(s));
    s.j = j;
    s.k = k;

    uint64_t p2 = pow2(j);
    uint64_t p3 = pow3(k);
    if (p2 == 0 || p3 == 0) return s;

    /* Check D = 2^j · 3^k fits in uint64 */
    if (p2 > UINT64_MAX / p3) return s;
    uint64_t D = p2 * p3;

    uint64_t n_2adic = p2;
    uint64_t n_3adic = p3;
    uint64_t total_pts = n_2adic + n_3adic - 1;  /* -1 for shared 0 */
    s.n_atoms = total_pts;

    /* Allocate boundary point array */
    uint64_t *pts = malloc(total_pts * sizeof(uint64_t));
    if (!pts) {
        fprintf(stderr, "OOM: atoms for j=%d k=%d need %"PRIu64" points\n",
                j, k, total_pts);
        return s;
    }

    /* Fill 2-adic boundaries: m · 3^k for m = 0, ..., 2^j - 1 */
    uint64_t idx = 0;
    for (uint64_t m = 0; m < n_2adic; m++)
        pts[idx++] = m * p3;

    /* Fill 3-adic boundaries: m' · 2^j for m' = 1, ..., 3^k - 1 */
    /* Skip m'=0 (already included as 2-adic m=0) */
    for (uint64_t m = 1; m < n_3adic; m++)
        pts[idx++] = m * p2;

    /* Sort */
    qsort(pts, total_pts, sizeof(uint64_t), cmp_u64);

    /* Compute gaps and entropy */
    s.min_gap = UINT64_MAX;
    s.max_gap = 0;
    double H = 0.0;

    for (uint64_t i = 0; i < total_pts; i++) {
        uint64_t next = (i + 1 < total_pts) ? pts[i + 1] : D;
        uint64_t gap = next - pts[i];

        if (gap < s.min_gap) s.min_gap = gap;
        if (gap > s.max_gap) s.max_gap = gap;

        /* Entropy contribution: -(gap/D) log(gap/D)
         * = -(gap/D)(log gap - log D)
         * Accumulate: H += (gap/D) * log(gap)  [subtract log D at end] */
        if (gap > 0) {
            double w = (double)gap / (double)D;
            H -= w * log(w);
        }
    }

    s.entropy = H;
    s.max_entropy = log((double)total_pts);
    s.entropy_deficit = s.max_entropy - H;
    s.min_width = (double)s.min_gap / (double)D;
    s.max_width = (double)s.max_gap / (double)D;
    s.mean_width = 1.0 / (double)total_pts;
    s.min_width_ratio = s.min_width / s.mean_width;
    s.baker_ratio = (double)s.min_gap;  /* min_gap ≥ 1 from coprimality */

    free(pts);
    return s;
}

/* ═══════════════════════════════════════════════════════════════════
 * Atom analysis mode: single (j,k) pair with detailed output
 * ═══════════════════════════════════════════════════════════════════ */

static void run_atom_analysis(int j, int k) {
    printf("\n=== Atom Analysis: P_2^(%d) ∨ P_3^(%d) ===\n\n", j, k);

    uint64_t p2 = pow2(j);
    uint64_t p3 = pow3(k);
    if (p2 == 0 || p3 == 0) {
        printf("  Overflow: j=%d or k=%d too large.\n", j, k);
        return;
    }
    if (p2 > UINT64_MAX / p3) {
        printf("  Overflow: D = 2^%d · 3^%d exceeds uint64.\n", j, k);
        return;
    }
    uint64_t D = p2 * p3;
    uint64_t total_pts = p2 + p3 - 1;

    printf("  2^j = %"PRIu64",  3^k = %"PRIu64"\n", p2, p3);
    printf("  D = 2^j · 3^k = %"PRIu64"\n", D);
    printf("  Boundary points: %"PRIu64" (2-adic) + %"PRIu64" (3-adic) - 1 = %"PRIu64"\n",
           p2, p3, total_pts);
    printf("  Atom count: %"PRIu64"\n", total_pts);
    printf("  Memory: %.1f MB\n\n", (double)(total_pts * 8) / 1e6);

    double t0 = omp_get_wtime();
    AtomStats s = compute_atoms(j, k);
    double elapsed = omp_get_wtime() - t0;

    if (s.n_atoms == 0) {
        printf("  Computation failed (overflow or OOM).\n");
        return;
    }

    printf("  Computed in %.3f s\n\n", elapsed);
    printf("  Minimum atom width:  %.15e  (= %"PRIu64" / D)\n", s.min_width, s.min_gap);
    printf("  Maximum atom width:  %.15e  (= %"PRIu64" / D)\n", s.max_width, s.max_gap);
    printf("  Mean atom width:     %.15e\n", s.mean_width);
    printf("  Min/mean ratio:      %.8f\n", s.min_width_ratio);
    printf("  Baker floor (1/D):   %.15e\n", 1.0 / (double)D);
    printf("  Min gap integer:     %"PRIu64"  (should be ≥ 1)\n\n", s.min_gap);

    printf("  Entropy (Lebesgue):  %.10f nats\n", s.entropy);
    printf("  Max entropy:         %.10f nats  (= log %"PRIu64")\n", s.max_entropy, total_pts);
    printf("  Entropy deficit:     %.10f nats\n", s.entropy_deficit);
    printf("  Efficiency:          %.8f  (H / H_max)\n", s.entropy / s.max_entropy);

    printf("\n  Theory check:\n");
    printf("    j·log 2 + k·log 3 = %.6f\n", j * log(2.0) + k * log(3.0));
    printf("    log(2^j + 3^k)    = %.6f\n", log((double)p2 + (double)p3));
    printf("    H / j             = %.6f  (should → log 2 = %.6f as j→∞)\n",
           s.entropy / j, log(2.0));
}

/* ═══════════════════════════════════════════════════════════════════
 * Entropy sweep: compute atom stats for many (j,k) pairs
 * ═══════════════════════════════════════════════════════════════════ */

static void run_entropy_sweep(int jmax) {
    printf("\n=== Entropy Sweep: P_2^(j) ∨ P_3^(k), j ≤ %d ===\n\n", jmax);

    FILE *csv = fopen(ENTROPY_CSV, "w");
    if (!csv) { perror(ENTROPY_CSV); return; }
    fprintf(csv, "j,k,n_atoms,min_width,max_width,mean_width,min_mean_ratio,"
                 "entropy,max_entropy,deficit,efficiency,H_over_j,H_over_k,"
                 "min_gap_int,baker_ratio\n");

    /* Header */
    printf("  %-4s %-4s %12s %12s %10s %10s %10s %10s\n",
           "j", "k", "atoms", "min_gap",
           "entropy", "H/j", "deficit", "efficiency");
    printf("  %-4s %-4s %12s %12s %10s %10s %10s %10s\n",
           "----", "----", "------------", "------------",
           "----------", "----------", "----------", "----------");

    double t0 = omp_get_wtime();

    for (int j = 1; j <= jmax; j++) {
        /* Choose k values: balanced (k ≈ j·log2/log3), and a few others */
        int k_balanced = (int)round(j * log(2.0) / log(3.0));
        int k_vals[] = { 1, k_balanced / 2, k_balanced, k_balanced + 2, 2 * k_balanced };
        int n_kvals = 5;

        for (int ki = 0; ki < n_kvals; ki++) {
            int k = k_vals[ki];
            if (k < 1) continue;
            if (k > MAX_K_ATOMS && j > 16) continue;  /* skip huge cases */

            /* Check memory bound */
            uint64_t p2 = pow2(j);
            uint64_t p3 = pow3(k);
            if (p2 == 0 || p3 == 0) continue;
            uint64_t total = p2 + p3;
            if (total > 50000000ULL) continue;  /* 400 MB limit */

            AtomStats s = compute_atoms(j, k);
            if (s.n_atoms == 0) continue;

            /* De-duplicate: only print if this k hasn't been printed */
            int dup = 0;
            for (int prev = 0; prev < ki; prev++) {
                if (k_vals[prev] == k) { dup = 1; break; }
            }
            if (dup) continue;

            printf("  %-4d %-4d %12"PRIu64" %12"PRIu64" %10.4f %10.6f %10.4f %10.6f\n",
                   j, k, s.n_atoms, s.min_gap,
                   s.entropy, s.entropy / j,
                   s.entropy_deficit, s.entropy / s.max_entropy);

            fprintf(csv, "%d,%d,%"PRIu64",%.15e,%.15e,%.15e,%.8f,"
                         "%.10f,%.10f,%.10f,%.8f,%.10f,%.10f,"
                         "%"PRIu64",%.2f\n",
                    j, k, s.n_atoms, s.min_width, s.max_width, s.mean_width,
                    s.min_width_ratio,
                    s.entropy, s.max_entropy, s.entropy_deficit,
                    s.entropy / s.max_entropy,
                    s.entropy / j, s.entropy / k,
                    s.min_gap, s.baker_ratio);
        }
    }

    double elapsed = omp_get_wtime() - t0;
    fclose(csv);
    printf("\n  Sweep completed in %.2f s.  Written to %s\n", elapsed, ENTROPY_CSV);
}

/* ═══════════════════════════════════════════════════════════════════
 * Multiplicative orders: ord_{2^j}(3) and ord_{3^k}(2)
 *
 * Known theory:
 *   ord_{2^j}(3) = 2^{j-2} for j ≥ 3  (index = 2 always)
 *   ord_{3^k}(2) = φ(3^k) = 2·3^{k-1}  (2 is primitive root mod 3^k)
 *
 * We verify these empirically up to large j,k.
 * ═══════════════════════════════════════════════════════════════════ */

static uint64_t compute_order(uint64_t base, uint64_t mod) {
    /* Brute-force for small mod, or use Euler totient factorization */
    uint64_t phi = mod;
    uint64_t temp = mod;

    /* Compute φ(mod) for mod = 2^j or 3^k */
    if (temp % 2 == 0) { phi -= phi / 2; while (temp % 2 == 0) temp /= 2; }
    if (temp % 3 == 0) { phi -= phi / 3; while (temp % 3 == 0) temp /= 3; }
    /* mod is 2^j or 3^k, so only one prime factor */

    /* ord | φ(mod).  Try all divisors of φ by dividing out prime factors. */
    uint64_t ord = phi;

    /* Factor phi */
    uint64_t pfactors[64];
    int npf = 0;
    uint64_t tmp = phi;
    for (uint64_t d = 2; d * d <= tmp; d++) {
        if (tmp % d == 0) {
            pfactors[npf++] = d;
            while (tmp % d == 0) tmp /= d;
        }
    }
    if (tmp > 1) pfactors[npf++] = tmp;

    /* Divide out each prime factor while order is maintained */
    for (int i = 0; i < npf; i++) {
        while (ord % pfactors[i] == 0 && powmod(base, ord / pfactors[i], mod) == 1)
            ord /= pfactors[i];
    }

    return ord;
}

static void run_orders(int jmax) {
    printf("\n=== Multiplicative Orders ===\n\n");

    FILE *csv = fopen(ORDERS_CSV, "w");
    if (!csv) { perror(ORDERS_CSV); return; }
    fprintf(csv, "type,exponent,modulus,phi,order,index,predicted_order,match\n");

    /* Part 1: ord_{2^j}(3) */
    printf("  ord_{2^j}(3):  predicted = 2^{j-2} for j ≥ 3\n\n");
    printf("  %-6s %20s %20s %20s %6s %8s\n",
           "j", "2^j", "ord_{2^j}(3)", "predicted", "index", "match");
    printf("  %-6s %20s %20s %20s %6s %8s\n",
           "------", "--------------------", "--------------------",
           "--------------------", "------", "--------");

    for (int j = 1; j <= jmax && j < 63; j++) {
        uint64_t mod = 1ULL << j;
        uint64_t phi_mod = mod / 2;  /* φ(2^j) = 2^{j-1} */
        uint64_t ord = compute_order(3, mod);
        uint64_t predicted = (j >= 3) ? (1ULL << (j - 2)) : (j == 2 ? 2 : 1);
        uint64_t idx = phi_mod / ord;
        int match = (ord == predicted);

        printf("  %-6d %20"PRIu64" %20"PRIu64" %20"PRIu64" %6"PRIu64" %8s\n",
               j, mod, ord, predicted, idx, match ? "YES" : "NO");

        fprintf(csv, "2^j,%d,%"PRIu64",%"PRIu64",%"PRIu64",%"PRIu64",%"PRIu64",%d\n",
                j, mod, phi_mod, ord, idx, predicted, match);
    }

    /* Part 2: ord_{3^k}(2) */
    printf("\n  ord_{3^k}(2):  predicted = 2·3^{k-1} = φ(3^k)  (primitive root)\n\n");
    printf("  %-6s %20s %20s %20s %6s %8s\n",
           "k", "3^k", "ord_{3^k}(2)", "predicted", "index", "match");
    printf("  %-6s %20s %20s %20s %6s %8s\n",
           "------", "--------------------", "--------------------",
           "--------------------", "------", "--------");

    for (int k = 1; k <= jmax; k++) {
        uint64_t mod = pow3(k);
        if (mod == 0) break;
        uint64_t phi_mod = mod - mod / 3;  /* φ(3^k) = 3^k - 3^{k-1} = 2·3^{k-1} */
        uint64_t ord = compute_order(2, mod);
        uint64_t predicted = phi_mod;  /* 2 is primitive root mod 3^k */
        uint64_t idx = phi_mod / ord;
        int match = (ord == predicted);

        printf("  %-6d %20"PRIu64" %20"PRIu64" %20"PRIu64" %6"PRIu64" %8s\n",
               k, mod, ord, predicted, idx, match ? "YES" : "NO");

        fprintf(csv, "3^k,%d,%"PRIu64",%"PRIu64",%"PRIu64",%"PRIu64",%"PRIu64",%d\n",
                k, mod, phi_mod, ord, idx, predicted, match);
    }

    /* Part 3: Asymmetry table — the key observation for entropy bridge */
    printf("\n  === Asymmetry: index comparison ===\n\n");
    printf("  The 2-adic side always has index 2 (3 is NOT a primitive root mod 2^j).\n");
    printf("  The 3-adic side always has index 1 (2 IS a primitive root mod 3^k).\n");
    printf("  This asymmetry is the structural basis for the entropy bridge:\n");
    printf("  T_3 acts with full freedom on the 3-adic partition, but T_2 leaves\n");
    printf("  a coset of size 2 invariant on the 2-adic partition.\n\n");

    printf("  Balanced scales (j ≈ k · log₂3):\n");
    printf("  %-6s %-6s %12s %12s %8s %8s\n",
           "j", "k", "ord_2j(3)", "ord_3k(2)", "idx_2", "idx_3");

    for (int k = 1; k <= jmax && k < 40; k++) {
        int j = (int)round(k * LOG2_3);
        if (j >= 63) break;

        uint64_t mod2 = 1ULL << j;
        uint64_t mod3 = pow3(k);
        if (mod3 == 0) break;

        uint64_t ord2 = compute_order(3, mod2);
        uint64_t ord3 = compute_order(2, mod3);
        uint64_t phi2 = mod2 / 2;
        uint64_t phi3 = mod3 - mod3 / 3;

        printf("  %-6d %-6d %12"PRIu64" %12"PRIu64" %8"PRIu64" %8"PRIu64"\n",
               j, k, ord2, ord3, phi2 / ord2, phi3 / ord3);
    }

    fclose(csv);
    printf("\n  Written to %s\n", ORDERS_CSV);
}

/* ═══════════════════════════════════════════════════════════════════
 * Detailed gap distribution for a single (j,k) pair
 *
 * Classifies each gap as "2-2" (between two 2-adic boundaries),
 * "3-3" (between two 3-adic), or "2-3" / "3-2" (mixed).
 * The mixed gaps are where Baker's theorem operates.
 * ═══════════════════════════════════════════════════════════════════ */

static void run_gap_distribution(int j, int k) {
    printf("\n=== Gap Distribution: P_2^(%d) ∨ P_3^(%d) ===\n\n", j, k);

    uint64_t p2 = pow2(j);
    uint64_t p3 = pow3(k);
    if (p2 == 0 || p3 == 0) { printf("  Overflow.\n"); return; }
    if (p2 > UINT64_MAX / p3) { printf("  D overflow.\n"); return; }
    uint64_t D = p2 * p3;
    uint64_t total_pts = p2 + p3 - 1;

    if (total_pts > 50000000ULL) {
        printf("  Too many points (%"PRIu64").  Use j ≤ %d, k ≤ %d.\n",
               total_pts, MAX_J_ATOMS, MAX_K_ATOMS);
        return;
    }

    /* Allocate points with type tags: 0 = 2-adic, 1 = 3-adic */
    TaggedPt *pts = malloc(total_pts * sizeof(TaggedPt));
    if (!pts) { fprintf(stderr, "OOM\n"); return; }

    uint64_t idx = 0;
    for (uint64_t m = 0; m < p2; m++) {
        pts[idx].val = m * p3;
        pts[idx].type = 0;
        idx++;
    }
    for (uint64_t m = 1; m < p3; m++) {
        pts[idx].val = m * p2;
        pts[idx].type = 1;
        idx++;
    }

    /* Sort by value */
    qsort(pts, total_pts, sizeof(TaggedPt), cmp_tagged);

    /* Classify gaps */
    uint64_t n_22 = 0, n_33 = 0, n_23 = 0;
    uint64_t min_mixed = UINT64_MAX, max_mixed = 0;
    uint64_t sum_mixed = 0;

    for (uint64_t i = 0; i < total_pts; i++) {
        uint64_t nv = (i + 1 < total_pts) ? pts[i + 1].val : D;
        uint8_t nt = (i + 1 < total_pts) ? pts[i + 1].type : pts[0].type;
        uint64_t gap = nv - pts[i].val;

        if (pts[i].type == 0 && nt == 0) {
            n_22++;
        } else if (pts[i].type == 1 && nt == 1) {
            n_33++;
        } else {
            n_23++;
            if (gap < min_mixed) min_mixed = gap;
            if (gap > max_mixed) max_mixed = gap;
            sum_mixed += gap;
        }
    }

    printf("  Gap types:\n");
    printf("    2-adic → 2-adic:  %"PRIu64"  (width = 3^k = %"PRIu64")\n", n_22, p3);
    printf("    3-adic → 3-adic:  %"PRIu64"  (width = 2^j = %"PRIu64")\n", n_33, p2);
    printf("    Mixed (2↔3):      %"PRIu64"\n\n", n_23);

    printf("  Mixed gap statistics (in integer units of 1/D):\n");
    printf("    Minimum: %"PRIu64"  (= %.6e of circle)\n", min_mixed, (double)min_mixed / (double)D);
    printf("    Maximum: %"PRIu64"  (= %.6e of circle)\n", max_mixed, (double)max_mixed / (double)D);
    if (n_23 > 0)
        printf("    Mean:    %.1f  (= %.6e of circle)\n",
               (double)sum_mixed / n_23, (double)sum_mixed / n_23 / (double)D);

    printf("\n  Interpretation:\n");
    printf("    Pure 2-adic gaps: always exactly 3^k = %"PRIu64" (uniform)\n", p3);
    printf("    Pure 3-adic gaps: always exactly 2^j = %"PRIu64" (uniform)\n", p2);
    printf("    Mixed gaps: minimum = %"PRIu64" ≥ 1 (Baker/coprimality floor)\n", min_mixed);
    printf("    The mixed gaps are where atoms of P_2^(j) are split by P_3^(k).\n");
    printf("    Baker ensures no mixed gap is ever 0, preventing pathological thinning.\n");

    free(pts);
}

/* ═══════════════════════════════════════════════════════════════════
 * Entropy growth rate analysis
 *
 * For balanced scales k(j) = round(j · log2/log3), compute
 * H(P_2^(j) ∨ P_3^(k(j))) / j as j increases.
 * This should converge to log 2 for Lebesgue measure.
 * ═══════════════════════════════════════════════════════════════════ */

static void run_entropy_rate(int jmax) {
    printf("\n=== Entropy Growth Rate (balanced scales) ===\n\n");
    printf("  For k(j) = round(j · log2/log3), compute H/j.\n");
    printf("  Lebesgue prediction: H/j → log 2 = %.6f\n\n", log(2.0));

    printf("  %-6s %-6s %12s %12s %10s %10s %10s\n",
           "j", "k(j)", "atoms", "H", "H/j", "deficit", "eff");
    printf("  %-6s %-6s %12s %12s %10s %10s %10s\n",
           "------", "------", "------------", "------------",
           "----------", "----------", "----------");

    FILE *csv = fopen(ATOMS_CSV, "w");
    if (csv) {
        fprintf(csv, "j,k,n_atoms,entropy,H_over_j,entropy_deficit,"
                     "efficiency,min_gap,min_mean_ratio\n");
    }

    for (int j = 2; j <= jmax; j++) {
        int k = (int)round(j * log(2.0) / log(3.0));
        if (k < 1) k = 1;

        uint64_t p2 = pow2(j);
        uint64_t p3 = pow3(k);
        if (p2 == 0 || p3 == 0) break;
        if (p2 + p3 > 50000000ULL) break;  /* memory limit */

        AtomStats s = compute_atoms(j, k);
        if (s.n_atoms == 0) continue;

        printf("  %-6d %-6d %12"PRIu64" %12.4f %10.6f %10.4f %10.6f\n",
               j, k, s.n_atoms, s.entropy, s.entropy / j,
               s.entropy_deficit, s.entropy / s.max_entropy);

        if (csv) {
            fprintf(csv, "%d,%d,%"PRIu64",%.10f,%.10f,%.10f,%.8f,%"PRIu64",%.8f\n",
                    j, k, s.n_atoms, s.entropy, s.entropy / j,
                    s.entropy_deficit, s.entropy / s.max_entropy,
                    s.min_gap, s.min_width_ratio);
        }
    }

    if (csv) {
        fclose(csv);
        printf("\n  Written to %s\n", ATOMS_CSV);
    }
}

/* ═══════════════════════════════════════════════════════════════════
 * Main
 * ═══════════════════════════════════════════════════════════════════ */

int main(int argc, char **argv) {
    int do_atoms = 0, atom_j = 12, atom_k = 8;
    int do_sweep = 0, sweep_jmax = 20;
    int do_orders = 0, orders_jmax = 40;
    int do_rate = 0;
    int do_gaps = 0;
    int do_all = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--atoms") == 0) {
            do_atoms = 1;
            if (i + 2 < argc) {
                atom_j = atoi(argv[i + 1]);
                atom_k = atoi(argv[i + 2]);
                i += 2;
            }
        } else if (strcmp(argv[i], "--sweep") == 0) {
            do_sweep = 1;
            if (i + 1 < argc && argv[i + 1][0] != '-') {
                sweep_jmax = atoi(argv[++i]);
            }
        } else if (strcmp(argv[i], "--orders") == 0) {
            do_orders = 1;
            if (i + 1 < argc && argv[i + 1][0] != '-') {
                orders_jmax = atoi(argv[++i]);
            }
        } else if (strcmp(argv[i], "--rate") == 0) {
            do_rate = 1;
            if (i + 1 < argc && argv[i + 1][0] != '-') {
                sweep_jmax = atoi(argv[++i]);
            }
        } else if (strcmp(argv[i], "--gaps") == 0) {
            do_gaps = 1;
            if (i + 2 < argc) {
                atom_j = atoi(argv[i + 1]);
                atom_k = atoi(argv[i + 2]);
                i += 2;
            }
        } else if (strcmp(argv[i], "--all") == 0) {
            do_all = 1;
        }
    }

    if (!do_atoms && !do_sweep && !do_orders && !do_rate && !do_gaps && !do_all) {
        do_all = 1;
    }

    printf("╔══════════════════════════════════════════════════════════════╗\n");
    printf("║  Furstenberg ×2, ×3 — Phase 2: Entropy Bridge             ║\n");
    printf("╚══════════════════════════════════════════════════════════════╝\n");
    printf("  %d threads available\n", omp_get_max_threads());

    if (do_all || do_orders)
        run_orders(do_all ? 40 : orders_jmax);

    if (do_all || do_rate)
        run_entropy_rate(do_all ? 24 : sweep_jmax);

    if (do_all || do_atoms)
        run_atom_analysis(atom_j, atom_k);

    if (do_all || do_gaps)
        run_gap_distribution(atom_j, atom_k);

    if (do_all || do_sweep)
        run_entropy_sweep(do_all ? 20 : sweep_jmax);

    printf("\nDone.\n");
    return 0;
}
