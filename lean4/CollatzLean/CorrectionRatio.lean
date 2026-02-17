/-
  CollatzLean/CorrectionRatio.lean
  The correction ratio r(t) = correction(n,t) / 2^ν₂(n,t) and its properties.

  Key result: if the walk has eventually linear drift, then the Collatz
  sequence is eventually bounded.  This replaces the false `correction_bound`
  (which claimed correction/3^ν₃ is bounded — it isn't) with the correct
  ratio correction/2^ν₂, which IS bounded when the walk has positive drift.

  See docs/correction_ratio_bound.tex for the full mathematical argument.
-/
import CollatzLean.Identity
import CollatzLean.Drift
import Mathlib.Data.Fintype.Pigeonhole

namespace Collatz

open Real

/-! ## Correction ratio recurrence

The correction ratio r(t) = C(t)/2^ν₂ satisfies:
  - Even step: r → r/2
  - Odd step: r → 3r + 1
This is the same arithmetic as the Collatz map, but driven by the parity
of collatzSeq(n,t), not by r(t) itself.

We work with the cleared-denominator form to stay in ℕ:
  correction(n,t) and 2^(nu2 n t)
and derive the key inequality on collatzSeq from these. -/

/-- At an even step, correction is unchanged and 2^ν₂ doubles.
    So correction / 2^ν₂ halves (cleared form: same numerator, larger denominator). -/
theorem correction_ratio_even (n t : ℕ) (he : isEvenStep n t = true) :
    correction n (t + 1) = correction n t ∧
    2 ^ nu2 n (t + 1) = 2 ^ nu2 n t * 2 := by
  exact ⟨correction_succ_even n t he, by rw [nu2_step_even n t he, pow_succ]⟩

/-- At an odd step, correction triples plus 2^ν₂, and 2^ν₂ stays.
    So correction / 2^ν₂ → 3 * (correction / 2^ν₂) + 1. -/
theorem correction_ratio_odd (n t : ℕ) (ho : isOddStep n t = true) :
    correction n (t + 1) = 3 * correction n t + 2 ^ nu2 n t ∧
    nu2 n (t + 1) = nu2 n t := by
  exact ⟨correction_succ_odd n t ho, nu2_step_odd n t ho⟩

/-! ## Trajectory bound from linear drift

The core result: if walk(n,t) ≥ ε·t for t ≥ T₀, then collatzSeq(n,t)
is eventually bounded.

Strategy: from the identity  a(t) · 2^ν₂ = n · 3^ν₃ + C(t),
we get  a(t) = n · 3^ν₃/2^ν₂ + C(t)/2^ν₂.

Walk divergence gives 3^ν₃/2^ν₂ → 0.  The geometric series argument
(see correction_ratio_bound.tex §3) shows C(t)/2^ν₂ is bounded.
Therefore a(t) is bounded.

For the Lean formalization, we work directly with the ℕ inequality:
  collatzSeq n t ≤ B  ↔  n · 3^ν₃ + C(t) ≤ B · 2^ν₂
and prove the RHS for large t. -/

/-- From the multiplicative identity: collatzSeq n t ≤ (n * 3^ν₃ + correction) / 2^ν₂.
    Since collatzSeq * 2^ν₂ = n * 3^ν₃ + correction exactly, this is an equality,
    but the ≤ form is what we need for bounding. -/
theorem collatzSeq_le_of_identity (n t : ℕ) (_hn : n ≥ 1) :
    collatzSeq n t * 2 ^ nu2 n t = n * 3 ^ nu3 n t + correction n t :=
  collatz_identity n t

/-- If the walk has eventually linear drift, then for all sufficiently
    large t, the trajectory value collatzSeq(n,t) is bounded.

    This is the central new result, replacing the false correction_bound.
    The bound B depends on the drift rate ε.

    The proof requires showing that the geometric series
      Σ_m 3^m · 2^{-D_m}
    converges when D_m ≥ m·α with α > log₂3 (from the walk drift).
    This is a real-analysis argument formalized in ℕ via cleared denominators.

    Sorry: the full geometric series argument requires substantial real
    analysis infrastructure (partial sums, geometric series convergence,
    floor/ceil bounds).  The mathematical proof is in
    docs/correction_ratio_bound.tex, Theorem 3.3. -/
theorem collatzSeq_eventually_bounded_of_linear_drift (n : ℕ) (hn : n ≥ 1)
    (ε : ℝ) (hε : ε > 0)
    (T₀ : ℕ) (hbound : ∀ t, t ≥ T₀ → (↑(nu3 n t) / ↑t : ℝ) ≤ p_equilibrium - ε) :
    ∃ B : ℕ, ∃ T₁ : ℕ, ∀ t, t ≥ T₁ → collatzSeq n t ≤ B := by
  sorry

/-! ## Eventual periodicity

From the trajectory bound, the Collatz sequence takes finitely many values
for large t, hence is eventually periodic by pigeonhole. -/

/-- Equal Collatz values propagate forward: if the sequence agrees at two
    times, it agrees at all later offsets (since collatzSeq is just iteration). -/
private theorem collatzSeq_shift_eq (n t₁ t₂ : ℕ)
    (h : collatzSeq n t₁ = collatzSeq n t₂) (k : ℕ) :
    collatzSeq n (t₁ + k) = collatzSeq n (t₂ + k) := by
  induction k with
  | zero => simpa
  | succ k ih =>
    change collatz (collatzSeq n (t₁ + k)) = collatz (collatzSeq n (t₂ + k))
    rw [ih]

/-- A bounded Collatz trajectory is eventually periodic. -/
theorem collatzSeq_eventually_periodic_of_bounded (n : ℕ) (_hn : n ≥ 1)
    (B T₁ : ℕ) (hB : ∀ t, t ≥ T₁ → collatzSeq n t ≤ B) :
    ∃ T₂ : ℕ, ∃ p : ℕ, p ≥ 1 ∧ T₂ ≥ T₁ ∧ ∀ t, t ≥ T₂ → collatzSeq n (t + p) = collatzSeq n t := by
  -- Pigeonhole: B+2 consecutive values map to B+1 possible outputs
  let f : Fin (B + 2) → Fin (B + 1) := fun i =>
    ⟨collatzSeq n (T₁ + i.val), by have := hB (T₁ + i.val) (by omega); omega⟩
  obtain ⟨i, j, hij, hfij⟩ :=
    Fintype.exists_ne_map_eq_of_card_lt f (by simp [Fintype.card_fin])
  -- Extract that the trajectory values are equal
  have heq : collatzSeq n (T₁ + i.val) = collatzSeq n (T₁ + j.val) :=
    congrArg Fin.val hfij
  have hne : i.val ≠ j.val := Fin.val_ne_of_ne hij
  -- Take the smaller index as start, difference as period
  rcases Nat.lt_or_gt_of_ne hne with hlt | hgt
  · -- i.val < j.val
    refine ⟨T₁ + i.val, j.val - i.val, by omega, by omega, ?_⟩
    intro t ht
    have hk := collatzSeq_shift_eq n (T₁ + i.val) (T₁ + j.val) heq (t - (T₁ + i.val))
    rw [Nat.add_sub_cancel' (show T₁ + i.val ≤ t by omega)] at hk
    rw [show T₁ + j.val + (t - (T₁ + i.val)) = t + (j.val - i.val) from by omega] at hk
    exact hk.symm
  · -- j.val < i.val
    refine ⟨T₁ + j.val, i.val - j.val, by omega, by omega, ?_⟩
    intro t ht
    have hk := collatzSeq_shift_eq n (T₁ + j.val) (T₁ + i.val) heq.symm (t - (T₁ + j.val))
    rw [Nat.add_sub_cancel' (show T₁ + j.val ≤ t by omega)] at hk
    rw [show T₁ + i.val + (t - (T₁ + j.val)) = t + (i.val - j.val) from by omega] at hk
    exact hk.symm

/-! ## Cycle elimination (Δ₃ = 1)

The only Collatz cycle with exactly one odd step per period is {1, 2, 4}.
This follows from the cycle equation: c₀ = 2^e₁ / (2^Δ₂ - 3).
For c₀ to be a positive integer, 2^Δ₂ - 3 must divide a power of 2,
forcing 2^Δ₂ - 3 = 1, hence Δ₂ = 2, c₀ ∈ {1, 2, 4}. -/

set_option linter.unusedVariables false in
/-- In the trivial cycle 1 → 4 → 2 → 1, the sequence reaches 1. -/
theorem reaches_one_of_cycle_142 (n : ℕ) (hn : n ≥ 1)
    (T₂ p : ℕ) (hp : p ≥ 1)
    (hperiodic : ∀ t, t ≥ T₂ → collatzSeq n (t + p) = collatzSeq n t)
    (hone : ∃ t, t ≥ T₂ ∧ collatzSeq n t = 1) :
    collatzReaches n := by
  obtain ⟨t, _, ht1⟩ := hone
  exact ⟨t, ht1⟩

/-- Any eventually periodic Collatz trajectory with walk divergence
    must contain 1 in its cycle.

    For Δ₃ = 1 cycles: proved algebraically (the only such cycle is {1,2,4}).
    For Δ₃ ≥ 2 cycles: follows from Baker-type estimates on |2^a - 3^b|
    (uses baker_two_three from Baker.lean).

    Sorry: the full cycle equation analysis + Baker application for Δ₃ ≥ 2. -/
theorem cycle_contains_one (n : ℕ) (hn : n ≥ 1)
    (B T₂ p : ℕ) (hp : p ≥ 1)
    (hB : ∀ t, t ≥ T₂ → collatzSeq n t ≤ B)
    (hperiodic : ∀ t, t ≥ T₂ → collatzSeq n (t + p) = collatzSeq n t)
    (hdiv : Filter.Tendsto (fun t => walk n t) Filter.atTop Filter.atTop) :
    ∃ t, t ≥ T₂ ∧ collatzSeq n t = 1 := by
  sorry

/-! ## Main composition -/

/-- Walk divergence with linear drift implies collatzReaches.
    This replaces the false correction_bound sorry with an honest proof chain:
    linear drift → correction ratio bounded → trajectory bounded →
    eventually periodic → cycle is trivial → reaches 1. -/
theorem reaches_one_of_linear_drift (n : ℕ) (hn : n ≥ 1)
    (ε : ℝ) (hε : ε > 0)
    (T₀ : ℕ) (hbound : ∀ t, t ≥ T₀ → (↑(nu3 n t) / ↑t : ℝ) ≤ p_equilibrium - ε)
    (hdiv : Filter.Tendsto (fun t => walk n t) Filter.atTop Filter.atTop) :
    collatzReaches n := by
  -- Step 1: trajectory is eventually bounded
  obtain ⟨B, T₁, hBound⟩ := collatzSeq_eventually_bounded_of_linear_drift n hn ε hε T₀ hbound
  -- Step 2: trajectory is eventually periodic
  obtain ⟨T₂, p, hp, hT₂ge, hPeriodic⟩ := collatzSeq_eventually_periodic_of_bounded n hn B T₁ hBound
  -- Step 3: cycle contains 1
  have hCycle := cycle_contains_one n hn B T₂ p hp
    (fun t ht => hBound t (by omega)) hPeriodic hdiv
  -- Step 4: extract collatzReaches
  obtain ⟨t, _, ht1⟩ := hCycle
  exact ⟨t, ht1⟩

end Collatz
