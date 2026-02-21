/-
  CollatzLean/SUnitEquation.lean
  S-unit equations 2^a − 3^b = d and their connection to Collatz cycles.

  An S-unit equation (for S = {2,3}) takes the form:
    2^a − 3^b = d
  where a, b ≥ 1 and d ∈ ℤ. The Collatz cycle equation
    c₀ · (2^L − 3^K) = correction
  is exactly such an equation with c = c₀ and d = correction.

  Baker's effective lower bound on |2^a − 3^b| constrains solutions,
  implying finiteness: for any fixed D, only finitely many (a,b) pairs
  satisfy |2^a − 3^b| ≤ D.

  Architecture:
  - isSUnitSoln: S-unit solution predicate
  - sunit_gap_effective: Baker lower bound on S-unit gaps
  - sunit_c_le_abs_d: elementary coefficient bound (gap ≥ 1)
  - sunit_c_effective_bound: Baker-based coefficient bound
  - cycle_as_sunit_int: cycle equation lifted to ℤ
  - sunit_solutions_finite: finiteness of bounded solutions (sorry)
  - cycle_c0_baker_bound: effective bound on cycle starting value

  References:
  - Baker (1975): Transcendental Number Theory
  - Laurent, Mignotte, Nesterenko (1995): Formes linéaires en deux logarithmes
  - Evertse (1984): On sums of S-units and linear recurrences
  - Steiner (1977): Cycle equation framework
-/
import CollatzLean.DistancePowers
import CollatzLean.SteinerCycle

set_option linter.style.nativeDecide false

namespace Collatz

open Real

/-! ## S-unit equation: definition -/

/-- Predicate: (a, b, d) is an S-unit solution for S = {2, 3}. -/
def isSUnitSoln (a b : ℕ) (d : ℤ) : Prop :=
  (2 : ℤ) ^ a - (3 : ℤ) ^ b = d

/-- 2^1 − 3^1 = −1. -/
theorem sunit_2_3 : isSUnitSoln 1 1 (-1) := by unfold isSUnitSoln; native_decide

/-- 2^3 − 3^2 = −1 (the Pythagorean whole tone). -/
theorem sunit_8_9 : isSUnitSoln 3 2 (-1) := by unfold isSUnitSoln; native_decide

/-- 2^19 − 3^12 = −7153 (the Pythagorean comma). -/
theorem sunit_comma : isSUnitSoln 19 12 (-7153) := by unfold isSUnitSoln; native_decide

/-! ## Baker's effective bound on S-unit gaps -/

/-- Baker's theorem provides an effective lower bound on |2^a − 3^b|.
    Direct alias of distance_powers_lower_bound. -/
theorem sunit_gap_effective :
    ∃ (C : ℝ) (κ : ℝ), C > 0 ∧ κ > 0 ∧
      ∀ a b : ℕ, a ≥ 1 → b ≥ 1 →
        |(2 : ℝ) ^ a - (3 : ℝ) ^ b| >
          C * min ((2 : ℝ) ^ a) ((3 : ℝ) ^ b) / (max (a : ℝ) (b : ℝ)) ^ κ :=
  distance_powers_lower_bound

/-- The integer S-unit gap is always at least 1 (multiplicative independence). -/
theorem sunit_gap_at_least_one (a b : ℕ) (ha : a ≥ 1) (hb : b ≥ 1) :
    |(2 : ℤ) ^ a - (3 : ℤ) ^ b| ≥ 1 :=
  distance_powers_at_least_one a b ha hb

/-! ## Elementary S-unit coefficient bound -/

/-- If c · (2^a − 3^b) = d with c, a, b ≥ 1, then c ≤ |d|.
    Proof: |2^a − 3^b| ≥ 1, so |d| = c · |gap| ≥ c · 1 = c. -/
theorem sunit_c_le_abs_d (c a b : ℕ) (d : ℤ)
    (_hc : c ≥ 1) (ha : a ≥ 1) (hb : b ≥ 1)
    (heq : (c : ℤ) * ((2 : ℤ) ^ a - (3 : ℤ) ^ b) = d) :
    (c : ℤ) ≤ |d| := by
  have hgap := sunit_gap_at_least_one a b ha hb
  rw [← heq, abs_mul]
  calc (c : ℤ) ≤ |(c : ℤ)| := le_abs_self _
    _ = |(c : ℤ)| * 1 := (mul_one _).symm
    _ ≤ |(c : ℤ)| * |((2 : ℤ) ^ a - (3 : ℤ) ^ b)| :=
        Int.mul_le_mul_of_nonneg_left hgap (abs_nonneg _)

/-! ## Baker-based effective coefficient bound -/

/-- From Baker's theorem: if c · (2^a − 3^b) = d with a, b ≥ 1, then
    c · C · min(2^a, 3^b) < |d| · max(a, b)^κ.

    This is the division-free form of c < |d| · max^κ / (C · min). -/
theorem sunit_c_effective_bound :
    ∃ (C : ℝ) (κ : ℝ), C > 0 ∧ κ > 0 ∧
      ∀ (c a b : ℕ) (d : ℤ),
        c ≥ 1 → a ≥ 1 → b ≥ 1 →
        (c : ℤ) * ((2 : ℤ) ^ a - (3 : ℤ) ^ b) = d →
        (c : ℝ) * (C * min ((2 : ℝ) ^ a) ((3 : ℝ) ^ b)) <
          |(d : ℝ)| * (max (a : ℝ) (b : ℝ)) ^ κ := by
  obtain ⟨C, κ, hC, hκ, hbaker⟩ := distance_powers_lower_bound
  refine ⟨C, κ, hC, hκ, ?_⟩
  intro c a b d hc ha hb heq
  have hgap := hbaker a b ha hb
  have hmax_pos : (0 : ℝ) < max (a : ℝ) b :=
    lt_of_lt_of_le (Nat.cast_pos.mpr (by omega)) (le_max_left _ _)
  have hmax_pow_pos : (0 : ℝ) < (max (a : ℝ) b) ^ κ := rpow_pos_of_pos hmax_pos _
  have hc_pos : (0 : ℝ) < c := Nat.cast_pos.mpr (by omega)
  -- |d| = c · |2^a - 3^b| over ℝ
  have hd_abs : |(d : ℝ)| = (c : ℝ) * |(2 : ℝ) ^ a - (3 : ℝ) ^ b| := by
    have : (d : ℝ) = (c : ℝ) * ((2 : ℝ) ^ a - (3 : ℝ) ^ b) := by exact_mod_cast heq.symm
    rw [this, abs_mul, abs_of_pos hc_pos]
  -- Baker: c * (C·min/max^κ) < c · |diff| = |d|
  have h1 : (c : ℝ) * (C * min ((2 : ℝ) ^ a) ((3 : ℝ) ^ b) /
      (max (a : ℝ) b) ^ κ) < |(d : ℝ)| := by
    rw [hd_abs]; exact mul_lt_mul_of_pos_left hgap hc_pos
  -- Rearrange: c * (x/y) = c*x/y, then a/b < c ⟹ a < c*b
  rw [← mul_div_assoc, div_lt_iff₀ hmax_pow_pos] at h1
  exact h1

/-! ## Cycle equation as S-unit equation over ℤ -/

/-- The Steiner cycle equation c₀ · (2^L − 3^K) = correction,
    lifted from ℕ (natural subtraction) to ℤ (genuine subtraction). -/
theorem cycle_as_sunit_int (c₀ p : ℕ)
    (hcycle : collatzStep^[p] c₀ = c₀)
    (hexp : 2 ^ cycleNu2 c₀ p > 3 ^ cycleNu3 c₀ p) :
    (c₀ : ℤ) * ((2 : ℤ) ^ cycleNu2 c₀ p - (3 : ℤ) ^ cycleNu3 c₀ p) =
      (cycleCorrection c₀ p : ℤ) := by
  have h := cycle_equation c₀ p hcycle hexp
  have hle : 3 ^ cycleNu3 c₀ p ≤ 2 ^ cycleNu2 c₀ p := by omega
  zify [hle] at h
  linarith

/-- The S-unit gap 2^L − 3^K in a cycle is an isSUnitSoln. -/
theorem cycle_gap_is_sunit (c₀ p : ℕ)
    (_hexp : 2 ^ cycleNu2 c₀ p > 3 ^ cycleNu3 c₀ p) :
    isSUnitSoln (cycleNu2 c₀ p) (cycleNu3 c₀ p)
      ((2 : ℤ) ^ cycleNu2 c₀ p - (3 : ℤ) ^ cycleNu3 c₀ p) := by
  rfl

/-! ## Finiteness of S-unit solutions -/

/-- For any bound D, there are only finitely many (a, b) with a, b ≥ 1
    and |2^a − 3^b| ≤ D. This follows from Baker's effective lower bound:
    |2^a − 3^b| > C · min(2^a, 3^b) / max(a,b)^κ, and the fact that
    the exponential min(2^a, 3^b) eventually dominates the polynomial
    max(a,b)^κ for any fixed D.

    The formal proof requires an "exponential beats polynomial" lemma
    (standard but tedious to formalize). -/
theorem sunit_solutions_finite (D : ℕ) :
    Set.Finite {p : ℕ × ℕ | p.1 ≥ 1 ∧ p.2 ≥ 1 ∧
      |(2 : ℤ) ^ p.1 - (3 : ℤ) ^ p.2| ≤ D} := by
  sorry

/-! ## Cycle starting value bound from Baker -/

/-- For a cycle with K ≥ 1 odd steps and 2^L > 3^K:
    c₀ · C · 3^K < correction · max(L, K)^κ.

    This is sunit_c_effective_bound applied to the cycle equation,
    using min(2^L, 3^K) = 3^K since 2^L > 3^K. -/
theorem cycle_c0_baker_bound :
    ∃ (C : ℝ) (κ : ℝ), C > 0 ∧ κ > 0 ∧
      ∀ (c₀ p : ℕ),
        c₀ ≥ 1 →
        collatzStep^[p] c₀ = c₀ →
        2 ^ cycleNu2 c₀ p > 3 ^ cycleNu3 c₀ p →
        cycleNu3 c₀ p ≥ 1 →
        (c₀ : ℝ) * (C * (3 : ℝ) ^ cycleNu3 c₀ p) <
          (cycleCorrection c₀ p : ℝ) *
            (max (cycleNu2 c₀ p : ℝ) (cycleNu3 c₀ p : ℝ)) ^ κ := by
  obtain ⟨C, κ, hC, hκ, hbound⟩ := sunit_c_effective_bound
  refine ⟨C, κ, hC, hκ, ?_⟩
  intro c₀ p hc hcycle hexp hK
  -- cycleNu2 ≥ 2 since 2^L > 3^K ≥ 3
  have h3K : 3 ≤ 3 ^ cycleNu3 c₀ p := by
    calc 3 = 3 ^ 1 := (pow_one 3).symm
      _ ≤ 3 ^ cycleNu3 c₀ p := Nat.pow_le_pow_right (by omega) hK
  have hL : cycleNu2 c₀ p ≥ 2 := by
    by_contra hlt; push_neg at hlt
    interval_cases (cycleNu2 c₀ p)
    · simp_all
    · simp_all; omega
  -- Apply the effective bound
  have heq := cycle_as_sunit_int c₀ p hcycle hexp
  have h := hbound c₀ (cycleNu2 c₀ p) (cycleNu3 c₀ p) (cycleCorrection c₀ p : ℤ)
    hc (by omega) hK heq
  -- min(2^L, 3^K) = 3^K since 2^L > 3^K
  have hmin : min ((2 : ℝ) ^ cycleNu2 c₀ p) ((3 : ℝ) ^ cycleNu3 c₀ p) =
      (3 : ℝ) ^ cycleNu3 c₀ p := by
    apply min_eq_right; exact_mod_cast (le_of_lt hexp)
  rw [hmin] at h
  -- |correction| = correction (correction ≥ 0)
  have hcorr_nonneg : (0 : ℤ) ≤ (cycleCorrection c₀ p : ℤ) := Int.natCast_nonneg _
  rwa [abs_of_nonneg (by exact_mod_cast hcorr_nonneg)] at h

end Collatz
