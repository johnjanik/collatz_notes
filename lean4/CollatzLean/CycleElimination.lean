/-
  CollatzLean/CycleElimination.lean

  Cycle elimination via the Rhin irrationality measure.

  Architecture: Baker.lean's `cycle_no_nontrivial_solution` sorry says that
  no c₀ ≥ 2 satisfies the Steiner cycle equation. IrrationalityMeasure.lean
  provides `linearFormLog_lower_bound_of_rhin`, a polynomial lower bound
  on |ν₂·log 2 - ν₃·log 3|. This file connects them:

  LOWER BOUND (from Rhin):
    |Λ| = |ν₂·log 2 - ν₃·log 3| > C·log2 / ν₃⁵    (polynomial in ν₃)

  UPPER BOUND (from cycle equation):
    2^ν₂ = 3^ν₃ · (1 + corr/(c₀·3^ν₃))
    ⟹ Λ = log(1 + corr/(c₀·3^ν₃)) < corr/(c₀·3^ν₃)
    ⟹ Λ < (2^ν₂ - 3^ν₃)/3^ν₃                        (exponential decay)

  CONTRADICTION: polynomial > exponential is impossible for large ν₃.
  Small ν₃ cases (ν₃ ≤ threshold) are eliminated computationally.

  References:
  - Steiner (1977), cycle equation structure
  - Simons & de Weger (2005), computational cycle elimination
  - Hercher (2024), extended computations using irrationality measures
-/
import CollatzLean.Baker
import CollatzLean.IrrationalityMeasure

namespace Collatz

open Real

/-! ## The linear form from cycle parameters -/

/-- The linear form Λ = ν₂·log 2 - ν₃·log 3, expressed via linearFormLog.
    For a cycle with ν₂ even steps and ν₃ odd steps, this measures how close
    the ratio ν₂/ν₃ is to log₂3 ≈ 1.585. -/
noncomputable def cycleLinearForm (c₀ p : ℕ) : ℝ :=
  linearFormLog (cycleNu2 c₀ p : ℤ) (-(cycleNu3 c₀ p : ℤ))

/-- The cycle linear form equals ν₂·log 2 - ν₃·log 3. -/
theorem cycleLinearForm_eq (c₀ p : ℕ) :
    cycleLinearForm c₀ p =
      (cycleNu2 c₀ p : ℝ) * Real.log 2 - (cycleNu3 c₀ p : ℝ) * Real.log 3 := by
  unfold cycleLinearForm linearFormLog
  push_cast
  ring

/-! ## Lower bound from Rhin -/

/-- The Rhin irrationality measure gives a polynomial lower bound on the
    cycle linear form. For ν₃ ≥ 1:
      |Λ| > ν₃ · log 2 · C / ν₃^6
    which simplifies to C · log 2 / ν₃^5.

    This is the key "transcendence input" — the linear form cannot be
    too close to zero because log₂3 is not well-approximable by rationals. -/
theorem cycle_lower_bound :
    ∃ (C : ℝ), C > 0 ∧
      ∀ (c₀ p : ℕ), cycleNu3 c₀ p ≥ 1 →
        |cycleLinearForm c₀ p| >
          ↑(cycleNu3 c₀ p) * Real.log 2 * (C / (↑(cycleNu3 c₀ p) : ℝ) ^ 6) := by
  obtain ⟨C, hC, hbound⟩ := linearFormLog_lower_bound_of_rhin
  exact ⟨C, hC, fun c₀ p hν₃ => by
    unfold cycleLinearForm
    have hν₃_neg : (-(cycleNu3 c₀ p : ℤ)) < 0 := by omega
    have h := hbound (cycleNu2 c₀ p : ℤ) (-(cycleNu3 c₀ p : ℤ)) hν₃_neg
    simp only [neg_neg, Int.cast_natCast] at h
    exact h⟩

/-! ## Upper bound from cycle equation -/

/-- Upper bound on the linear form from the cycle equation.

    From the cycle identity c₀ · 2^ν₂ = c₀ · 3^ν₃ + correction, periodicity
    gives 2^ν₂/3^ν₃ = 1 + corr/(c₀ · 3^ν₃), so
    Λ = ν₂·log 2 - ν₃·log 3 = log(2^ν₂/3^ν₃) = log(1 + corr/(c₀·3^ν₃)).

    Since log(1+x) < x for x > 0, we get Λ < corr/(c₀·3^ν₃).
    Using the cycle equation corr = c₀·(2^ν₂ - 3^ν₃):
    Λ < (2^ν₂ - 3^ν₃)/3^ν₃

    This exponential upper bound (which shrinks as 3^{-ν₃} · something)
    will contradict the polynomial lower bound from Rhin for large ν₃.

    The proof requires passage between ℕ arithmetic (cycle_equation)
    and ℝ analysis (log, exp). This is the analytically non-trivial step. -/
theorem cycle_upper_bound (c₀ p : ℕ)
    (hc : c₀ ≥ 2)
    (hcycle : collatzStep^[p] c₀ = c₀)
    (hν₃ : cycleNu3 c₀ p ≥ 1)
    (hexp : 2 ^ cycleNu2 c₀ p > 3 ^ cycleNu3 c₀ p) :
    cycleLinearForm c₀ p <
      ((2 : ℝ) ^ cycleNu2 c₀ p - (3 : ℝ) ^ cycleNu3 c₀ p) /
        (3 : ℝ) ^ cycleNu3 c₀ p := by
  rw [cycleLinearForm_eq]
  -- Positivity facts
  have h3pos : (0 : ℝ) < (3 : ℝ) ^ cycleNu3 c₀ p := by positivity
  have h2pos : (0 : ℝ) < (2 : ℝ) ^ cycleNu2 c₀ p := by positivity
  have h3ne : (3 : ℝ) ^ cycleNu3 c₀ p ≠ 0 := ne_of_gt h3pos
  have h2ne : (2 : ℝ) ^ cycleNu2 c₀ p ≠ 0 := ne_of_gt h2pos
  -- Rewrite LHS as log(2^ν₂ / 3^ν₃)
  have hlhs : (↑(cycleNu2 c₀ p) : ℝ) * Real.log 2 - (↑(cycleNu3 c₀ p) : ℝ) * Real.log 3 =
      Real.log ((2 : ℝ) ^ cycleNu2 c₀ p / (3 : ℝ) ^ cycleNu3 c₀ p) := by
    rw [Real.log_div h2ne h3ne, Real.log_pow, Real.log_pow]
  rw [hlhs]
  -- Set x = 2^ν₂ / 3^ν₃, show x > 1
  set x := (2 : ℝ) ^ cycleNu2 c₀ p / (3 : ℝ) ^ cycleNu3 c₀ p with hx_def
  have hx_pos : 0 < x := div_pos h2pos h3pos
  have hx_gt1 : x > 1 := by
    rw [hx_def, gt_iff_lt, one_lt_div h3pos]
    exact_mod_cast hexp
  -- log(x) < x - 1 for x > 0, x ≠ 1
  have hlog_lt := Real.log_lt_sub_one_of_pos hx_pos (ne_of_gt hx_gt1)
  -- x - 1 = (2^ν₂ - 3^ν₃) / 3^ν₃
  have hx_sub : x - 1 = ((2 : ℝ) ^ cycleNu2 c₀ p - (3 : ℝ) ^ cycleNu3 c₀ p) /
      (3 : ℝ) ^ cycleNu3 c₀ p := by
    rw [hx_def, div_sub_one h3ne]
  linarith

/-! ## Positivity of cycle linear form -/

/-- The cycle linear form is positive when 2^ν₂ > 3^ν₃. -/
theorem cycleLinearForm_pos (c₀ p : ℕ)
    (hexp : 2 ^ cycleNu2 c₀ p > 3 ^ cycleNu3 c₀ p) :
    cycleLinearForm c₀ p > 0 := by
  rw [cycleLinearForm_eq]
  have hlog2 : Real.log 2 > 0 := Real.log_pos (by norm_num)
  have hlog3 : Real.log 3 > 0 := Real.log_pos (by norm_num)
  -- 2^ν₂ > 3^ν₃ implies ν₂·log 2 > ν₃·log 3 (since log is monotone)
  have h2 : Real.log ((2 : ℝ) ^ cycleNu2 c₀ p) >
             Real.log ((3 : ℝ) ^ cycleNu3 c₀ p) := by
    apply Real.log_lt_log
    · positivity
    · exact_mod_cast hexp
  rw [Real.log_pow, Real.log_pow] at h2
  linarith

/-! ## Large ν₃ contradiction -/

/-- For sufficiently large ν₃, the polynomial lower bound from Rhin
    contradicts the exponential upper bound from the cycle equation.

    Specifically: C·log2/ν₃⁵ < (2^ν₂ - 3^ν₃)/3^ν₃ requires
    C·log2·3^ν₃ < ν₃⁵·(2^ν₂ - 3^ν₃).

    But 2^ν₂ < 2·3^ν₃ (from ν₂ < 2ν₃, which holds for any cycle with
    ν₃ ≥ 2 since log₂3 < 2), so the RHS grows polynomially in ν₃
    while the LHS grows exponentially — contradiction for large ν₃.

    This is sorry'd because the quantitative analysis requires careful
    bounds on ν₂/ν₃ and the exponential-polynomial comparison. -/
theorem cycle_large_nu3_contradiction (c₀ p : ℕ)
    (hc : c₀ ≥ 2)
    (hcycle : collatzStep^[p] c₀ = c₀)
    (hν₃ : cycleNu3 c₀ p ≥ 1)
    (hexp : 2 ^ cycleNu2 c₀ p > 3 ^ cycleNu3 c₀ p)
    (hceq : c₀ * (2 ^ cycleNu2 c₀ p - 3 ^ cycleNu3 c₀ p) = cycleCorrection c₀ p)
    (hlarge : cycleNu3 c₀ p ≥ 68) :
    False := by
  sorry

/-! ## Small ν₃ computational elimination -/

/-- For small ν₃ (say ν₃ < 68), computational verification shows that
    no non-trivial cycle exists. This uses the fact that the cycle equation
    c₀ · (2^ν₂ - 3^ν₃) = correction, combined with the constraint
    ν₂ + ν₃ = p and the structure of the correction sum, leaves no
    solutions with c₀ ≥ 2.

    The threshold 68 comes from Steiner's original analysis, later
    extended by Simons & de Weger (2005) to ν₃ < 68 and further by
    Hercher (2024). In principle this could be replaced by native_decide
    for small cases, but the correction term structure makes direct
    computation complex.

    This is sorry'd as computational verification of cycle nonexistence
    for small parameters. -/
theorem cycle_small_nu3_elim (c₀ p : ℕ)
    (hc : c₀ ≥ 2)
    (hcycle : collatzStep^[p] c₀ = c₀)
    (hν₃ : cycleNu3 c₀ p ≥ 1)
    (hexp : 2 ^ cycleNu2 c₀ p > 3 ^ cycleNu3 c₀ p)
    (hceq : c₀ * (2 ^ cycleNu2 c₀ p - 3 ^ cycleNu3 c₀ p) = cycleCorrection c₀ p)
    (hsmall : cycleNu3 c₀ p < 68) :
    ∃ t, t < p ∧ collatzStep^[t] c₀ = 1 := by
  sorry

/-! ## Main theorem: cycle elimination from Rhin bound -/

/-- Cycle elimination via Rhin's irrationality measure.

    No non-trivial Collatz cycle exists with period p = 3·Δ₃ for Δ₃ ≥ 2.
    Any such cycle must pass through 1.

    This is the same conclusion as Baker.lean's `baker_no_balanced_cycle`,
    but with a sharper decomposition of the sorry into two focused gaps:
    1. `cycle_large_nu3_contradiction`: exponential-polynomial comparison
    2. `cycle_small_nu3_elim`: computational verification for small ν₃

    The proof structure:
    - From periodicity, derive c₀ ≥ 2 (or c₀ = 1, done) and ν₃ ≥ 1
    - Establish 2^ν₂ > 3^ν₃ and the cycle equation
    - Case split: ν₃ ≥ 68 (large, Rhin contradiction) vs ν₃ < 68 (small, computation) -/
theorem cycle_elim_from_rhin (Δ₃ : ℕ) (hΔ : Δ₃ ≥ 2)
    (c₀ : ℕ) (hc : c₀ ≥ 1)
    (hcycle : collatzStep^[3 * Δ₃] c₀ = c₀) :
    ∃ t, t < 3 * Δ₃ ∧ collatzStep^[t] c₀ = 1 := by
  -- Trivial case: c₀ = 1
  by_cases hc1 : c₀ = 1
  · exact ⟨0, by omega, by simp [hc1]⟩
  -- Nontrivial: c₀ ≥ 2
  have hc2 : c₀ ≥ 2 := by omega
  set p := 3 * Δ₃ with hp
  -- At least one odd step
  have hν₃ : cycleNu3 c₀ p ≥ 1 := by
    by_contra hlt
    push_neg at hlt
    have hv3 : cycleNu3 c₀ p = 0 := by omega
    have hcorr0 := correction_zero_of_nu3_zero c₀ p hv3
    have hnu2 : cycleNu2 c₀ p = p := by unfold cycleNu2; omega
    have hident := cycle_identity c₀ p
    rw [hcycle, hv3, hcorr0, hnu2] at hident; simp at hident
    have h2p : 2 ≤ 2 ^ p := by
      change 2 ^ 1 ≤ 2 ^ p
      apply Nat.pow_le_pow_right <;> omega
    linarith [Nat.mul_le_mul_left c₀ h2p]
  -- Exponent ordering: 2^ν₂ > 3^ν₃
  have hexp : 2 ^ cycleNu2 c₀ p > 3 ^ cycleNu3 c₀ p := by
    by_contra hle
    push_neg at hle
    have hident := cycle_identity c₀ p
    rw [hcycle] at hident
    have hcorr_pos := cycleCorrection_pos c₀ p hν₃
    have := Nat.mul_le_mul_left c₀ hle
    omega
  -- Cycle equation
  have hceq := cycle_equation c₀ p hcycle hexp
  -- Case split on ν₃
  by_cases hlarge : cycleNu3 c₀ p ≥ 68
  · -- Large ν₃: Rhin bound contradicts cycle equation
    exact absurd (cycle_large_nu3_contradiction c₀ p hc2 hcycle hν₃ hexp hceq hlarge) id
  · -- Small ν₃: computational elimination
    push_neg at hlarge
    exact cycle_small_nu3_elim c₀ p hc2 hcycle hν₃ hexp hceq hlarge

end Collatz
