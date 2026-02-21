/-
  CollatzLean/DistancePowers.lean
  Effective lower bounds for |α^m - β^n| via Baker's theorem.

  Main result (Theorem 63 in the Diophantine taxonomy):
  The distance |2^m - 3^n| grows effectively — it cannot be made
  arbitrarily small relative to the magnitudes of the powers.

  Architecture:
  - BakerBound structure (generalized interface for Baker-type bounds)
  - baker_gap_log2_log3: effective bound on |m·log 2 - n·log 3|
  - distance_powers_lower_bound: the main theorem
  - Concrete small cases (music theory / equal temperament)

  References:
  - A. Baker, "Transcendental Number Theory", Cambridge, 1975.
  - M. Laurent, M. Mignotte, Yu. Nesterenko, "Formes linéaires en deux
    logarithmes et déterminants d'interpolation", J. Number Theory 55
    (1995), 285–321.
-/
import CollatzLean.Baker

set_option linter.style.nativeDecide false

namespace Collatz

open Real

/-! ## BakerBound: generalized interface for Baker-type lower bounds -/

/-- A Baker-type lower bound specification for a pair of real numbers.
    This is a Prop-valued predicate packaging the effective constants. -/
structure BakerBound (α₁ α₂ : ℝ) (C κ : ℝ) : Prop where
  hC : C > 0
  hκ : κ > 0
  hα₁ : α₁ > 0
  hα₂ : α₂ > 0
  bound : ∀ m n : ℤ, m ≠ 0 ∨ n ≠ 0 →
    |m * log α₁ + n * log α₂| > C / (max |m| |n| : ℝ) ^ κ

/-- Baker's theorem provides a BakerBound for (2, 3). -/
theorem bakerBound23 : ∃ C κ : ℝ, BakerBound 2 3 C κ := by
  obtain ⟨C, κ, hC, hκ, hbound⟩ := baker_two_three
  exact ⟨C, κ, hC, hκ, by norm_num, by norm_num, fun m n hmn => by
    have := hbound m n hmn; unfold linearFormLog at this; exact this⟩

/-! ## Effective gap: Baker bound on |m · log 2 - n · log 3| -/

/-- The linear form m · log 2 - n · log 3 is bounded below by C/max(m,n)^κ
    for effective constants C, κ > 0. This is the "raw" Baker bound. -/
theorem baker_gap_log2_log3 :
    ∃ (C : ℝ) (κ : ℝ), C > 0 ∧ κ > 0 ∧
      ∀ m n : ℕ, m ≥ 1 → n ≥ 1 →
        |(↑m : ℝ) * log 2 - (↑n : ℝ) * log 3| > C / (max (m : ℝ) (n : ℝ)) ^ κ := by
  obtain ⟨C, κ, hC, hκ, hbound⟩ := baker_two_three
  refine ⟨C, κ, hC, hκ, ?_⟩
  intro m n hm hn
  have hmn_ne : (m : ℤ) ≠ 0 ∨ (-(n : ℤ)) ≠ 0 := by left; omega
  have hb := hbound (m : ℤ) (-(n : ℤ)) hmn_ne
  unfold linearFormLog at hb
  -- Rewrite the linear form: ↑m * log 2 + ↑(-↑n) * log 3 = ↑m * log 2 - ↑n * log 3
  have hform : (↑(m : ℤ) : ℝ) * log 2 + (↑(-(n : ℤ)) : ℝ) * log 3 =
      (↑m : ℝ) * log 2 - (↑n : ℝ) * log 3 := by push_cast; ring
  rw [hform] at hb
  -- Rewrite the max: max |(m:ℤ)| |-(n:ℤ)| = max m n
  convert hb using 2
  have : |((m : ℤ) : ℝ)| = (m : ℝ) := abs_of_nonneg (Nat.cast_nonneg' m)
  have : |((-(n : ℤ) : ℤ) : ℝ)| = (n : ℝ) := by
    rw [Int.cast_neg, abs_neg]; exact abs_of_nonneg (Nat.cast_nonneg' n)
  simp only [*]

/-! ## Consequence: 2^m ≠ 3^n -/

/-- Powers of 2 and 3 are always distinct (from multiplicative independence). -/
theorem powers_two_three_ne (m n : ℕ) (hm : m ≥ 1) (_hn : n ≥ 1) :
    (2 : ℤ) ^ m ≠ (3 : ℤ) ^ n := by
  intro h
  have h' : (2 : ℕ) ^ m = (3 : ℕ) ^ n := by exact_mod_cast h
  have ⟨hm0, _⟩ := multIndep_two_three m n h'
  omega

/-- The integer distance |2^m - 3^n| is at least 1 for m, n ≥ 1. -/
theorem distance_powers_at_least_one (m n : ℕ) (hm : m ≥ 1) (hn : n ≥ 1) :
    1 ≤ |(2 : ℤ) ^ m - (3 : ℤ) ^ n| := by
  have hne := powers_two_three_ne m n hm hn
  exact Int.one_le_abs (sub_ne_zero.mpr hne)

/-! ## Main theorem: effective lower bound on |2^m - 3^n| -/

/-- **Distance between powers of 2 and 3** (Theorem 63).

    There exist universal constants C > 0 and κ > 0 such that for all m, n ≥ 1:

      |2^m - 3^n| > C · min(2^m, 3^n) / max(m, n)^κ

    Proof: Write 2^m - 3^n = 3^n · (exp(Λ) - 1) where Λ = m·log 2 - n·log 3.
    Baker gives |Λ| > C/max(m,n)^κ, and |exp(Λ) - 1| ≥ |Λ|/2 for |Λ| ≤ 1.
    For |Λ| large, the integer gap ≥ 1 suffices. -/
theorem distance_powers_lower_bound :
    ∃ (C : ℝ) (κ : ℝ), C > 0 ∧ κ > 0 ∧
      ∀ m n : ℕ, m ≥ 1 → n ≥ 1 →
        |(2 : ℝ) ^ m - (3 : ℝ) ^ n| >
          C * min ((2 : ℝ) ^ m) ((3 : ℝ) ^ n) / (max (m : ℝ) (n : ℝ)) ^ κ := by
  obtain ⟨C, κ, hC, hκ, hbaker⟩ := baker_gap_log2_log3
  refine ⟨C, κ, hC, hκ, ?_⟩
  intro m n hm hn
  have h2pos : (0 : ℝ) < 2 ^ m := pow_pos (by norm_num) m
  have h3pos : (0 : ℝ) < 3 ^ n := pow_pos (by norm_num) n
  have hmin_pos : 0 < min ((2 : ℝ) ^ m) ((3 : ℝ) ^ n) := lt_min h2pos h3pos
  -- They can't be equal
  have hne : (2 : ℝ) ^ m ≠ (3 : ℝ) ^ n := by
    intro heq
    have : (2 : ℕ) ^ m = (3 : ℕ) ^ n := by exact_mod_cast heq
    have := (multIndep_two_three m n this).1; omega
  -- Set Λ = m·log 2 - n·log 3
  set Λ := (↑m : ℝ) * log 2 - (↑n : ℝ) * log 3 with hΛ_def
  -- Baker: |Λ| > C / max(m,n)^κ
  have hΛ_baker : |Λ| > C / (max (↑m : ℝ) ↑n) ^ κ := hbaker m n hm hn
  -- Key intermediate: |2^m - 3^n| ≥ min(2^m, 3^n) · |Λ|
  suffices hsuff : |(2 : ℝ) ^ m - (3 : ℝ) ^ n| ≥ min ((2 : ℝ) ^ m) ((3 : ℝ) ^ n) * |Λ| by
    calc |(2 : ℝ) ^ m - (3 : ℝ) ^ n|
        ≥ min (2 ^ m) (3 ^ n) * |Λ| := hsuff
      _ > min (2 ^ m) (3 ^ n) * (C / (max ↑m ↑n) ^ κ) :=
          mul_lt_mul_of_pos_left hΛ_baker hmin_pos
      _ = C * min (2 ^ m) (3 ^ n) / (max ↑m ↑n) ^ κ := by ring
  -- Prove |2^m - 3^n| ≥ min(2^m, 3^n) · |Λ|
  -- Exp identities
  have h2exp : (2 : ℝ) ^ m = exp (↑m * log 2) := by
    have := log_pow (2 : ℝ) m; rw [← this, exp_log h2pos]
  have h3exp : (3 : ℝ) ^ n = exp (↑n * log 3) := by
    have := log_pow (3 : ℝ) n; rw [← this, exp_log h3pos]
  rcases lt_or_gt_of_ne hne with h | h
  · -- Case: 2^m < 3^n
    rw [abs_of_nonpos (sub_nonpos.mpr (le_of_lt h)), neg_sub,
        min_eq_left (le_of_lt h), abs_of_neg (show Λ < 0 by
          rw [hΛ_def]; nlinarith [log_lt_log h2pos h, log_pow (2 : ℝ) m, log_pow (3 : ℝ) n])]
    -- Goal: 3^n - 2^m ≥ 2^m * (-Λ)
    have hexp_ratio : (3 : ℝ) ^ n / (2 : ℝ) ^ m = exp (-Λ) := by
      rw [h3exp, h2exp, ← exp_sub]; congr 1; ring
    have hfactor : (3 : ℝ) ^ n - (2 : ℝ) ^ m =
        (2 : ℝ) ^ m * (exp (-Λ) - 1) := by
      rw [← hexp_ratio]; field_simp
    rw [hfactor]
    exact mul_le_mul_of_nonneg_left (by linarith [add_one_le_exp (-Λ)]) (le_of_lt h2pos)
  · -- Case: 2^m > 3^n
    rw [abs_of_pos (sub_pos.mpr h), min_eq_right (le_of_lt h),
        abs_of_pos (show Λ > 0 by
          rw [hΛ_def]; nlinarith [log_lt_log h3pos h, log_pow (2 : ℝ) m, log_pow (3 : ℝ) n])]
    -- Goal: 2^m - 3^n ≥ 3^n * Λ
    have hexp_ratio : (2 : ℝ) ^ m / (3 : ℝ) ^ n = exp Λ := by
      rw [h2exp, h3exp, ← exp_sub]
    have hfactor : (2 : ℝ) ^ m - (3 : ℝ) ^ n =
        (3 : ℝ) ^ n * (exp Λ - 1) := by
      rw [← hexp_ratio]; field_simp
    rw [hfactor]
    exact mul_le_mul_of_nonneg_left (by linarith [add_one_le_exp Λ]) (le_of_lt h3pos)

/-! ## Concrete small cases: the music theory of 2 and 3

    The distances |2^m - 3^n| for small m, n encode the fundamental intervals
    of Western music theory. The closeness of 2^m to 3^n determines the quality
    of temperament systems.

    Key convergents of log₂3 ≈ 1.58496:
    - 3/2 = 1.500 (the perfect fifth)
    - 8/5 = 1.600 (Pythagorean limma)
    - 19/12 = 1.5833 (12-tone equal temperament)
    - 65/41 = 1.58536
    - 84/53 = 1.58490 (Mercator's 53-tone system)
-/

/-- 2^1 - 3^1 = -1, distance = 1. -/
theorem distance_2_3 : |2 ^ 1 - 3 ^ 1| = (1 : ℤ) := by native_decide

/-- 2^2 - 3^1 = 1, distance = 1. -/
theorem distance_4_3 : |2 ^ 2 - 3 ^ 1| = (1 : ℤ) := by native_decide

/-- 2^3 - 3^2 = -1, distance = 1. The famous 8 vs 9 (Pythagorean whole tone). -/
theorem distance_8_9 : |2 ^ 3 - 3 ^ 2| = (1 : ℤ) := by native_decide

/-- 2^8 - 3^5 = 256 - 243 = 13. The Pythagorean limma. -/
theorem distance_256_243 : |2 ^ 8 - 3 ^ 5| = (13 : ℤ) := by native_decide

/-- 2^19 - 3^12 = 524288 - 531441 = -7153. The Pythagorean comma.
    19/12 = 1.5833... is a convergent of log₂3 = 1.58496... -/
theorem distance_2_19_3_12 : |2 ^ 19 - 3 ^ 12| = (7153 : ℤ) := by native_decide

/-- 3^53 > 2^84: the close approach from convergent 84/53 of log₂3. -/
theorem powers_3_53_gt_2_84 : (3 : ℤ) ^ 53 > 2 ^ 84 := by native_decide

/-- The distance |2^84 - 3^53| for the notable convergent 84/53.
    This is a famously close pair: |2^84 - 3^53| / 3^53 ≈ 5.7 × 10^{-14}. -/
theorem distance_2_84_3_53 :
    |2 ^ 84 - (3 : ℤ) ^ 53| = 40432553845953101497907 := by native_decide

/-! ## Approximation quality of convergents to log₂3 -/

/-- Baker's theorem applied to rational approximations of log₂3.
    For any p, q ≥ 1, |p/q - log₂3| > C / max(p,q)^κ.

    The proof uses: |p/q - log₂3| = |p·log 2 - q·log 3| / (q · log 2),
    and baker_gap_log2_log3 bounds the numerator. -/
theorem logb3_approx_quality :
    ∃ (C : ℝ) (κ : ℝ), C > 0 ∧ κ > 0 ∧
      ∀ p q : ℕ, p ≥ 1 → q ≥ 1 →
        |(↑p : ℝ) / (↑q : ℝ) - logb 2 3| > C / (max (p : ℝ) (q : ℝ)) ^ κ := by
  obtain ⟨C, κ, hC, hκ, hbaker⟩ := baker_gap_log2_log3
  refine ⟨C / log 2, κ + 1, div_pos hC (log_pos (by norm_num)), by linarith, ?_⟩
  intro p q hp hq
  have hlog2 : (0 : ℝ) < log 2 := log_pos (by norm_num)
  have hq_pos : (0 : ℝ) < (q : ℝ) := Nat.cast_pos.mpr (by omega)
  have hmax_pos : (0 : ℝ) < max (p : ℝ) (q : ℝ) :=
    lt_of_lt_of_le hq_pos (le_max_right _ _)
  have hmax_rpow_pos : (0 : ℝ) < (max (p : ℝ) (q : ℝ)) ^ κ :=
    rpow_pos_of_pos hmax_pos _
  have hqlog2 : (0 : ℝ) < ↑q * log 2 := mul_pos hq_pos hlog2
  have hmlog2 : (0 : ℝ) < max (↑p : ℝ) ↑q * log 2 := mul_pos hmax_pos hlog2
  have hCdiv_pos : (0 : ℝ) < C / (max (↑p : ℝ) ↑q) ^ κ := div_pos hC hmax_rpow_pos
  have hb := hbaker p q hp hq
  -- Identity: p/q - logb 2 3 = (p·log 2 - q·log 3) / (q · log 2)
  have hid : (↑p : ℝ) / (↑q : ℝ) - logb 2 3 =
    ((↑p : ℝ) * log 2 - (↑q : ℝ) * log 3) / ((↑q : ℝ) * log 2) := by
    unfold logb; field_simp
  rw [hid, abs_div, abs_of_pos hqlog2]
  -- Step 1: Baker bound → numerator bound
  have h1 : C / (max ↑p ↑q) ^ κ / (↑q * log 2) <
    |↑p * log 2 - ↑q * log 3| / (↑q * log 2) :=
    div_lt_div_of_pos_right hb hqlog2
  -- Step 2: q ≤ max → denominator weakening
  have hqdenom : ↑q * log 2 ≤ max (↑p : ℝ) ↑q * log 2 :=
    mul_le_mul_of_nonneg_right (le_max_right _ _) (le_of_lt hlog2)
  have h2 : C / (max ↑p ↑q) ^ κ / (max ↑p ↑q * log 2) ≤
    C / (max ↑p ↑q) ^ κ / (↑q * log 2) :=
    div_le_div_of_nonneg_left (le_of_lt hCdiv_pos) hqlog2 hqdenom
  -- Step 3: Algebra — C/max^κ/(max·log 2) = C/log 2/max^(κ+1)
  have h3 : C / log 2 / (max (↑p : ℝ) ↑q) ^ (κ + 1) =
    C / (max ↑p ↑q) ^ κ / (max ↑p ↑q * log 2) := by
    rw [rpow_add_one (ne_of_gt hmax_pos)]
    field_simp [ne_of_gt hmax_pos, ne_of_gt hlog2, ne_of_gt hmax_rpow_pos]
  linarith

/-! ## Connection to equal temperament -/

/-- The 12-tone equal temperament system approximates the perfect fifth (3/2)
    by 2^(7/12). The quality of this approximation is governed by Baker's
    theorem applied to the convergent 19/12 of log₂3.

    Proved via: 2^19 < 3^12 (i.e., 524288 < 531441), so 2^(19/12) < 3,
    hence 19/12 < log₂3, and the error is nonzero. -/
theorem equal_temperament_error :
    logb 2 3 > 19 / 12 := by
  -- log₂3 > 19/12 ↔ 3 > 2^(19/12) ↔ 3^12 > 2^19 ↔ 531441 > 524288
  rw [gt_iff_lt, ← sub_pos]
  -- logb 2 3 - 19/12 > 0
  -- Use: logb 2 3 = log 3 / log 2, and 19/12 = log(2^19) / (12 · log 2)
  -- Equivalently: log 3 / log 2 > 19/12 ↔ 12 · log 3 > 19 · log 2
  -- ↔ log(3^12) > log(2^19) ↔ 3^12 > 2^19
  have hlog2_pos : log 2 > 0 := log_pos (by norm_num)
  rw [show logb 2 3 - 19 / 12 = (12 * log 3 - 19 * log 2) / (12 * log 2) from by
    unfold logb; field_simp]
  apply div_pos
  · -- 12 · log 3 - 19 · log 2 > 0 ↔ log(3^12) > log(2^19)
    rw [show 12 * log 3 = log ((3 : ℝ) ^ 12) from by rw [log_pow]; ring]
    rw [show 19 * log 2 = log ((2 : ℝ) ^ 19) from by rw [log_pow]; ring]
    rw [sub_pos]
    apply log_lt_log (by positivity)
    -- 2^19 < 3^12
    norm_num
  · positivity

end Collatz
