/-
  CollatzLean/Baker.lean
  Baker's theorem foundations for α₁ = 2, α₂ = 3:
  multiplicative independence, irrationality of log₂(3),
  linear form nonvanishing, and the Gel'fond–Schneider proof chain (sorry'd).
-/
import Mathlib.Analysis.SpecialFunctions.Log.Base
import Mathlib.Data.Nat.Prime.Basic
import Mathlib.NumberTheory.Real.Irrational

set_option linter.style.nativeDecide false

namespace Collatz

open Real

/-! ## Linear form in logarithms -/

/-- The linear form m · log 2 + n · log 3. -/
noncomputable def linearFormLog (m n : ℤ) : ℝ :=
  m * Real.log 2 + n * Real.log 3

/-! ## Multiplicative independence of 2 and 3 -/

/-- 2 and 3 are multiplicatively independent: 2^m = 3^n implies m = 0 ∧ n = 0. -/
theorem multIndep_two_three (m n : ℕ) (h : 2 ^ m = 3 ^ n) : m = 0 ∧ n = 0 := by
  by_cases hm : m = 0
  · constructor
    · exact hm
    · subst hm; simp at h
      by_contra hn
      have : 3 ^ n ≥ 3 := le_self_pow₀ (by norm_num : 3 ≥ 1) hn
      omega
  · exfalso
    have h2_dvd : 2 ∣ 2 ^ m := dvd_pow_self 2 hm
    rw [h] at h2_dvd
    have : 2 ∣ 3 := Nat.Prime.dvd_of_dvd_pow Nat.prime_two h2_dvd
    omega

/-- Integer version: 2^m = 3^n (with m, n : ℤ, m ≥ 0, n ≥ 0) implies m = 0 ∧ n = 0. -/
theorem multIndep_two_three_int (m n : ℤ) (hm : 0 ≤ m) (hn : 0 ≤ n)
    (h : (2 : ℤ) ^ m.toNat = (3 : ℤ) ^ n.toNat) : m = 0 ∧ n = 0 := by
  have h' : (2 : ℕ) ^ m.toNat = (3 : ℕ) ^ n.toNat := by exact_mod_cast h
  have ⟨hm0, hn0⟩ := multIndep_two_three _ _ h'
  constructor <;> omega

/-! ## Irrationality of log₂(3) -/

/-- log₂(3) is irrational. -/
theorem irrational_logb_two_three : Irrational (logb 2 3) := by
  rw [irrational_iff_ne_rational]
  intro a b hb hab
  have hlog2_pos : Real.log 2 > 0 := Real.log_pos (by norm_num)
  have hlog3_pos : Real.log 3 > 0 := Real.log_pos (by norm_num)
  have hlog2_ne : Real.log 2 ≠ 0 := ne_of_gt hlog2_pos
  have hb_cast : (b : ℝ) ≠ 0 := Int.cast_ne_zero.mpr hb
  -- Cross-multiply: logb 2 3 = log 3 / log 2 = a / b → a * log 2 = b * log 3
  have hcross : (a : ℝ) * Real.log 2 = (b : ℝ) * Real.log 3 := by
    unfold logb at hab
    have := (div_eq_div_iff hlog2_ne hb_cast).mp hab
    linarith
  -- Take abs of both sides: |a| * log 2 = |b| * log 3
  have habs : |(a : ℝ)| * Real.log 2 = |(b : ℝ)| * Real.log 3 := by
    have := congr_arg abs hcross
    rwa [abs_mul, abs_mul, abs_of_pos hlog2_pos, abs_of_pos hlog3_pos] at this
  -- (a.natAbs : ℝ) = |(a : ℝ)| and same for b
  have ha_abs : (a.natAbs : ℝ) = |(a : ℝ)| := by
    rw [Nat.cast_natAbs, Int.cast_abs]
  have hb_abs : (b.natAbs : ℝ) = |(b : ℝ)| := by
    rw [Nat.cast_natAbs, Int.cast_abs]
  -- natAbs versions: a.natAbs * log 2 = b.natAbs * log 3
  have hnat_cross : (a.natAbs : ℝ) * Real.log 2 = (b.natAbs : ℝ) * Real.log 3 := by
    rw [ha_abs, hb_abs]; exact habs
  -- log(2^a.natAbs) = log(3^b.natAbs)
  have hlog_eq : Real.log ((2 : ℝ) ^ a.natAbs) = Real.log ((3 : ℝ) ^ b.natAbs) := by
    rw [Real.log_pow, Real.log_pow]; linarith
  -- Both sides > 0, so by injectivity of log
  have hpow_eq : (2 : ℝ) ^ a.natAbs = (3 : ℝ) ^ b.natAbs :=
    Real.log_injOn_pos (Set.mem_Ioi.mpr (by positivity)) (Set.mem_Ioi.mpr (by positivity)) hlog_eq
  -- Cast to ℕ
  have hpow_nat : 2 ^ a.natAbs = 3 ^ b.natAbs := by exact_mod_cast hpow_eq
  -- Multiplicative independence: a.natAbs = 0 ∧ b.natAbs = 0
  have ⟨_, hbn⟩ := multIndep_two_three _ _ hpow_nat
  -- b.natAbs = 0 → b = 0, contradicting hb
  exact hb (Int.natAbs_eq_zero.mp hbn)

/-! ## Linear form nonvanishing -/

/-- If (m, n) ≠ (0, 0), then m · log 2 + n · log 3 ≠ 0. -/
theorem linear_form_nonzero (m n : ℤ) (hmn : m ≠ 0 ∨ n ≠ 0) :
    linearFormLog m n ≠ 0 := by
  unfold linearFormLog
  have hlog2_pos : Real.log 2 > 0 := Real.log_pos (by norm_num)
  have hlog3_pos : Real.log 3 > 0 := Real.log_pos (by norm_num)
  intro heq
  -- heq : ↑m * log 2 + ↑n * log 3 = 0
  by_cases hn : n = 0
  · -- n = 0: m * log 2 = 0, but log 2 > 0 and m ≠ 0
    have hm : m ≠ 0 := hmn.resolve_right (not_not.mpr hn)
    have hn_cast : (n : ℝ) = 0 := Int.cast_eq_zero.mpr hn
    have hn_term : (n : ℝ) * Real.log 3 = 0 := by rw [hn_cast, zero_mul]
    have hmlog : (m : ℝ) * Real.log 2 = 0 := by linarith
    rcases mul_eq_zero.mp hmlog with hm0 | hlog0
    · exact hm (Int.cast_eq_zero.mp hm0)
    · exact ne_of_gt hlog2_pos hlog0
  · by_cases hm : m = 0
    · -- m = 0: n * log 3 = 0, but log 3 > 0 and n ≠ 0
      have hm_cast : (m : ℝ) = 0 := Int.cast_eq_zero.mpr hm
      have hm_term : (m : ℝ) * Real.log 2 = 0 := by rw [hm_cast, zero_mul]
      have hnlog : (n : ℝ) * Real.log 3 = 0 := by linarith
      rcases mul_eq_zero.mp hnlog with hn0 | hlog0
      · exact hn (Int.cast_eq_zero.mp hn0)
      · exact ne_of_gt hlog3_pos hlog0
    · -- Both nonzero: logb 2 3 = (-m)/n, contradicting irrationality
      have hlogb_eq : logb 2 3 = (↑(-m) : ℝ) / ↑n := by
        unfold logb
        rw [div_eq_div_iff (ne_of_gt hlog2_pos) (Int.cast_ne_zero.mpr hn)]
        push_cast; linarith
      exact irrational_logb_two_three.ne_rational (-m) n hlogb_eq

/-! ## Baker proof chain (sorry'd stubs) -/

/-- Siegel's lemma: auxiliary polynomial with small coefficients.
    Stub — to be filled with proper polynomial ring types. -/
theorem baker_aux_construction (m n : ℤ) (hm : m ≠ 0) (hn : n ≠ 0) :
    ∃ (P : ℤ → ℤ → ℤ) (_hP : P 0 0 ≠ 0),
      ∀ i j : ℤ, |P i j| ≤ max |m| |n| := by
  sorry

/-- Schwarz lemma + analytic continuation extends vanishing.
    Stub — needs complex analysis foundations. -/
theorem baker_extrapolation (m n : ℤ) (hm : m ≠ 0) (hn : n ≠ 0)
    (P : ℤ → ℤ → ℤ) (_hP : P 0 0 ≠ 0)
    (_hbound : ∀ i j : ℤ, |P i j| ≤ max |m| |n|) :
    ∃ S : Finset (ℤ × ℤ), S.card ≥ |m| ∧
      ∀ p ∈ S, P p.1 p.2 = 0 := by
  sorry

/-- Interpolation determinant ≠ 0 by multiplicative independence.
    Stub — needs linear algebra over ℤ. -/
theorem baker_zero_estimate (m n : ℤ) (hm : m ≠ 0) (hn : n ≠ 0)
    (S : Finset (ℤ × ℤ)) (hS : S.card ≥ |m|) :
    ∃ C : ℝ, C > 0 ∧ |linearFormLog m n| ≥ C / (max |m| |n| : ℝ) ^ (S.card : ℝ) := by
  sorry

/-- Combines aux_construction + extrapolation + zero_estimate. -/
theorem baker_effective_bound (m n : ℤ) (hm : m ≠ 0) (hn : n ≠ 0) :
    ∃ C : ℝ, C > 0 ∧
      |linearFormLog m n| ≥ C / (max |m| |n| : ℝ) ^ (2 + 1) := by
  sorry

/-- Main Baker inequality for α₁ = 2, α₂ = 3:
    |m · log 2 + n · log 3| > C / max(|m|,|n|)^κ for effective C, κ. -/
theorem baker_two_three :
    ∃ (C : ℝ) (κ : ℝ), C > 0 ∧ κ > 0 ∧
      ∀ m n : ℤ, m ≠ 0 ∨ n ≠ 0 →
        |linearFormLog m n| > C / (max |m| |n| : ℝ) ^ κ := by
  sorry

/-! ## Cycle elimination (Baker-Steiner) -/

/-- The Collatz step function (standalone definition for Baker-level results,
    avoiding import dependencies on CollatzLean.Basic). -/
def collatzStep (n : ℕ) : ℕ :=
  if n = 0 then 0
  else if n % 2 = 0 then n / 2
  else 3 * n + 1

/-- Baker-Steiner cycle theorem: no non-trivial Collatz cycle has period
    p = 3·Δ₃ for any Δ₃ ≥ 2. Any such cycle must contain 1.

    Proof requires Baker's theorem lower bound on |m·log 2 + n·log 3|
    combined with Steiner-type analysis of the cycle equation
    c₀·(4^Δ₃ - 3^Δ₃) = Σ 3^{Δ₃-j}·2^{e_j} and computational
    verification for small Δ₃.

    References: Steiner (1977), Simons & de Weger (2005). -/
theorem baker_no_balanced_cycle (Δ₃ : ℕ) (hΔ : Δ₃ ≥ 2)
    (c₀ : ℕ) (hc : c₀ ≥ 1)
    (hcycle : collatzStep^[3 * Δ₃] c₀ = c₀) :
    ∃ t, t < 3 * Δ₃ ∧ collatzStep^[t] c₀ = 1 := by
  sorry

/-! ## Evaluation -/

-- Verify 2^m ≠ 3^n for small m, n (except m = n = 0)
#eval (List.range 10).all fun m => (List.range 10).all fun n =>
  m == 0 && n == 0 || 2 ^ m != 3 ^ n

end Collatz
