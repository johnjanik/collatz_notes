# Collatz Sieve Analysis Report

## Summary

We built a sieve generator (`gen_sieve.c`) and analyzer (`analyze_sieve.c`) based on
Barina's approach, adapted for branch_locus acceleration. Key findings:

| k (bits) | Class-dead % | Avg det. steps | Bare-iter speedup | Est. branch_locus |
|----------|-------------|---------------|-------------------|-------------------|
| 16       | 84.9%       | 24.5          | 1.21x (bench)     | ~1.3-1.5x         |
| 24       | 89.5%       | 36.5          | 1.21x (bench)     | ~1.4-1.6x         |
| 32       | 92.5%       | 48.5          | (not benchmarked) | ~1.5-1.8x         |

**Benchmarked** (`sieve_bench.c`): 1.21x speedup on bare Collatz iteration at N=1B with k=24.
Step counts verified exact (zero error). Steps skipped: 9.7% at trajectory start.

**For branch_locus** (27 grid levels per step), the per-step cost is ~50-100x higher than
bare iteration. The sieve replaces expensive grid-update steps with a single O(1) formula,
so the effective speedup is significantly larger.

**Recommendation**: Use k=24 (2MB bitmap, 192MB precomp table) for initial integration.
Mid-trajectory sieve application (applying sieve after each odd step during iteration) can
skip 19% of all steps but only pays off when per-step cost is high (branch_locus: yes).

**Critical finding**: Mid-trajectory sieve is 2% SLOWER for bare iteration (sieve lookup
costs more than the trivial 3x+1 steps it replaces) but should be ~30-40% faster for
branch_locus where each step involves 27 grid updates.

## Sieve Mechanism

### Class Analysis (the main insight)

For each odd residue r mod 2^k, the first a+k Collatz steps of ANY n ≡ r (mod 2^k) are
fully determined by r. Here a = number of odd steps, k = number of even steps (always
exactly k, since we "consume" one bit per even step).

After these determined steps, the value transforms as:
```
n_new = (3^a * n + B) >> k
```
where a and B depend only on r (precomputed per residue class).

The shrinkage factor is α = 3^a / 2^k:
- If α < 1 (i.e., a ≤ floor(k · log2/log3)), the trajectory is **guaranteed to decrease**.
  These are "class-dead" residues.
- If α ≥ 1, the trajectory may increase after the determined steps.

### Distribution of a (odd step count)

The distribution of a follows a **binomial-like pattern**: C(k-1, a-1) for each a,
peaking at a = k/2. This is because each bit position contributes either an odd step
(if the bit is 1 at the time it's consumed) or an even step (if 0).

The class-dead threshold is at a ≈ 0.63·k (= k·log2/log3). Since the average a ≈ k/2
and the distribution is concentrated, roughly 85-93% of residues are class-dead.

### Exact Analysis

For the small values r < 2^k themselves, we also check whether Collatz(r) drops below r.
Result: **99.997% of r drop below r for k=16, and 100.000% for k≥24.**

The one non-dropping residue at k=16 is r=65535 (2^16-1), whose trajectory grows before
eventually dropping. This is consistent: the highest residue has the most room to grow.

## Mod-9 Analysis

### Barina's dead set: {2, 4, 5, 8} mod 9

**Mod-3 component** ({2, 5, 8} ≡ 2 mod 3):
For n ≡ 2 mod 3, the Collatz step gives 3n+1 ≡ 1 mod 3, and subsequent steps tend to
produce extra even steps (higher v₂). The algebraic tracing in Barina's mod3-sieve
generator proves that these residue classes have α < 1 after a bounded number of steps,
regardless of the higher bits.

**Extra mod-9 kill** (4 mod 9):
n ≡ 4 mod 9 means n ≡ 1 mod 3 (NOT caught by mod-3). However, tracing the Collatz
iteration mod 9 reveals: 3(9m+4)+1 = 27m+13 ≡ 4 mod 9, so the residue mod 9 is
preserved through the odd step. The subsequent even steps cycle the value through dead
mod-3 classes, ensuring eventual decrease.

**Effectiveness for branch_locus**: Our data shows mod-9 class has **no differential effect**
on the 2^k class-dead rate (all mod-9 classes show ~85-92% class-dead, varying < 0.1%).
This is because the 2^k sieve already subsumes the mod-9 information for k ≥ 16.

### Conclusion on mod-9 for branch_locus

The mod-9 sieve is **unnecessary** if we use a 2^k sieve with k ≥ 16. The 2^k sieve
provides strictly more information. However, mod-9 is useful as a **zero-cost arithmetic
pre-filter** before the bitmap lookup, as Barina does.

## v₂=1 Danger Cross-Reference

Numbers with v₂(3n+1) = 1 (n ≡ 3 mod 4) are "dangerous" — minimal shrinkage per odd step.

| k  | v₂=1 class-dead | v₂≥2 class-dead | Delta  |
|----|-----------------|-----------------|--------|
| 16 | 78.8%           | 91.0%           | 12.2%  |
| 24 | 85.7%           | 93.3%           | 7.6%   |
| 32 | 90.2%           | 94.8%           | 4.6%   |

**v₂=1 residues are disproportionately "live"** (harder to prove shrinking), confirming the
connection between the Diophantine danger zones and sieve resistance.

### Hensel Attrition Pattern

For d consecutive v₂=1 steps (n ≡ -1 mod 2^(d+1)):

| d | Fraction | ClassDead% (k=24) | Avg a |
|---|----------|-------------------|-------|
| 1 | 50%      | 85.7%             | 13.0  |
| 2 | 25%      | 80.8%             | 13.5  |
| 3 | 12.5%    | 74.8%             | 14.0  |
| 4 | 6.25%    | 67.6%             | 14.5  |
| 5 | 3.125%   | 59.3%             | 15.0  |
| 6 | 1.5625%  | 50.0%             | 15.5  |
| 8 | 0.39%    | 30.4%             | 16.5  |

Each consecutive danger step adds exactly +0.5 to avg a, making class-death less likely.
At d=6 (for k=24), exactly 50% are class-dead — the crossover point.

## Branch_locus Integration Design

### Option A: Fast-Forward (recommended for next run)

Replace the first a+k Collatz steps per trajectory with a single arithmetic operation:
```c
// Precomputed per residue class r = n % (1 << K):
//   A_num[r], B_num[r] from sieve_kK_precomp.bin
uint64_t n_new = (A_num * (uint64_t)n + B_num) >> K;
```

**Cell grid updates** for the skipped steps: precompute per-residue cell increment arrays.
For each residue r, the parity sequence of the first a+k steps is known → the (ν₂, ν₃)
path is known → cell visits are predetermined. Store as batch increments per level.

**Memory cost** (k=24): 192MB precomp table + ~800MB cell increment tables (27 levels × 8M
residues × ~4 bytes each). Total ~1GB. Fits in RAM.

**Speed gain**: ~52% fewer inner-loop iterations. Accounting for the precomp lookup overhead
and cell batch updates, net speedup estimate: **25-40%**.

### Option B: Trajectory Sharing (more complex, higher payoff)

For class-dead residues (89.5% at k=24), after the fast-forward the value n_new < n.
If processing in ascending order, n_new was already processed, so its cell contributions
are already accumulated. We could avoid recomputing the remaining ~34 steps.

This requires storing trajectory cell contributions in a hash table or memoization structure,
which adds significant memory and complexity.

**Combined speedup**: theoretically ~95% of steps eliminated, but the memory and lookup
overhead may reduce this to ~60-70% net.

### Option C: Sieve-Only Filtering (simplest)

For a quick win: just skip class-dead numbers entirely (don't process them). This loses
their cell contributions but could be acceptable if we're sampling.

**NOT recommended** for branch_locus since we need all cell statistics.

## Practical Recommendation for the Next 100B+ Run

1. **Use k=24 sieve** with Option A (fast-forward).
2. Precompute the sieve at startup (~0.07 seconds).
3. For each n, look up residue class and apply fast-forward formula.
4. Pre-accumulate cell contributions for the determined steps.
5. Continue Collatz iteration from n_new for the remaining steps.
6. **Expected runtime reduction: ~30%** (from ~75 hours to ~52 hours for 100B).

## Benchmark Results (sieve_bench.c)

Proof-of-concept with recursive initial fast-forward (apply sieve at trajectory start,
re-apply if resulting value is still odd). Step counts verified exact.

| N    | k  | Steps skipped | Wall speedup | Notes                    |
|------|----|--------------|-------------|--------------------------|
| 10M  | 16 | 6.5%         | 1.21x       | Small N, many n < 2^k    |
| 100M | 16 | 9.0%         | 1.10x       | Precomp table in L3 cache|
| 100M | 24 | 8.1%         | 1.18x       | Larger skip per application|
| 1B   | 24 | 9.7%         | 1.21x       | Steady-state behavior    |

**Mid-trajectory sieve** (apply sieve at every intermediate odd value):
- Skips 19.1% of steps (vs 8.1% for start-only)
- But 2% SLOWER for bare iteration (128-bit multiply overhead > saved ALU ops)
- For branch_locus with 27 grid levels per step: each skipped step saves ~145 ns of
  grid work, while sieve lookup costs ~10 ns → net ~30-40% faster

## Files Produced

| File | Size | Description |
|------|------|-------------|
| `gen_sieve.c` | 8KB | Sieve generator |
| `analyze_sieve.c` | 7KB | Analysis tool |
| `sieve_bench.c` | 5KB | Proof-of-concept benchmark |
| `sieve_report.md` | — | This report |
| `sieve_k16_class.bin` | 8KB | Class bitmap (k=16) |
| `sieve_k16_exact.bin` | 8KB | Exact bitmap (k=16) |
| `sieve_k16_precomp.bin` | 769KB | Precomputed data (k=16) |
| `sieve_k16_stats.csv` | 942KB | Per-residue CSV (k=16) |
| `sieve_k24_class.bin` | 2MB | Class bitmap (k=24) |
| `sieve_k24_exact.bin` | 2MB | Exact bitmap (k=24) |
| `sieve_k24_precomp.bin` | 192MB | Precomputed data (k=24) |
| `sieve_k32_class.bin` | 512MB | Class bitmap (k=32) |
| `sieve_k32_exact.bin` | 512MB | Exact bitmap (k=32) |
