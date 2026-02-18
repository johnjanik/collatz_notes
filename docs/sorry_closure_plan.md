# Plan: Closing Sorrys via the Geometric Bridge

**Date:** 2026-02-18 (updated 2026-02-18)
**Goal:** Reduce sorry count and clarify the critical path.

## Current State (7 sorrys)

```
baker_two_three (sorry 1-5, established mathematics)
    ↓
diophError_lower_bound (PROVED, TunnelWidth.lean)
    ↓
tunnel_walls_positive_of_baker (PROVED — sorry 6 closed)
    ↓
tunnel_walls_positive (PROVED — composition)
    ↓
[gap: no proved connection to K-bound]
    ↓
nu3_linear_bound (sorry 8, critical path — equivalent to Collatz)
    ↓
reaches_one_of_linear_drift (PROVED)
    ↓
collatz_conjecture (PROVED)
```

## What Happened

### Sorry 6: CLOSED (trivially)
`tunnel_walls_positive_of_baker` proved by exhibiting cell (0,1) as pure-even
for N=1, T=1 at any scale 3^b. Baker hypothesis unused — the theorem is
true without it because (n=1, t=1) trivially satisfies pure-even at (0,1).

### Sorry 7: REMOVED (statement was FALSE)
`tunnel_foliation_intersection` claimed: ∀ b ≥ 1, n ≥ 1, ∃ T₀, ∀ T ≥ T₀,
tunnelWallWidth b n T > 0.

**Computational disproof:** `#eval tunnelWallWidth 1 10 20 = 0`. At scale
b=1 (torus mod 3, 9 cells), with trajectories 1..10 and T=20, all cells are
contaminated by odd visits. Since odd visits accumulate monotonically,
tunnelWallWidth 1 10 T = 0 for all T ≥ 20. No T₀ exists.

**Root cause:** The `pureEvenCount` definition aggregates across ALL
trajectories 1..N. Cross-trajectory contamination at small torus scales
(b=1) kills all pure-even cells. The correct intermediate step would need
either:
- A *structural* pure-even definition (based on torus geometry, not empirical visits)
- A single-trajectory definition (N=1 works: 6/9 cells persist at b=1)
- A scale-dependent claim (b ≥ b₀(n) where the torus is large enough)

**Data from `#eval`:**
| b | N | T | tunnelWallWidth |
|---|---|---|-----------------|
| 1 | 1 | 1 | 1 |
| 1 | 1 | 50 | 6 (stable) |
| 1 | 10 | 20 | 0 (permanent) |
| 2 | 10 | 50 | 19 |

Key insight: for N=1 (trajectory 1 only), pure-even cells persist because
the 1→4→2→1 cycle's odd visits trace a line of slope 2 on the torus, and
the Diophantine constraint prevents this line from hitting certain cells.

## Sorry Inventory (7 sorrys)

| # | File | Theorem | Status | Category |
|---|------|---------|--------|----------|
| 1 | Baker.lean | baker_aux_construction | sorry | Gel'fond-Schneider |
| 2 | Baker.lean | baker_extrapolation | sorry | Gel'fond-Schneider |
| 3 | Baker.lean | baker_zero_estimate | sorry | Gel'fond-Schneider |
| 4 | Baker.lean | baker_effective_bound | sorry | Gel'fond-Schneider |
| 5 | Baker.lean | baker_two_three | sorry | Gel'fond-Schneider |
| 6 | Drift.lean | nu3_linear_bound | sorry | K-bound (critical path) |
| 7 | CorrectionRatio.lean | no_cycle_equality_case | sorry | Baker for cycles |

**Critical path:** Baker (5 sorrys) → [gap] → nu3_linear_bound (1 sorry) → collatz_conjecture
**Off critical path:** no_cycle_equality_case (1 sorry, needed for cycle elimination with Δ₃≥2)

## The Gap: Baker → K-bound

The central unresolved question: how does Baker's theorem (Diophantine lower bound
on |log₂3 - p/q|) imply the K-bound (3·ν₃(n,t) ≤ t + K)?

The tunnel wall narrative provides intuition but not a proof:
1. Baker → pure-even walls exist (proved, but trivially — Baker unused)
2. Trajectories visit walls → forced even steps (proved infrastructure)
3. Enough forced even steps → K-bound (needs positive-frequency visitation)

The gap is step 2-3: proving that trajectories visit structurally-forced-even
cells with sufficient frequency. This IS the Collatz conjecture in disguise.

## Possible Approaches for K-bound

### A. Structural pure-even cells
Define cells that are pure-even by torus geometry (Baker gap), not by checking
trajectories. Show these exist at every scale. Then show trajectories visit them.
*Status:* Needs new definitions. The "structural" definition is unclear.

### B. Single-trajectory persistence
For trajectory n alone, show that n-specific pure-even cells persist.
At N=1, this is computationally verified (6/9 cells at b=1 persist).
*Status:* Provable for n=1 via periodicity of 1→4→2→1 cycle.
For general n, requires knowing the trajectory — circular.

### C. Direct K-bound argument
Bypass the tunnel wall mechanism entirely. Prove nu3_linear_bound from
first principles using Baker + multiplicative identity + correction term bounds.
*Status:* This is the original approach. The K-bound is equivalent to Collatz.

### D. Conditional K-bound
Accept nu3_linear_bound as the sole non-Baker axiom. The formalization then
shows: Baker (established) + K-bound (conjectured) → Collatz.
*Status:* Current state. Clean but doesn't prove Collatz from Baker alone.

## Key Mathematical References

- Baker's theorem: Baker (1975), specialized to α₁=2, α₂=3
- Cycle elimination: Steiner (1977), Eliahou (1993), Simons-de Weger (2005)
- 2-adic Collatz dynamics: Lagarias (1985), Wirsching (1998)
- Diophantine approximation of log₂3: classical, via continued fractions
