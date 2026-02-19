# v2_danger Anomalies — 2026-02-18

Observations from runs at N=10K, 1M, 10M, 100M, 1B.

## 1. k=1 E[v₂]=4.67, safe=100% at N=1B

At scale 3^1=3, the 3x3 grid has only 9 cells. At N=1B, E[v₂]=4.6704 and
safe_frac=100%. This is anomalously high compared to the global E[v₂]=1.9948.

Hypothesis: modular arithmetic artifact. At scale 3, cell (nu2 mod 3, nu3 mod 3)
collapses so much structure that certain cells accumulate disproportionately large
v₂ values. The cell (0,0) in particular sees the first step of every trajectory
where n is divisible by high powers of 2, contributing large v₂.

Counter-check: at N=100M, k=1 showed E[v₂]=1.9941 (normal). So this jumped
dramatically between 100M and 1B. Possible uint32_t overflow in cell_t.count?
At 1B trajectories with ~67 odd steps each, a single cell at k=1 could accumulate
67B/9 ≈ 7.5B visits, which overflows uint32_t (max 4.29B).

**LIKELY ROOT CAUSE: uint32_t count overflow at k=1.**

Fix: change cell_t.count from uint32_t to uint64_t for large N runs, or use
uint64_t when N > 1B.

## 2. k=6,7 identical to k=5 (occupancy saturation)

At N=1B with min_visits=5, only 12875 cells are occupied across k=5,6,7.
The k=5 grid has 59049 cells, k=6 has 531441, k=7 has 4782969.

With 67.5B odd steps distributed across 4.8M cells at k=7, the average is
~14 visits/cell — but the distribution is highly non-uniform (follows the
trajectory measure, concentrated near the equilibrium line). Most cells at
k≥6 get 0-4 visits, below min_visits=5.

Expected N to unlock scales:
- k=6 (729²=531K cells): N ≈ 10B-100B
- k=7 (2187²=4.8M cells): N ≈ 100B-1T

## 3. k=4 danger fraction shrinking: 5.88% → 3.99% → 2.45%

As N increases, more cells at k=4 cross the min_visits threshold, and cells
that were marginally dangerous (E[v₂] just below log₂3) average out above
the threshold with more data. This is consistent with the dangerous cells
being exactly the CF convergent cells — a fixed finite set — while newly
occupied cells are generically safe.

## 4. Autocorrelation lag pattern

Lag-1 is weakly negative (-0.007 at 1B), lag-2 is strongly negative (-0.092),
lag-4 is the only positive lag (+0.007). This oscillatory pattern suggests
a ~4-step quasi-periodicity in v₂ values along trajectories.

Physical interpretation: after a low-v₂ odd step (v₂=1, the "dangerous" case),
the trajectory tends to have higher v₂ at the next odd step (mean reversion),
but two odd steps later it dips again (lag-2 negative). The positive lag-4
suggests a 4-step return pattern, possibly related to the structure of
3-adic neighborhoods on the torus.

## 5. Max residence length scaling

| N     | k=4 max | k=5 max |
|-------|---------|---------|
| 10K   | 9       | —       |
| 1M    | 6       | —       |
| 10M   | 7       | 7       |
| 100M  | 7       | 11      |
| 1B    | 6       | 22      |

k=4 max is stable around 6-7 (bounded). k=5 max is growing: 7→11→22.
Growth rate is sublinear in N — consistent with logarithmic growth
(log(1B)/log(10M) ≈ 3, and 22/7 ≈ 3.1).

If max_run ~ C * log(N), this is exactly what the Diophantine Repeller
predicts: the probability of a run of length L decays exponentially,
so the maximum over N trajectories grows as log(N).
