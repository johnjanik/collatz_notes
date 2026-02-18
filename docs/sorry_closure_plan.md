# Plan: Closing Sorrys 6 and 8 via the Geometric Bridge

**Date:** 2026-02-18
**Goal:** Prove `tunnel_walls_positive_of_baker` (sorry 6) and `nu3_linear_bound` (sorry 8)
by connecting Baker's theorem to the K-bound through the tunnel wall mechanism.

## Current State

9 sorrys across 16 Lean files (~1600 lines). Critical path:

```
nu3_linear_bound (sorry 8, INDEPENDENT — equivalent to Collatz)
    ↓
reaches_one_of_linear_drift (proved)
    ↓
collatz_conjecture (proved)
```

**Problem:** Sorry 8 is *equivalent* to the Collatz conjecture. It's circular —
we assume the conclusion to prove the conclusion.

## Revised Architecture

Replace the independent sorry with a derivation from Baker's theorem:

```
baker_two_three (sorry 1-5, established mathematics)
    ↓
diophError_lower_bound (PROVED, TunnelWidth.lean)
    ↓
tunnel_walls_positive_of_baker (sorry 6 — CLOSE)
    ↓
topological_recurrence (NEW — 2-adic/3-adic metric conflict)
    ↓
nu3_linear_bound (sorry 8 — CLOSE, now a THEOREM)
    ↓
reaches_one_of_linear_drift (PROVED)
    ↓
collatz_conjecture (PROVED)
```

## Why This Works (The Self-Correcting Mechanism)

The equilibrium line L on (Z/3^b Z)² has irrational slope log₂3. Baker's theorem
guarantees L cannot coincide with rational grid lines at any scale 3^b. The gap
between L and the nearest rational line is > C/(3^b)^{1+ε}.

**The feedback loop:**
1. If ν₃/t → p_eq = 1/(1+log₂3), then ν₂/ν₃ → log₂3
2. On the torus, the residue pair approaches the irrational line L
3. Baker guarantees pure-even walls surround L (sorry 6)
4. Trajectory enters a wall → forced even step → walk increment +1
5. This pushes ν₃/t back down below p_eq
6. Equilibrium is unstable because it's irrational on a rational lattice

## Three Theorems to Prove

### Sorry 6: `tunnel_walls_positive_of_baker` (Geometric Bridge)

**File:** TunnelWidth.lean
**Statement:** If |diophError(b)| > C'/(3^b)^{1+ε}, then pure-even cells exist at scale 3^b.

**Proof strategy:** The Baker gap creates a structural dead zone — residue classes
(r₂, r₃) mod 3^b where no integer n can produce an odd-step visit. If r₂ ≈ log₂3 · r₃
(within the Baker gap), the multiplicative identity forces a(t) to be even at that cell.

**Key steps:**
1. At cell (r₂, r₃) on the torus, an odd step requires a(t) ≡ 1 (mod 2)
2. The multiplicative identity constrains a(t) via n · 3^{r₃} + C ≡ a(t) · 2^{r₂} (mod 3^b)
3. When r₂/r₃ is in the Diophantine gap (too close to log₂3 to be a valid rational
   approximation), the parity constraint on a(t) cannot be satisfied
4. Therefore these cells are structurally pure-even

**Difficulty:** Medium — arithmetic argument, no new mathematical machinery needed.

### Sorry 7 → Topological Recurrence (2-adic/3-adic Metric Conflict)

**File:** TunnelWidth.lean (restructure `tunnel_foliation_intersection`)
**Statement:** Every Collatz trajectory visits pure-even cells at scale 3^b with
positive frequency.

**Proof strategy (the 2-adic argument):**
1. To sustain k consecutive "10" blocks (odd-even pairs), n must satisfy
   n ≡ 2^{k+1} - 1 (mod 2^{k+1}) — "2-adically large"
2. The Collatz map contracts 2-adically (division by 2) but expands 3-adically
3. After enough steps, the 3-adic expansion of a(t) fills out all residue classes mod 3^b
4. This forces the residue pair (ν₂ mod 3^b, ν₃ mod 3^b) to visit the entire torus
5. In particular, it visits the pure-even wall cells

**The metric conflict:** A trajectory cannot simultaneously:
- Maintain the 2-adic structure needed for high p_odd
- Avoid the 3-adic residue classes that correspond to pure-even walls

**Difficulty:** Hard — requires formalizing the 2-adic/3-adic interplay.

### Sorry 8: `nu3_linear_bound` (K-bound from Walls)

**File:** Drift.lean
**Statement:** ∃ K T₀, ∀ t ≥ T₀, 3·ν₃(n,t) ≤ t + K

**Proof strategy:** Composition of sorry 6 + topological recurrence.
1. At every scale 3^b (b ≥ 1), pure-even walls exist (sorry 6, proved from Baker)
2. The trajectory visits these walls with positive frequency (topological recurrence)
3. Each wall visit forces walk increment +1 (proved: `walkIncrement_at_pureEven`)
4. Positive-frequency wall visits → positive mean walk increment → K-bound

**Detailed argument:**
- Let f(b) = wall encounter frequency at scale 3^b (positive by topological recurrence)
- At each wall encounter, walk gets +1 instead of -log₂3 (net gain: 1 + log₂3 ≈ 2.585)
- So mean walk increment ≥ f(b) · (1 + log₂3) - (1 - f(b)) · log₂3
  = f(b) · (1 + 2·log₂3) - log₂3
- For f(b) > log₂3/(1 + 2·log₂3) ≈ 0.387 · 2/(1 + 2·1.585) ≈ 0.24, drift is positive
- The wall density at k=144 is 659/17030 ≈ 3.9% — but this is physical walls,
  not encounter frequency. Need to bound encounter frequency from wall density.

**Difficulty:** Medium — given sorrys 6 and 7, this is a composition argument.

## Revised Sorry Inventory (Target: 7)

| # | File | Theorem | Status | Category |
|---|------|---------|--------|----------|
| 1 | Baker.lean | baker_aux_construction | sorry | Gel'fond-Schneider |
| 2 | Baker.lean | baker_extrapolation | sorry | Gel'fond-Schneider |
| 3 | Baker.lean | baker_zero_estimate | sorry | Gel'fond-Schneider |
| 4 | Baker.lean | baker_effective_bound | sorry | Gel'fond-Schneider |
| 5 | Baker.lean | baker_two_three | sorry | Gel'fond-Schneider |
| 6 | TunnelWidth.lean | tunnel_walls_positive_of_baker | **PROVE** | Geometric bridge |
| 7 | TunnelWidth.lean | tunnel_foliation_intersection | **PROVE** | 2-adic recurrence |
| 8 | Drift.lean | nu3_linear_bound | **PROVE** | Composition |
| 9 | CorrectionRatio.lean | no_cycle_equality_case | sorry | Baker for cycles |

**Result:** 7 sorrys remaining. All are either:
- Established mathematics awaiting formalization (Baker chain, 1-5)
- Direct application of Baker to cycle equations (9)

The critical path runs through Baker, which is the *correct* bottleneck.

## Implementation Order

1. **Sorry 6 first** — the geometric bridge. Purely arithmetic, no new imports needed.
   Once proved, the tunnel wall mechanism is rigorous.

2. **Sorry 7 next** — topological recurrence. The 2-adic/3-adic argument.
   May need new definitions for 2-adic valuation constraints.

3. **Sorry 8 last** — composition. Once 6 and 7 are proved, this is straightforward
   plumbing: walls exist → trajectory hits walls → walk has positive drift → K-bound.

## Key Mathematical References

- Baker's theorem: Baker (1975), specialized to α₁=2, α₂=3
- Cycle elimination: Steiner (1977), Eliahou (1993), Simons-de Weger (2005)
- 2-adic Collatz dynamics: Lagarias (1985), Wirsching (1998)
- Diophantine approximation of log₂3: classical, via continued fractions
