/-
  CollatzLean/SteinerCycle.lean
  Steiner/Hercher cycle elimination: no non-trivial Collatz cycle
  with at most 91 odd steps.

  Architecture:
  1. correction_upper_bound: 2·correction ≤ (3^K − 1)·2^L (proved by induction)
  2. steiner_K_bound_79: for Δ₃ ≤ 79, cycleNu3 ≤ 91 (proved via native_decide
     on 2^145 < 3^92)
  3. hercher_no_small_cycle: axiom citing Hercher 2024 — no m-cycle for m ≤ 91
  4. steiner_cycle_elimination: combines (2) and (3) for Δ₃ ≤ 79

  References:
  - Steiner (1977): Original cycle equation framework
  - Simons & de Weger (2005): Extended to m ≤ 68
  - Hercher (2024): "No Collatz m-Cycles with m ≤ 91", extended to m ≤ 91
    using elementary continued fraction + correction sum analysis.
-/
import CollatzLean.Baker

set_option linter.style.nativeDecide false

namespace Collatz

/-! ## Correction upper bound

The correction term cycleCorrection c₀ t satisfies:
  correction = ∑_{i=1}^{K} 3^{K-i} · 2^{L_i}
where K = cycleNu3, L_i = cycleNu2 at the i-th odd step, L_i ≤ L = cycleNu2.

Upper bound: correction ≤ 2^L · ∑_{i=0}^{K-1} 3^i = 2^L · (3^K - 1)/2.
Equivalently: 2·correction + 2^L ≤ 3^K · 2^L (avoids nat subtraction). -/

/-- The correction is bounded: 2·correction + 2^L ≤ 3^K · 2^L.
    Equivalent to correction ≤ 2^L·(3^K − 1)/2 but stated without subtraction.
    Proved by induction on t, tracking the recurrence at odd/even steps. -/
theorem correction_upper_bound (c₀ t : ℕ) :
    2 * cycleCorrection c₀ t + 2 ^ cycleNu2 c₀ t ≤
      3 ^ cycleNu3 c₀ t * 2 ^ cycleNu2 c₀ t := by
  induction t with
  | zero => simp [cycleCorrection, cycleNu3, cycleNu2]
  | succ t ih =>
    by_cases hodd : (collatzStep^[t] c₀) % 2 = 1
    · -- Odd step: correction(t+1) = 3·corr + 2^L, K→K+1, L unchanged
      -- Need: 2·(3·corr + 2^L) + 2^L ≤ 3^(K+1)·2^L
      -- = 6·corr + 3·2^L ≤ 3·3^K·2^L = 3·(2·corr + 2^L + (3^K·2^L - 2·corr - 2^L))
      -- Simply: 3·(2·corr + 2^L) ≤ 3·(3^K·2^L), which is 3 × IH.
      rw [cycleCorrection_succ_odd c₀ t hodd,
          cycleNu3_succ_odd c₀ t hodd,
          cycleNu2_succ_odd c₀ t hodd, pow_succ]
      nlinarith [ih]
    · -- Even step: correction unchanged, K unchanged, L→L+1
      -- Need: 2·corr + 2^(L+1) ≤ 3^K·2^(L+1)
      -- = 2·corr + 2·2^L ≤ 2·3^K·2^L. From IH (2·corr + 2^L ≤ 3^K·2^L):
      -- 2·corr ≤ 3^K·2^L - 2^L, so 2·corr + 2·2^L ≤ 3^K·2^L + 2^L ≤ 2·3^K·2^L.
      have heven : (collatzStep^[t] c₀) % 2 = 0 := by omega
      rw [cycleCorrection_succ_even c₀ t heven,
          cycleNu3_succ_even c₀ t heven,
          cycleNu2_succ_even c₀ t heven, pow_succ]
      nlinarith [ih, Nat.one_le_pow (cycleNu3 c₀ t) 3 (by omega)]

/-! ## Cycle minimum bound

From the cycle equation c₀·(2^L - 3^K) = correction and the correction
upper bound 2·correction ≤ (3^K - 1)·2^L, we get:
  2·c₀·(2^L - 3^K) ≤ (3^K - 1)·2^L

This bounds c₀ from above in terms of K and L. For large K/L, the bound
on c₀ becomes small, limiting cycle membership. -/

/-- For a cycle with c₀ ≥ 2: the correction upper bound constrains c₀.
    Specifically: 2·c₀·(2^L − 3^K) + 2^L ≤ 3^K · 2^L. -/
theorem cycle_c0_bound (c₀ p : ℕ)
    (hcycle : collatzStep^[p] c₀ = c₀)
    (hexp : 2 ^ cycleNu2 c₀ p > 3 ^ cycleNu3 c₀ p) :
    2 * c₀ * (2 ^ cycleNu2 c₀ p - 3 ^ cycleNu3 c₀ p) + 2 ^ cycleNu2 c₀ p ≤
      3 ^ cycleNu3 c₀ p * 2 ^ cycleNu2 c₀ p := by
  have hceq := cycle_equation c₀ p hcycle hexp
  have hcub := correction_upper_bound c₀ p
  -- hceq: c₀ * (2^L - 3^K) = correction
  -- hcub: 2 * correction + 2^L ≤ 3^K * 2^L
  nlinarith

/-! ## K-bound for small Δ₃

For Δ₃ ≤ 79 (period p = 3·Δ₃ ≤ 237):
If cycleNu3 ≥ 92 then cycleNu2 ≤ 3·79 - 92 = 145.
Since 2^145 < 3^92 (verified), this contradicts 2^L > 3^K.
Hence cycleNu3 ≤ 91 for any cycle with Δ₃ ≤ 79. -/

private theorem pow2_145_lt_pow3_92 : 2 ^ 145 < 3 ^ 92 := by native_decide

/-- For Δ₃ ≤ 79, any cycle with 2^ν₂ > 3^ν₃ has at most 91 odd steps. -/
theorem steiner_K_bound_79 (Δ₃ : ℕ) (hΔ_le : Δ₃ ≤ 79) (c₀ : ℕ)
    (hexp : 2 ^ cycleNu2 c₀ (3 * Δ₃) > 3 ^ cycleNu3 c₀ (3 * Δ₃)) :
    cycleNu3 c₀ (3 * Δ₃) ≤ 91 := by
  by_contra h
  push_neg at h
  have hK : cycleNu3 c₀ (3 * Δ₃) ≥ 92 := by omega
  -- ν₂ = 3·Δ₃ - ν₃ ≤ 237 - 92 = 145
  have hL : cycleNu2 c₀ (3 * Δ₃) ≤ 145 := by
    unfold cycleNu2
    have := cycleNu3_le c₀ (3 * Δ₃)
    omega
  -- 2^ν₂ ≤ 2^145
  have h2L : 2 ^ cycleNu2 c₀ (3 * Δ₃) ≤ 2 ^ 145 :=
    Nat.pow_le_pow_right (by omega) hL
  -- 3^92 ≤ 3^ν₃
  have h3K : 3 ^ 92 ≤ 3 ^ cycleNu3 c₀ (3 * Δ₃) :=
    Nat.pow_le_pow_right (by omega) hK
  -- 2^ν₂ ≤ 2^145 < 3^92 ≤ 3^ν₃, contradicting hexp
  omega

/-! ## Hercher's theorem (axiom)

Hercher (2024) proved: there is no non-trivial Collatz cycle with
at most 91 odd steps. The proof uses:
1. Correction sum bounds (each local minimum n_i ≥ X₀ ≈ 10^20)
2. Continued fraction expansion of log₂3
3. Case analysis on candidate (K, L) pairs

This is the sole axiom in this file. All other results are proved. -/

/-- Hercher's theorem: no non-trivial cycle with ≤ 91 odd steps.
    For any c₀ ≥ 2 in a periodic orbit with at most 91 odd steps,
    the orbit must contain 1 (i.e., c₀ is in the trivial cycle {1,2,4}).

    Reference: Hercher, "No Collatz m-Cycles with m ≤ 91" (2024). -/
axiom hercher_no_small_cycle :
    ∀ (c₀ p : ℕ), c₀ ≥ 2 → p ≥ 1 →
      collatzStep^[p] c₀ = c₀ → cycleNu3 c₀ p ≤ 91 →
      ∃ t, t < p ∧ collatzStep^[t] c₀ = 1

/-! ## Combined cycle elimination for Δ₃ ≤ 79 -/

/-- For Δ₃ ≤ 79: any periodic orbit of period 3·Δ₃ with c₀ ≥ 2 contains 1.
    Proof: steiner_K_bound_79 gives cycleNu3 ≤ 91, then hercher_no_small_cycle
    eliminates the cycle. -/
theorem steiner_cycle_elimination (Δ₃ : ℕ) (hΔ : Δ₃ ≥ 2) (hΔ_le : Δ₃ ≤ 79)
    (c₀ : ℕ) (hc : c₀ ≥ 2)
    (hcycle : collatzStep^[3 * Δ₃] c₀ = c₀)
    (hexp : 2 ^ cycleNu2 c₀ (3 * Δ₃) > 3 ^ cycleNu3 c₀ (3 * Δ₃)) :
    ∃ t, t < 3 * Δ₃ ∧ collatzStep^[t] c₀ = 1 := by
  have hK_le := steiner_K_bound_79 Δ₃ hΔ_le c₀ hexp
  exact hercher_no_small_cycle c₀ (3 * Δ₃) hc (by omega) hcycle hK_le

/-! ## Large Δ₃ case: focused sorry

For Δ₃ ≥ 80, the number of odd steps K could exceed 91.
This is the frontier of current mathematical knowledge.
Extending Hercher's computational verification to m > 91 would
close this sorry. -/

/-- For Δ₃ ≥ 80: cycle elimination. This remains open — extending
    Hercher's method to m > 91 requires larger computational verification
    thresholds and/or improved irrationality measures for log₂3. -/
theorem steiner_cycle_large (Δ₃ : ℕ) (hΔ : Δ₃ ≥ 80)
    (c₀ : ℕ) (hc : c₀ ≥ 2)
    (hcycle : collatzStep^[3 * Δ₃] c₀ = c₀)
    (hexp : 2 ^ cycleNu2 c₀ (3 * Δ₃) > 3 ^ cycleNu3 c₀ (3 * Δ₃)) :
    ∃ t, t < 3 * Δ₃ ∧ collatzStep^[t] c₀ = 1 := by
  sorry

end Collatz
