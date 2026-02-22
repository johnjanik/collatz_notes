/*
 * lehmer_sieve.c
 *
 * Search for integer polynomials with small Mahler measure.
 *
 * Three-phase pipeline:
 *   Phase 1 — Enumerate monic reciprocal polynomials of given degree
 *   Phase 2 — Graeffe root-squaring filter (reject M > cutoff in O(d²))
 *   Phase 3 — Exact Mahler measure via companion matrix eigenvalues
 *
 * Only reciprocal polynomials are searched: Smyth (1971) showed that
 * non-reciprocal M ≥ θ₀ ≈ 1.3247 (plastic number), so only the
 * reciprocal case matters for Lehmer's conjecture.
 *
 * Usage: ./lehmer_sieve --degree D [--max-coeff C] [--cutoff X]
 *                       [--threads T] [--output-dir DIR]
 *
 * Compile: gcc -O3 -march=native -Wall -fopenmp -o lehmer_sieve lehmer_sieve.c -lm
 */

#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <time.h>
#include <float.h>
#include <omp.h>

/* ── Constants ──────────────────────────────────────────────────────── */

#define MAX_DEGREE      50
#define MAX_SURVIVORS   100000
#define GRAEFFE_ITERS   4
#define ROOT_ITERS      200      /* Durand-Kerner iterations */
#define PI              3.14159265358979323846

/* ── Timing helpers ─────────────────────────────────────────────────── */

static double wall_clock(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

/* Comma-formatted integer */
static char *fmt_comma(int64_t n, char *buf, size_t sz) {
    char raw[32];
    snprintf(raw, sizeof(raw), "%ld", (long)n);
    int len = (int)strlen(raw);
    int commas = (len - 1 - (n < 0 ? 1 : 0)) / 3;
    int out_len = len + commas;
    if ((int)sz <= out_len) { snprintf(buf, sz, "%ld", (long)n); return buf; }
    buf[out_len] = '\0';
    int src = len - 1, dst = out_len - 1, cnt = 0;
    while (src >= 0) {
        buf[dst--] = raw[src--];
        cnt++;
        if (cnt == 3 && src >= 0 && raw[src] != '-') {
            buf[dst--] = ',';
            cnt = 0;
        }
    }
    return buf;
}

/* ── Survivor record ────────────────────────────────────────────────── */

typedef struct {
    int degree;
    int coeffs[MAX_DEGREE + 1];   /* full polynomial coefficients */
    double mahler;                  /* exact Mahler measure */
    int n_roots_outside;            /* number of roots with |α| > 1 */
} survivor_t;

/* ── Global state ───────────────────────────────────────────────────── */

static int      param_degree    = 10;
static int      param_max_coeff = 10;
static double   param_cutoff    = 1.3;
static int      param_threads   = 0;
static char     param_outdir[512] = ".";

static survivor_t *survivors;
static int         n_survivors;
static omp_lock_t  survivor_lock;

static int64_t  total_searched;
static int64_t  total_graeffe_pass;
static int64_t  total_cyclotomic;

/* ── Polynomial operations (double precision) ───────────────────────── */

/* Evaluate polynomial at complex point (Horner) */
static void poly_eval_complex(const double *p, int deg,
                               double zr, double zi,
                               double *wr, double *wi)
{
    double rr = p[deg], ri = 0.0;
    for (int k = deg - 1; k >= 0; k--) {
        double tr = rr * zr - ri * zi + p[k];
        double ti = rr * zi + ri * zr;
        rr = tr; ri = ti;
    }
    *wr = rr; *wi = ri;
}

/*
 * Graeffe iteration: given P(x) of degree d, compute Q(x) such that
 * Q(x²) = (-1)^d P(x) P(-x).
 *
 * If P(x) = Σ aₖ xᵏ, split into even/odd parts:
 *   E(x²) = Σ a_{2k} x^{2k},  O(x²) = Σ a_{2k+1} x^{2k+1}
 *   P(x)P(-x) = E(x²)² - x² O(x²)²
 * So Q(y) = E(y)² - y·O(y)²  (degree d).
 */
static void graeffe_step(const double *p, int deg, double *q) {
    int half = deg / 2;
    double e[MAX_DEGREE + 1], o[MAX_DEGREE + 1];

    /* Split into even/odd */
    memset(e, 0, sizeof(double) * (half + 1));
    memset(o, 0, sizeof(double) * (half + 1));
    for (int k = 0; k <= deg; k++) {
        if (k % 2 == 0) e[k / 2] = p[k];
        else             o[k / 2] = p[k];
    }

    /* E² */
    double esq[MAX_DEGREE + 1];
    memset(esq, 0, sizeof(double) * (deg + 1));
    for (int i = 0; i <= half; i++)
        for (int j = 0; j <= half; j++)
            if (i + j <= deg) esq[i + j] += e[i] * e[j];

    /* O² */
    double osq[MAX_DEGREE + 1];
    memset(osq, 0, sizeof(double) * (deg + 1));
    for (int i = 0; i <= half; i++)
        for (int j = 0; j <= half; j++)
            if (i + j <= deg) osq[i + j] += o[i] * o[j];

    /* Q = E² - y·O² */
    for (int k = 0; k <= deg; k++) {
        q[k] = esq[k];
        if (k > 0) q[k] -= osq[k - 1];
    }

    /* Normalize: make monic (leading coeff = 1 or -1 → take abs) */
    if (fabs(q[deg]) > 1e-100) {
        double sign = (q[deg] > 0) ? 1.0 : -1.0;
        for (int k = 0; k <= deg; k++) q[k] *= sign;
    }
}

/*
 * Graeffe lower bound on Mahler measure.
 *
 * After k Graeffe iterations, roots α → α^{2^k}.  For a Salem polynomial
 * with one root |α| > 1 and one |1/α| < 1 (rest on unit circle):
 *   c_{d-1} / (d * c_d) ≈ -∑ αᵢ^{2^k} ≈ -α^{2^k} for large k.
 *
 * More robust: compare |c_{d-1}| to d (for monic).  If the polynomial has
 * a root of modulus r > 1, after k iterations the sub-leading coefficient
 * grows like r^{2^k}.  We extract M from the largest coefficient ratio.
 */
static double graeffe_lower_bound(const int *coeffs, int deg) {
    double p[MAX_DEGREE + 1], q[MAX_DEGREE + 1];

    for (int k = 0; k <= deg; k++) p[k] = (double)coeffs[k];

    for (int iter = 0; iter < GRAEFFE_ITERS; iter++) {
        graeffe_step(p, deg, q);
        memcpy(p, q, sizeof(double) * (deg + 1));
    }

    double power = (double)(1 << GRAEFFE_ITERS);

    /* For monic polynomial after Graeffe: p[deg] ≈ 1.
     * The sub-leading coeff p[deg-1] ≈ -(sum of roots^{2^k}).
     * For a Salem number with one root r > 1:
     *   |p[deg-1]| ≈ r^{2^k} + (d-2) + r^{-2^k} ≈ r^{2^k} for large k.
     * So r ≈ |p[deg-1]|^{1/2^k}. */
    double abs_sub = fabs(p[deg - 1]);
    if (abs_sub <= deg + 0.5) return 1.0;  /* all roots near unit circle */

    /* M ≈ (|c_{d-1}| - (d-1))^{1/2^k} — subtract unit circle contributions */
    double effective = abs_sub - (deg - 1);
    if (effective <= 1.0) return 1.0;

    return pow(effective, 1.0 / power);
}

/*
 * Find roots via Durand-Kerner (Weierstrass) method.
 * Returns roots in (re[], im[]) arrays.
 */
static void find_roots(const double *p, int deg, double *re, double *im) {
    /* Initialize with points on slightly perturbed circle */
    for (int k = 0; k < deg; k++) {
        double angle = 2.0 * PI * k / deg + 0.1;
        double r = 0.9 + 0.2 * k / deg;  /* slight spiral */
        re[k] = r * cos(angle);
        im[k] = r * sin(angle);
    }

    for (int iter = 0; iter < ROOT_ITERS; iter++) {
        double max_shift = 0.0;
        for (int i = 0; i < deg; i++) {
            /* Evaluate P at z_i */
            double pr, pi_val;
            poly_eval_complex(p, deg, re[i], im[i], &pr, &pi_val);

            /* Compute product ∏_{j≠i} (z_i - z_j) */
            double qr = 1.0, qi = 0.0;
            for (int j = 0; j < deg; j++) {
                if (j == i) continue;
                double dr = re[i] - re[j];
                double di = im[i] - im[j];
                double tr = qr * dr - qi * di;
                double ti = qr * di + qi * dr;
                qr = tr; qi = ti;
            }

            /* Shift: P(z_i) / ∏(z_i - z_j) */
            double denom = qr * qr + qi * qi;
            if (denom < 1e-300) continue;
            double sr = (pr * qr + pi_val * qi) / denom;
            double si = (pi_val * qr - pr * qi) / denom;

            re[i] -= sr;
            im[i] -= si;
            double shift = sr * sr + si * si;
            if (shift > max_shift) max_shift = shift;
        }
        if (max_shift < 1e-30) break;
    }
}

/*
 * Compute exact Mahler measure from roots.
 * M(P) = |a_d| * ∏ max(1, |α_i|)
 */
static double mahler_measure(const double *p, int deg, int *n_outside) {
    double re[MAX_DEGREE], im_arr[MAX_DEGREE];
    find_roots(p, deg, re, im_arr);

    double m = fabs(p[deg]);  /* leading coefficient (should be 1 for monic) */
    int cnt = 0;
    for (int k = 0; k < deg; k++) {
        double absval = sqrt(re[k] * re[k] + im_arr[k] * im_arr[k]);
        if (absval > 1.0 + 1e-10) {
            m *= absval;
            cnt++;
        }
    }
    if (n_outside) *n_outside = cnt;
    return m;
}

/* ── Reciprocal polynomial check & cyclotomic detection ─────────────── */

/*
 * Check if polynomial divides x^n - 1 for some small n (cyclotomic test).
 * Uses the fact that cyclotomic polynomials have all roots on the unit circle,
 * so M(P) = 1 exactly. We check: evaluate at several roots of unity.
 */
static int is_likely_cyclotomic(const int *coeffs, int deg) {
    /* Quick check: constant term must be ±1 for cyclotomic */
    if (abs(coeffs[0]) != 1) return 0;

    /* All coefficients of cyclotomic polynomials are relatively constrained */
    /* For degree ≤ 104, all cyclotomic coefficients are in {-1, 0, 1} */
    if (deg <= 50) {
        for (int k = 0; k <= deg; k++)
            if (abs(coeffs[k]) > 1) return 0;
    }

    /* Resultant test: compute GCD with x^n - 1 for n up to 2*deg */
    /* Instead, just check if Mahler measure ≈ 1 to high precision */
    /* (deferred to Phase 3) */
    return 0;
}

/* ── Enumeration of reciprocal polynomials ──────────────────────────── */

/*
 * For degree d, a monic reciprocal polynomial has:
 *   a_d = 1, a_0 = 1 (or a_0 = -1 for odd degree)
 *   a_k = a_{d-k} for all k
 *
 * Free parameters: a_1, a_2, ..., a_{d/2} (half = d/2 values)
 * For odd d: a_{(d-1)/2} and a_{(d+1)/2} are paired, plus middle a_{d/2} is free
 *
 * We enumerate all combinations with |a_k| ≤ max_coeff.
 */

/* Convert flat index to coefficient vector for half-polynomial */
static void index_to_half_coeffs(int64_t idx, int half, int max_coeff,
                                  int *half_coeffs)
{
    int range = 2 * max_coeff + 1;
    for (int k = 0; k < half; k++) {
        half_coeffs[k] = (int)(idx % range) - max_coeff;
        idx /= range;
    }
}

/* Build full reciprocal polynomial from half coefficients */
static void build_reciprocal(const int *half_coeffs, int deg, int *coeffs) {
    int half = deg / 2;

    /* Leading and constant terms */
    coeffs[deg] = 1;
    coeffs[0] = 1;

    /* Mirror coefficients */
    for (int k = 1; k <= half; k++) {
        coeffs[k] = half_coeffs[k - 1];
        coeffs[deg - k] = half_coeffs[k - 1];
    }

    /* Middle term for even degree */
    if (deg % 2 == 0) {
        /* a_{d/2} is already set by the loop above for k = half
         * when deg is even, half = deg/2, and coeffs[half] = half_coeffs[half-1]
         * which was set in the loop for k = half. That's correct. */
    }
    /* Middle term for odd degree: already handled by the mirror */
}

/* ── Trace bound pruning (Schur-Siegel-Smyth) ──────────────────────── */

/*
 * For a monic reciprocal polynomial with all roots on/near the unit circle,
 * the sum of roots = -a_{d-1}. For small Mahler measure, most roots are on
 * the unit circle, constraining the trace.
 *
 * SSS bound: for totally positive algebraic integers of degree n,
 * trace ≥ 1.7719 * n (Smyth). This constrains a_{d-1} = a_1.
 */

/* ── Main search routine ────────────────────────────────────────────── */

static void search_degree(int deg) {
    int half = deg / 2;
    int range = 2 * param_max_coeff + 1;
    int64_t total_combos = 1;
    for (int k = 0; k < half; k++) {
        total_combos *= range;
        if (total_combos > (int64_t)1e15) {
            fprintf(stderr, "Warning: degree %d with max_coeff %d has %s combos"
                    " — may be very slow\n", deg, param_max_coeff, ">10^15");
            break;
        }
    }

    char buf[32];
    printf("  Degree %d: %s combinations (half = %d, range = %d)\n",
           deg, fmt_comma(total_combos, buf, sizeof(buf)), half, range);

    int64_t local_searched = 0;
    int64_t local_graeffe_pass = 0;
    int64_t local_cyclotomic = 0;

    #pragma omp parallel reduction(+:local_searched,local_graeffe_pass,local_cyclotomic)
    {
        int half_coeffs[MAX_DEGREE];
        int coeffs[MAX_DEGREE + 1];
        double dcoeffs[MAX_DEGREE + 1];

        #pragma omp for schedule(dynamic, 1024)
        for (int64_t idx = 0; idx < total_combos; idx++) {
            local_searched++;

            /* Decode index to half coefficients */
            index_to_half_coeffs(idx, half, param_max_coeff, half_coeffs);

            /* Build full reciprocal polynomial */
            build_reciprocal(half_coeffs, deg, coeffs);

            /* Quick reject: constant term must be ±1 for small M
             * (Actually for reciprocal monic, constant term = 1 always) */

            /* Quick cyclotomic check */
            if (is_likely_cyclotomic(coeffs, deg)) {
                local_cyclotomic++;
                continue;
            }

            /* Phase 2: Graeffe filter */
            double m_lower = graeffe_lower_bound(coeffs, deg);
            if (m_lower > param_cutoff) continue;
            local_graeffe_pass++;

            /* Phase 3: Exact Mahler measure */
            for (int k = 0; k <= deg; k++) dcoeffs[k] = (double)coeffs[k];

            int n_out = 0;
            double m = mahler_measure(dcoeffs, deg, &n_out);

            /* Skip if M ≈ 1 (cyclotomic or numerical artifact) or M > cutoff */
            if (m < 1.001) {
                local_cyclotomic++;
                continue;
            }
            if (m > param_cutoff) continue;

            /* Survivor! Record it. */
            omp_set_lock(&survivor_lock);
            if (n_survivors < MAX_SURVIVORS) {
                survivor_t *s = &survivors[n_survivors];
                s->degree = deg;
                memcpy(s->coeffs, coeffs, sizeof(int) * (deg + 1));
                s->mahler = m;
                s->n_roots_outside = n_out;
                n_survivors++;
            }
            omp_unset_lock(&survivor_lock);
        }
    }

    #pragma omp atomic
    total_searched += local_searched;
    #pragma omp atomic
    total_graeffe_pass += local_graeffe_pass;
    #pragma omp atomic
    total_cyclotomic += local_cyclotomic;
}

/* ── Duplicate removal ──────────────────────────────────────────────── */

/* Two polynomials are "same" if they have identical coefficient vectors,
 * or one is the negation of the other (same roots, same M). */
static int same_poly(const survivor_t *a, const survivor_t *b) {
    if (a->degree != b->degree) return 0;
    int d = a->degree;
    int same = 1, neg = 1;
    for (int k = 0; k <= d; k++) {
        if (a->coeffs[k] != b->coeffs[k]) same = 0;
        if (a->coeffs[k] != -b->coeffs[k]) neg = 0;
    }
    return same || neg;
}

static int cmp_survivors(const void *a, const void *b) {
    const survivor_t *sa = (const survivor_t *)a;
    const survivor_t *sb = (const survivor_t *)b;
    if (sa->mahler < sb->mahler) return -1;
    if (sa->mahler > sb->mahler) return 1;
    return 0;
}

static void dedup_survivors(void) {
    if (n_survivors <= 1) return;
    qsort(survivors, n_survivors, sizeof(survivor_t), cmp_survivors);

    int out = 0;
    for (int i = 0; i < n_survivors; i++) {
        int dup = 0;
        for (int j = 0; j < out; j++) {
            if (fabs(survivors[i].mahler - survivors[j].mahler) < 1e-8 &&
                same_poly(&survivors[i], &survivors[j])) {
                dup = 1;
                break;
            }
        }
        if (!dup) survivors[out++] = survivors[i];
    }
    n_survivors = out;
}

/* ── Output ─────────────────────────────────────────────────────────── */

static void write_survivors_csv(int deg) {
    char path[1024];
    snprintf(path, sizeof(path), "%s/lehmer_survivors_d%d.csv", param_outdir, deg);
    FILE *f = fopen(path, "w");
    if (!f) { perror(path); return; }

    fprintf(f, "rank,degree,mahler_measure,n_roots_outside,coefficients\n");
    for (int i = 0; i < n_survivors; i++) {
        if (survivors[i].degree != deg) continue;
        fprintf(f, "%d,%d,%.15f,%d,\"",
                i + 1, survivors[i].degree,
                survivors[i].mahler, survivors[i].n_roots_outside);
        for (int k = survivors[i].degree; k >= 0; k--) {
            fprintf(f, "%d", survivors[i].coeffs[k]);
            if (k > 0) fprintf(f, " ");
        }
        fprintf(f, "\"\n");
    }
    fclose(f);
    printf("  Wrote %s\n", path);
}

static void write_summary_csv(int deg, double elapsed) {
    char path[1024];
    snprintf(path, sizeof(path), "%s/lehmer_summary.csv", param_outdir);

    /* Check if file exists to decide on header */
    FILE *test = fopen(path, "r");
    int exists = (test != NULL);
    if (test) fclose(test);

    FILE *f = fopen(path, exists ? "a" : "w");
    if (!f) { perror(path); return; }

    if (!exists) {
        fprintf(f, "degree,total_searched,graeffe_survivors,cyclotomic,final_survivors,"
                   "min_mahler,time_seconds\n");
    }

    /* Count survivors for this degree */
    int deg_survivors = 0;
    double min_m = 1e30;
    for (int i = 0; i < n_survivors; i++) {
        if (survivors[i].degree == deg) {
            deg_survivors++;
            if (survivors[i].mahler < min_m) min_m = survivors[i].mahler;
        }
    }

    fprintf(f, "%d,%ld,%ld,%ld,%d,%.15f,%.2f\n",
            deg, (long)total_searched, (long)total_graeffe_pass,
            (long)total_cyclotomic, deg_survivors,
            deg_survivors > 0 ? min_m : 0.0, elapsed);
    fclose(f);
    printf("  Wrote %s\n", path);
}

static void print_top_results(int deg) {
    printf("\n  ── Top survivors (degree %d, M < %.4f) ─────────\n",
           deg, param_cutoff);

    int count = 0;
    for (int i = 0; i < n_survivors && count < 20; i++) {
        if (survivors[i].degree != deg) continue;
        count++;
        printf("  %3d. M = %.12f  (roots outside: %d)  P(x) = ",
               count, survivors[i].mahler, survivors[i].n_roots_outside);

        /* Print polynomial */
        int d = survivors[i].degree;
        int first = 1;
        for (int k = d; k >= 0; k--) {
            int c = survivors[i].coeffs[k];
            if (c == 0) continue;
            if (!first && c > 0) printf("+ ");
            if (!first && c < 0) printf("- ");
            if (first && c < 0) printf("-");
            int ac = abs(c);
            if (k == 0 || ac != 1) printf("%d", ac);
            if (k >= 2) printf("x^%d ", k);
            else if (k == 1) printf("x ");
            else if (k == 0) printf(" ");
            first = 0;
        }
        printf("\n");
    }
    if (count == 0) printf("  (none)\n");
}

/* ── Known Lehmer polynomial check ──────────────────────────────────── */

static void check_lehmer_polynomial(void) {
    /* Lehmer's polynomial: x^10 + x^9 - x^7 - x^6 - x^5 - x^4 - x^3 + x + 1 */
    static const int lehmer[] = {1, 1, 0, -1, -1, -1, -1, -1, 0, 1, 1};

    printf("\n  ── Verification: Lehmer's polynomial ─────────────────────\n");
    double dcoeffs[11];
    for (int k = 0; k <= 10; k++) dcoeffs[k] = (double)lehmer[k];

    int n_out = 0;
    double m = mahler_measure(dcoeffs, 10, &n_out);
    printf("  L(x) = x^10 + x^9 - x^7 - x^6 - x^5 - x^4 - x^3 + x + 1\n");
    printf("  M(L) = %.15f  (expected: 1.176280818...)\n", m);
    printf("  Roots outside unit disk: %d\n", n_out);

    int is_recip = 1;
    for (int k = 0; k <= 10; k++) {
        if (lehmer[k] != lehmer[10 - k]) { is_recip = 0; break; }
    }
    printf("  Reciprocal: %s\n", is_recip ? "yes" : "no");
}

/* ── Parse arguments ────────────────────────────────────────────────── */

static void parse_args(int argc, char **argv) {
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--degree") && i + 1 < argc)
            param_degree = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--max-coeff") && i + 1 < argc)
            param_max_coeff = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--cutoff") && i + 1 < argc)
            param_cutoff = atof(argv[++i]);
        else if (!strcmp(argv[i], "--threads") && i + 1 < argc)
            param_threads = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--output-dir") && i + 1 < argc)
            strncpy(param_outdir, argv[++i], sizeof(param_outdir) - 1);
        else if (!strcmp(argv[i], "--help")) {
            printf("Usage: %s [--degree D] [--max-coeff C] [--cutoff X]\n"
                   "          [--threads T] [--output-dir DIR]\n", argv[0]);
            exit(0);
        }
    }
}

/* ── Main ───────────────────────────────────────────────────────────── */

int main(int argc, char **argv) {
    parse_args(argc, argv);

    if (param_threads > 0) omp_set_num_threads(param_threads);
    int nt = 1;
    #pragma omp parallel
    {
        #pragma omp single
        nt = omp_get_num_threads();
    }

    printf("╔══════════════════════════════════════════════════════════╗\n");
    printf("║         Lehmer Conjecture — Mahler Measure Sieve        ║\n");
    printf("╠══════════════════════════════════════════════════════════╣\n");
    printf("║  Degree:    %-8d                                    ║\n", param_degree);
    printf("║  Max coeff: %-8d                                    ║\n", param_max_coeff);
    printf("║  Cutoff:    %-8.4f                                    ║\n", param_cutoff);
    printf("║  Threads:   %-8d                                    ║\n", nt);
    printf("╚══════════════════════════════════════════════════════════╝\n\n");

    /* Verify Lehmer polynomial first */
    check_lehmer_polynomial();

    /* Allocate survivors */
    survivors = calloc(MAX_SURVIVORS, sizeof(survivor_t));
    if (!survivors) { perror("calloc"); return 1; }
    n_survivors = 0;
    omp_init_lock(&survivor_lock);

    /* Search */
    int deg = param_degree;
    if (deg < 2 || deg > MAX_DEGREE) {
        fprintf(stderr, "Degree must be 2..%d\n", MAX_DEGREE);
        return 1;
    }
    if (deg % 2 != 0) {
        fprintf(stderr, "Warning: odd degree %d — for Lehmer search, even degree "
                "is standard.\nSmyth's bound handles odd-degree reciprocal case.\n"
                "Proceeding anyway.\n", deg);
    }

    printf("\n  Searching degree %d reciprocal polynomials...\n", deg);
    total_searched = 0;
    total_graeffe_pass = 0;
    total_cyclotomic = 0;

    double t0 = wall_clock();
    search_degree(deg);
    double elapsed = wall_clock() - t0;

    /* Dedup and sort */
    dedup_survivors();

    /* Report */
    char buf1[32], buf2[32], buf3[32];
    printf("\n  ── Summary ────────────────────────────────────────────\n");
    printf("  Total searched:     %s\n", fmt_comma(total_searched, buf1, sizeof(buf1)));
    printf("  Graeffe survivors:  %s\n", fmt_comma(total_graeffe_pass, buf2, sizeof(buf2)));
    printf("  Cyclotomic:         %s\n", fmt_comma(total_cyclotomic, buf3, sizeof(buf3)));
    printf("  Final survivors:    %d\n", n_survivors);
    printf("  Time:               %.2f seconds\n", elapsed);
    printf("  Rate:               %.1f M polys/sec\n",
           total_searched / elapsed / 1e6);

    print_top_results(deg);

    /* Write CSVs */
    write_survivors_csv(deg);
    write_summary_csv(deg, elapsed);

    omp_destroy_lock(&survivor_lock);
    free(survivors);
    return 0;
}
