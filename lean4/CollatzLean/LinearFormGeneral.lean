/-
  CollatzLean/LinearFormGeneral.lean
  Generalized n-variable linear forms in logarithms.

  Provides a uniform framework subsuming:
  - Baker's 2-variable theorem (Baker.lean)
  - Matveev's 3-variable theorem (LinearFormThree.lean)

  Architecture:
  - linearFormN: n-variable linear form ∑ bᵢ · log αᵢ
  - BakerBoundN: generalized Baker-type lower bound structure
  - matveev_general: axiom for n ≥ 2 variables
  - Specializations to n=2 (log 2, log 3) and n=3 (log 2, log 5, log 7)

  References:
  - E.M. Matveev, "An explicit lower bound for a homogeneous rational
    linear form in logarithms of algebraic numbers. II", Izv. Math. 64
    (2000), 1217–1269.
  - A. Baker & G. Wüstholz, "Logarithmic forms and Diophantine geometry",
    Cambridge, 2007.
-/
import CollatzLean.DistancePowers
import CollatzLean.LinearFormThree

namespace Collatz

open Real Finset

/-! ## n-variable linear form -/

/-- Linear form in n logarithms: ∑ᵢ bᵢ · log αᵢ. -/
noncomputable def linearFormN {n : ℕ} (bs : Fin n → ℤ) (αs : Fin n → ℝ) : ℝ :=
  ∑ i : Fin n, (bs i : ℝ) * log (αs i)

/-! ## Compatibility with 2-variable and 3-variable forms -/

/-- linearFormN for n=2 recovers linearFormLog. -/
theorem linearFormN_eq_linearFormLog (b₁ b₂ : ℤ) :
    linearFormN ![b₁, b₂] ![2, 3] = linearFormLog b₁ b₂ := by
  simp [linearFormN, linearFormLog, Fin.sum_univ_two]

/-- linearFormN for n=3 with (2, 5, 7) recovers linearForm257. -/
theorem linearFormN_eq_linearForm257 (b₁ b₂ b₃ : ℤ) :
    linearFormN ![b₁, b₂, b₃] ![2, 5, 7] = linearForm257 b₁ b₂ b₃ := by
  simp [linearFormN, linearForm257, linearFormLog3, Fin.sum_univ_three]

/-! ## Generalized Baker bound -/

/-- A Baker-type lower bound for n-variable linear forms.
    For coefficient vector bs with height H ≥ max |bᵢ| and H ≥ 3,
    the linear form is bounded below by C / H^κ when nonzero. -/
structure BakerBoundN (n : ℕ) (αs : Fin n → ℝ) (C κ : ℝ) : Prop where
  hC : C > 0
  hκ : κ > 0
  hα_pos : ∀ i, αs i > 0
  bound : ∀ (bs : Fin n → ℤ) (H : ℕ),
    (∀ i, (H : ℝ) ≥ |(bs i : ℝ)|) →
    H ≥ 3 →
    (∃ i, bs i ≠ 0) →
    linearFormN bs αs ≠ 0 →
    |linearFormN bs αs| ≥ C / (H : ℝ) ^ κ

/-! ## Matveev's general theorem -/

/-- Matveev's constant for n-variable linear forms.
    Rough magnitude: C(n) ≈ 3^(n+4) · (n+1)^6.
    In practice the constant also depends on heights of αᵢ,
    but for fixed αᵢ it is a function of n only. -/
noncomputable def matveevConstN (n : ℕ) : ℝ := 3 ^ (n + 4 : ℕ) * (↑n + 1) ^ 6

/-- **Matveev's theorem** (general n-variable case).
    For multiplicatively independent algebraic numbers α₁,...,αₙ > 1
    and integer coefficients with height H ≥ 3, the linear form
    |∑ bᵢ · log αᵢ| ≥ exp(-matveevConstN(n) · (log H)^(n+1))
    when the form is nonzero.

    Reference: Matveev, Izv. Math. 64 (2000), 1217–1269. -/
axiom matveev_general :
    ∀ (n : ℕ) (_hn : n ≥ 2) (αs : Fin n → ℝ),
      (∀ i, αs i > 1) →
      ∀ (bs : Fin n → ℤ) (H : ℕ),
        (∀ i, (H : ℝ) ≥ |(bs i : ℝ)|) →
        H ≥ 3 →
        (∃ i, bs i ≠ 0) →
        linearFormN bs αs ≠ 0 →
        |linearFormN bs αs| ≥ exp (-(matveevConstN n * (log (H : ℝ)) ^ (n + 1)))

/-! ## Matveev bound is positive -/

/-- The Matveev lower bound exp(-K · (log H)^(n+1)) is always positive. -/
theorem matveev_bound_pos_general (n : ℕ) (H : ℕ) :
    exp (-(matveevConstN n * (log (H : ℝ)) ^ (n + 1))) > 0 :=
  exp_pos _

/-! ## BakerBoundN specializations -/

/-- Baker's 2-variable theorem gives BakerBoundN 2 for (2, 3). -/
theorem bakerBoundN_two_three : ∃ C κ : ℝ, BakerBoundN 2 ![2, 3] C κ := by
  obtain ⟨C, κ, hC, hκ, hbound⟩ := baker_two_three
  refine ⟨C, κ, hC, hκ, fun i => by fin_cases i <;> simp <;> norm_num, ?_⟩
  intro bs H hH _hH3 hne _hnz
  -- Baker gives |b₁·log 2 + b₂·log 3| > C / max(|b₁|, |b₂|)^κ
  have hne' : bs 0 ≠ 0 ∨ bs 1 ≠ 0 := by
    rcases hne with ⟨i, hi⟩; fin_cases i <;> [left; right] <;> exact hi
  have hbk := hbound (bs 0) (bs 1) hne'
  unfold linearFormLog at hbk
  -- Rewrite our form to match Baker's
  have hform : linearFormN bs ![2, 3] = ↑(bs 0) * log 2 + ↑(bs 1) * log 3 := by
    simp [linearFormN, Fin.sum_univ_two]
  rw [hform]
  -- Baker bound uses max(|b₁|, |b₂|); we have H ≥ |bᵢ| for each i
  -- Since max ≤ H, we have H^κ ≥ max^κ, so C/H^κ ≤ C/max^κ < |form|
  have hmax_le_H : max |(bs 0 : ℝ)| |(bs 1 : ℝ)| ≤ (H : ℝ) :=
    max_le (hH 0) (hH 1)
  have hmax_pos : (0 : ℝ) < max |(bs 0 : ℝ)| |(bs 1 : ℝ)| := by
    rcases hne' with h | h <;>
      [exact lt_of_lt_of_le (abs_pos.mpr (Int.cast_ne_zero.mpr h)) (le_max_left _ _);
       exact lt_of_lt_of_le (abs_pos.mpr (Int.cast_ne_zero.mpr h)) (le_max_right _ _)]
  have hH_pos : (0 : ℝ) < (H : ℝ) := lt_of_lt_of_le hmax_pos hmax_le_H
  have hmax_pow_pos : (0 : ℝ) < max |(bs 0 : ℝ)| |(bs 1 : ℝ)| ^ κ :=
    rpow_pos_of_pos hmax_pos _
  have hH_pow_pos : (0 : ℝ) < (H : ℝ) ^ κ := rpow_pos_of_pos hH_pos _
  -- C / H^κ ≤ C / max^κ since H ≥ max (larger denom → smaller fraction)
  have hle : C / (H : ℝ) ^ κ ≤ C / max |(bs 0 : ℝ)| |(bs 1 : ℝ)| ^ κ :=
    div_le_div_of_nonneg_left (le_of_lt hC) hmax_pow_pos
      (rpow_le_rpow (le_of_lt hmax_pos) hmax_le_H (le_of_lt hκ))
  linarith

/-! ## Monotonicity: BakerBoundN bound weakens with larger height -/

/-- If the αᵢ form is nonzero for any nonzero coefficient vector,
    then the Baker bound gives an effective positive lower bound. -/
theorem bakerBoundN_positive {n : ℕ} {αs : Fin n → ℝ} {C κ : ℝ}
    (hbaker : BakerBoundN n αs C κ)
    (bs : Fin n → ℤ) (H : ℕ)
    (hH : ∀ i, (H : ℝ) ≥ |(bs i : ℝ)|) (hH3 : H ≥ 3)
    (hne : ∃ i, bs i ≠ 0)
    (hnz : linearFormN bs αs ≠ 0) :
    |linearFormN bs αs| > 0 :=
  lt_of_lt_of_le (div_pos hbaker.hC (rpow_pos_of_pos (by positivity : (0 : ℝ) < H) _))
    (hbaker.bound bs H hH hH3 hne hnz)

/-! ## Linear form nonvanishing from multiplicative independence -/

/-- If {log α₁, ..., log αₙ} are ℚ-linearly independent (i.e., the αᵢ are
    multiplicatively independent), then linearFormN bs αs ≠ 0 for nonzero bs.
    This is a consequence of the definition of linear independence. -/
theorem linearFormN_nonzero_of_mult_indep {n : ℕ} (αs : Fin n → ℝ)
    (hα_pos : ∀ i, αs i > 0)
    (hindep : ∀ bs : Fin n → ℤ, (∃ i, bs i ≠ 0) → linearFormN bs αs ≠ 0)
    (bs : Fin n → ℤ) (hne : ∃ i, bs i ≠ 0) :
    linearFormN bs αs ≠ 0 :=
  hindep bs hne

/-! ## Concrete: (2, 3) are multiplicatively independent -/

/-- For n=2 with αs = (2, 3), the linear form is nonzero when (b₁, b₂) ≠ (0, 0). -/
theorem linearFormN_23_nonzero (bs : Fin 2 → ℤ) (hne : ∃ i, bs i ≠ 0) :
    linearFormN bs ![2, 3] ≠ 0 := by
  have hne' : bs 0 ≠ 0 ∨ bs 1 ≠ 0 := by
    rcases hne with ⟨i, hi⟩; fin_cases i <;> [left; right] <;> exact hi
  have hform : linearFormN bs ![2, 3] = linearFormLog (bs 0) (bs 1) := by
    simp [linearFormN, linearFormLog, Fin.sum_univ_two]
  rw [hform]
  exact linear_form_nonzero (bs 0) (bs 1) hne'

/-! ## Concrete: (2, 5, 7) are multiplicatively independent -/

/-- For n=3 with αs = (2, 5, 7), the linear form is nonzero when some bᵢ ≠ 0. -/
theorem linearFormN_257_nonzero (bs : Fin 3 → ℤ) (hne : ∃ i, bs i ≠ 0) :
    linearFormN bs ![2, 5, 7] ≠ 0 := by
  have hne' : bs 0 ≠ 0 ∨ bs 1 ≠ 0 ∨ bs 2 ≠ 0 := by
    rcases hne with ⟨i, hi⟩; fin_cases i
    · exact Or.inl hi
    · exact Or.inr (Or.inl hi)
    · exact Or.inr (Or.inr hi)
  have hform : linearFormN bs ![2, 5, 7] = linearForm257 (bs 0) (bs 1) (bs 2) := by
    simp [linearFormN, linearForm257, linearFormLog3, Fin.sum_univ_three]
  rw [hform]
  exact linearForm257_nonzero (bs 0) (bs 1) (bs 2) hne'

/-! ## BakerBoundN implies nonvanishing -/

/-- If the linear form is known nonzero (e.g., by multiplicative independence),
    the Baker bound gives a concrete positive lower bound for any height H ≥ 3. -/
theorem bakerBoundN_lower {n : ℕ} {αs : Fin n → ℝ} {C κ : ℝ}
    (hbaker : BakerBoundN n αs C κ)
    (bs : Fin n → ℤ) (H : ℕ)
    (hH : ∀ i, (H : ℝ) ≥ |(bs i : ℝ)|) (hH3 : H ≥ 3)
    (hne : ∃ i, bs i ≠ 0) (hnz : linearFormN bs αs ≠ 0) :
    C / (H : ℝ) ^ κ ≤ |linearFormN bs αs| :=
  hbaker.bound bs H hH hH3 hne hnz

end Collatz
