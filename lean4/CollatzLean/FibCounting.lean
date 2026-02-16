/-
  CollatzLean/FibCounting.lean
  Fibonacci word counting for the golden mean shift,
  and the key numerical inequality log₂(3) < φ.
-/
import CollatzLean.SFT
import Mathlib.Data.Nat.Fib.Basic
import Mathlib.Analysis.SpecialFunctions.Log.Base

set_option linter.style.nativeDecide false

open Real in
open scoped Real

namespace Collatz

/-! ## Avoid count: binary words of length n with no "11" -/

/-- Number of binary words of length n avoiding the bigram "11".
    Satisfies the Fibonacci recurrence: f(0)=1, f(1)=2, f(n+2)=f(n+1)+f(n). -/
def avoidCount : ℕ → ℕ
  | 0 => 1
  | 1 => 2
  | n + 2 => avoidCount (n + 1) + avoidCount n

/-! ## Relationship to Fibonacci numbers -/

/-- Strengthened induction: avoidCount n = fib(n+2) for all n. -/
private theorem avoidCount_eq_fib_pair (n : ℕ) :
    avoidCount n = Nat.fib (n + 2) ∧ avoidCount (n + 1) = Nat.fib (n + 3) := by
  induction n with
  | zero =>
    constructor
    · -- avoidCount 0 = 1 = fib 2
      native_decide
    · -- avoidCount 1 = 2 = fib 3
      native_decide
  | succ n ih =>
    obtain ⟨ih1, ih2⟩ := ih
    refine ⟨ih2, ?_⟩
    -- avoidCount (n + 2) = avoidCount (n + 1) + avoidCount n = fib (n+3) + fib (n+2) = fib (n+4)
    change avoidCount (n + 2) = Nat.fib (n + 4)
    have hdef : avoidCount (n + 2) = avoidCount (n + 1) + avoidCount n := rfl
    rw [hdef, ih2, ih1, Nat.add_comm (Nat.fib (n + 3))]
    exact (@Nat.fib_add_two (n + 2)).symm

theorem avoidCount_eq_fib (n : ℕ) : avoidCount n = Nat.fib (n + 2) :=
  (avoidCount_eq_fib_pair n).1

/-! ## Small verifications -/

theorem avoidCount_zero : avoidCount 0 = 1 := rfl
theorem avoidCount_one : avoidCount 1 = 2 := rfl
theorem avoidCount_two : avoidCount 2 = 3 := rfl
theorem avoidCount_three : avoidCount 3 = 5 := rfl
theorem avoidCount_four : avoidCount 4 = 8 := rfl
theorem avoidCount_five : avoidCount 5 = 13 := rfl

#eval (List.range 8).map avoidCount  -- [1, 2, 3, 5, 8, 13, 21, 34]

/-! ## The key inequality: log₂(3) < φ -/

/-- log₂(3) < 8/5, via 3⁵ = 243 < 256 = 2⁸. -/
theorem logb_two_three_lt : Real.logb 2 3 < 8 / 5 := by
  have hlog2_pos : (0 : ℝ) < Real.log 2 := Real.log_pos (by norm_num : (1 : ℝ) < 2)
  rw [Real.logb, div_lt_div_iff₀ hlog2_pos (by norm_num : (0 : ℝ) < 5)]
  -- Goal: Real.log 3 * 5 < 8 * Real.log 2
  have lhs : Real.log 3 * 5 = Real.log ((3 : ℝ) ^ 5) := by
    rw [Real.log_pow]; ring
  have rhs : 8 * Real.log 2 = Real.log ((2 : ℝ) ^ 8) := by
    rw [Real.log_pow]; ring
  rw [lhs, rhs]
  exact Real.log_lt_log (by positivity) (by norm_num)

/-- 8/5 < φ, via (11/5)² = 121/25 < 5 = (√5)². -/
theorem eight_fifths_lt_goldenRatio : (8 : ℝ) / 5 < (1 + Real.sqrt 5) / 2 := by
  suffices h : 11 / 5 < Real.sqrt 5 by linarith
  have hsq : Real.sqrt 5 ^ 2 = 5 := Real.sq_sqrt (by norm_num : (0 : ℝ) ≤ 5)
  exact lt_of_pow_lt_pow_left₀ 2 (Real.sqrt_nonneg 5) (by rw [hsq]; norm_num)

/-- log₂(3) < φ (the golden ratio). -/
theorem log2_three_lt_goldenRatio : Real.logb 2 3 < (1 + Real.sqrt 5) / 2 :=
  calc Real.logb 2 3 < 8 / 5 := logb_two_three_lt
    _ < (1 + Real.sqrt 5) / 2 := eight_fifths_lt_goldenRatio

/-! ## Entropy and density (sorry — require substantial Mathlib extensions) -/

/-- The topological entropy of the golden mean shift is log φ.
    Proof requires: lim_{n→∞} log(fib n)/n = log φ (real analysis). -/
theorem goldenMean_entropy :
    Filter.Tendsto (fun n => Real.log (avoidCount n) / n) Filter.atTop
      (nhds (Real.log ((1 + Real.sqrt 5) / 2))) := by
  sorry

/-- Under the measure of maximal entropy on the golden mean shift,
    the maximum density of 1s (odd steps) is 1/φ² = (3 - √5)/2. -/
theorem goldenMean_max_p_odd :
    (1 : ℝ) / ((1 + Real.sqrt 5) / 2) ^ 2 = (3 - Real.sqrt 5) / 2 := by
  have h5 : Real.sqrt 5 ^ 2 = 5 := Real.sq_sqrt (by norm_num : (0 : ℝ) ≤ 5)
  have h5_3 : Real.sqrt 5 ^ 3 = 5 * Real.sqrt 5 := by
    have : Real.sqrt 5 ^ 3 = Real.sqrt 5 ^ 2 * Real.sqrt 5 := by ring
    rw [this, h5]
  have hpos : (0 : ℝ) < 1 + Real.sqrt 5 := by positivity
  field_simp
  nlinarith [h5, h5_3]

/-! ## Evaluation -/

#eval avoidCount 10   -- 144 = fib 12
#eval Nat.fib 12      -- 144

end Collatz
