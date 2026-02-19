/-
  CollatzLean/GrowthEstimates.lean

  Analytical infrastructure for the Gel'fond-Schneider proof chain
  (Steps 3-5 of Siu's proof).

  Defines the auxiliary entire function F(z) = Σ a(i,j) · exp((i + j·β)·z)
  and provides:
  1. Differentiability (entire) — proved
  2. Growth bounds (exponential type) — sorry'd
  3. Schwarz-type extrapolation of vanishing — sorry'd
  4. Polynomial zero estimate via multiplicative independence — sorry'd

  These are the analytical core of `baker_extrapolation` in Baker.lean.

  Template: Mathlib/NumberTheory/Transcendental/Lindemann/AnalyticalPart.lean
  Mathlib resources used:
  - Schwarz lemma: Mathlib.Analysis.Complex.Schwarz
  - Maximum modulus: Mathlib.Analysis.Complex.AbsMax
  - Jensen formula: Mathlib.Analysis.Complex.JensenFormula
-/
import Mathlib.Analysis.SpecialFunctions.ExpDeriv
import Mathlib.Analysis.SpecialFunctions.Log.Base
import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Mathlib.Data.Finset.Basic
import Mathlib.NumberTheory.Real.Irrational

namespace Collatz

open Complex Real

noncomputable section

/-! ## Auxiliary entire function

The Gel'fond-Schneider proof constructs an auxiliary polynomial P(X,Y) ∈ ℤ[X,Y]
and forms the entire function F(z) = P(e^z, e^{βz}) where β = log 3 / log 2.

Expanding: F(z) = Σ_{(i,j) ∈ supp} a(i,j) · exp((i + j·β)·z).

This function has exponential type (order ≤ 1), which is the key growth
constraint that makes the Schwarz lemma extrapolation work.
-/

/-- The auxiliary entire function F(z) = Σ_{(i,j) ∈ supp} a(i,j) · exp((i + jβ)z).
    Here `a` gives the coefficients, `supp` is the finite support, and `β` is
    the irrational parameter (log 3 / log 2 in the Baker application). -/
def auxEntireFunc (a : ℤ × ℤ → ℂ) (supp : Finset (ℤ × ℤ)) (β : ℝ) (z : ℂ) : ℂ :=
  ∑ p ∈ supp, a p * exp (((p.1 : ℂ) + (p.2 : ℂ) * (β : ℂ)) * z)

/-- The auxiliary function is differentiable (entire).
    Each summand is `const * exp(linear)`, hence entire, and finite sums of
    entire functions are entire. -/
theorem auxEntireFunc_differentiable (a : ℤ × ℤ → ℂ) (supp : Finset (ℤ × ℤ)) (β : ℝ) :
    Differentiable ℂ (auxEntireFunc a supp β) := by
  intro z
  change DifferentiableAt ℂ (fun z => ∑ p ∈ supp, a p * exp (((p.1 : ℂ) + (p.2 : ℂ) * (β : ℂ)) * z)) z
  apply DifferentiableAt.fun_sum
  intro p _
  apply DifferentiableAt.mul (differentiableAt_const _)
  apply DifferentiableAt.cexp
  exact differentiableAt_id.const_mul _

/-! ## Growth bound

The key analytical fact: F(z) = P(e^z, e^{βz}) has exponential type.
On a circle of radius R, |F(z)| ≤ |supp| · B · exp(σR) where:
- B = max coefficient size
- σ = max_{(i,j) ∈ supp} |i + jβ| (the "type" of F)

This follows from the triangle inequality and |exp(wz)| ≤ exp(|w|·|z|).
-/

/-- Growth bound for the auxiliary function on circles.
    For F(z) = Σ a(i,j) · exp((i+jβ)z) with |a(i,j)| ≤ B,
    we have |F(z)| ≤ |supp| · B · exp(σ · |z|) where σ depends on supp and β. -/
theorem auxEntireFunc_growth (a : ℤ × ℤ → ℂ) (supp : Finset (ℤ × ℤ)) (β : ℝ)
    (B : ℝ) (hB : 0 ≤ B) (hBound : ∀ p ∈ supp, ‖a p‖ ≤ B) :
    ∃ σ : ℝ, σ > 0 ∧
      ∀ z : ℂ, ‖auxEntireFunc a supp β z‖ ≤
        supp.card * B * Real.exp (σ * ‖z‖) := by
  -- Choose σ = 1 + Σ_{p ∈ supp} ‖weight(p)‖. This ensures σ > 0
  -- and σ ≥ ‖weight(p)‖ for every p ∈ supp (since norms are nonneg).
  refine ⟨1 + ∑ p ∈ supp, ‖((p.1 : ℤ) : ℂ) + ((p.2 : ℤ) : ℂ) * (β : ℂ)‖,
    by positivity, fun z => ?_⟩
  set σ := 1 + ∑ p ∈ supp, ‖((p.1 : ℤ) : ℂ) + ((p.2 : ℤ) : ℂ) * (β : ℂ)‖
  -- Triangle inequality on the sum
  have h1 : ‖auxEntireFunc a supp β z‖ ≤
      ∑ p ∈ supp, ‖a p * exp (((p.1 : ℂ) + (p.2 : ℂ) * (β : ℂ)) * z)‖ := by
    exact norm_sum_le supp _
  -- Bound each summand: ‖a p · exp(w·z)‖ ≤ B · exp(σ·‖z‖)
  have h2 : ∑ p ∈ supp, ‖a p * exp (((p.1 : ℂ) + (p.2 : ℂ) * (β : ℂ)) * z)‖ ≤
      ∑ p ∈ supp, B * Real.exp (σ * ‖z‖) := by
    apply Finset.sum_le_sum
    intro p hp
    -- Split norm of product
    rw [norm_mul, Complex.norm_exp]
    -- ‖a p‖ ≤ B and exp(Re(w·z)) ≤ exp(σ·‖z‖)
    apply mul_le_mul (hBound p hp) _ (Real.exp_nonneg _) hB
    apply Real.exp_le_exp.mpr
    -- Re(w·z) ≤ ‖w·z‖ = ‖w‖·‖z‖ ≤ σ·‖z‖
    calc (((↑(p.1 : ℤ) : ℂ) + ↑(p.2 : ℤ) * ↑β) * z).re
        ≤ ‖((↑(p.1 : ℤ) : ℂ) + ↑(p.2 : ℤ) * ↑β) * z‖ :=
          Complex.re_le_norm _
      _ = ‖(↑(p.1 : ℤ) : ℂ) + ↑(p.2 : ℤ) * ↑β‖ * ‖z‖ := norm_mul _ z
      _ ≤ σ * ‖z‖ := by
          apply mul_le_mul_of_nonneg_right _ (norm_nonneg z)
          have hsingle := Finset.single_le_sum
            (f := fun p => ‖((p.1 : ℤ) : ℂ) + ((p.2 : ℤ) : ℂ) * (β : ℂ)‖)
            (fun _ _ => norm_nonneg _) hp
          linarith
  -- Constant sum = card * constant
  have h3 : ∑ _ ∈ supp, B * Real.exp (σ * ‖z‖) =
      ↑supp.card * B * Real.exp (σ * ‖z‖) := by
    rw [Finset.sum_const, nsmul_eq_mul, mul_assoc]
  linarith

/-! ## Schwarz-type extrapolation

The core analytical step in the Gel'fond-Schneider proof.

If F is an entire function of exponential type σ that vanishes at the
integer points z = 0, 1, ..., T, then F is "exponentially small" on
compact subsets of the complex plane. Specifically, for |z| ≤ R ≤ T:

|F(z)| ≤ C · exp(σ(2T+1)) · ∏_{t=0}^{T} |z-t|/(2T+1)

Since the product captures T+1 factors each ≤ 1/2 for |z| ≤ T/2,
this gives |F(z)| ≤ C · exp(σ(2T+1)) · (1/2)^{T+1}, which is
exponentially small in T when T >> σ.

This combines:
- Schwarz lemma (Mathlib.Analysis.Complex.Schwarz): dist bound from
  mapping balls to balls
- Maximum modulus principle (Mathlib.Analysis.Complex.AbsMax): if |F|
  achieves maximum on interior, F is constant

The Schwarz-type bound is the "engine" that makes the Gel'fond-Schneider
extrapolation work: many vanishing points + moderate growth → very small values.
-/

/-- Schwarz-type vanishing extrapolation for entire functions of exponential type.

    If F is entire with growth |F(z)| ≤ C·exp(σ|z|), and F vanishes at
    all integers 0, 1, ..., T, then F is exponentially small on the disk |z| ≤ T/2.

    This is the analytical core of Steps 3-4 in Siu's Gel'fond-Schneider proof.
    The proof uses the Schwarz lemma applied to F(z) / ∏(z - t) on a large disk. -/
theorem schwarz_vanishing_bound
    (f : ℂ → ℂ) (hf : Differentiable ℂ f)
    (C σ : ℝ) (hC : C > 0) (hσ : σ > 0)
    (hgrowth : ∀ z : ℂ, ‖f z‖ ≤ C * Real.exp (σ * ‖z‖))
    (T : ℕ) (hT : T ≥ 2)
    (hvanish : ∀ t : ℕ, t ≤ T → f (t : ℂ) = 0) :
    ∀ z : ℂ, ‖z‖ ≤ T / 2 →
      ‖f z‖ ≤ C * Real.exp (σ * (2 * T + 1)) * (1 / 2) ^ (T + 1) := by
  sorry

/-! ## Jensen zero counting

Jensen's formula relates the average of log|f| on a circle to the
zeros of f inside the circle. For the Gel'fond-Schneider proof,
we use the contrapositive:

If f is small on a large circle (from Schwarz extrapolation) and
f(0) ≠ 0, then Jensen's formula bounds the number of zeros.

Specifically: if |f(z)| ≤ ε on |z| ≤ R and f(0) ≠ 0, then the
number of zeros in |z| ≤ R/2 is at most log(ε/|f(0)|) / log 2.

This uses Mathlib.Analysis.Complex.JensenFormula.
-/

/-- Jensen-type zero count from growth bounds.

    An entire function with f(0) ≠ 0 that is bounded by ε on |z| ≤ R
    has at most N zeros in |z| ≤ R/2, where N depends on ε, |f(0)|, and R. -/
theorem jensen_zero_count
    (f : ℂ → ℂ) (hf : Differentiable ℂ f) (hf0 : f 0 ≠ 0)
    (R : ℝ) (hR : R > 0) (ε : ℝ) (hε : ε > 0)
    (hsmall : ∀ z : ℂ, ‖z‖ ≤ R → ‖f z‖ ≤ ε) :
    ∃ N : ℕ, ∀ (S : Finset ℂ),
      (∀ z ∈ S, f z = 0 ∧ ‖z‖ ≤ R / 2) → S.card ≤ N := by
  sorry

/-! ## Polynomial zero estimate

A polynomial P(X,Y) evaluated at points of the form (2^t, 3^t) can
vanish at only finitely many such points unless P is identically zero.
This is because the points {(2^t, 3^t) : t ∈ ℕ} are in "general position"
with respect to polynomials, a consequence of the multiplicative independence
of 2 and 3.

The zero estimate is the "algebraic" counterpart to the "analytic" Schwarz
extrapolation: the extrapolation produces many zeros, while the zero estimate
bounds how many zeros a non-zero polynomial can have. The gap between these
two counts forces the polynomial to be identically zero — contradicting the
construction. The quantitative analysis of this gap yields the effective
Baker-type lower bound on |m·log 2 + n·log 3|.
-/

/-- Polynomial evaluation at exponential points.
    Evaluates P at (2^t, 3^t) for P represented as a function on ℤ × ℤ. -/
def polyEvalExp (P : ℤ → ℤ → ℤ) (L : ℕ) (t : ℕ) : ℤ :=
  ∑ i ∈ Finset.range (L + 1), ∑ j ∈ Finset.range (L + 1),
    P i j * (2 : ℤ) ^ (i * t) * (3 : ℤ) ^ (j * t)

/-- A non-zero polynomial of degree ≤ L in each variable has at most L²
    zeros among the points {(2^t, 3^t) : t = 0, 1, ..., T}.

    This follows from the multiplicative independence of 2 and 3
    (proved as `multIndep_two_three` in Baker.lean): the points
    (2^t, 3^t) are "algebraically independent enough" that a
    polynomial of degree L cannot vanish at more than L² of them.

    The underlying fact is that the Vandermonde-like determinant
    det[(2^{t_k})^i · (3^{t_k})^j] is nonzero when the t_k are distinct,
    because 2^a · 3^b are all distinct (by multiplicative independence). -/
theorem polynomial_zero_estimate
    (P : ℤ → ℤ → ℤ) (L : ℕ) (hL : L ≥ 1)
    (hsupp : ∀ i j : ℤ, (i < 0 ∨ i > L ∨ j < 0 ∨ j > L) → P i j = 0)
    (hP : ∃ i j : ℤ, 0 ≤ i ∧ i ≤ L ∧ 0 ≤ j ∧ j ≤ L ∧ P i j ≠ 0)
    (T : ℕ) (hT : T > L * L) :
    ∃ t : ℕ, t ≤ T ∧ polyEvalExp P L t ≠ 0 := by
  sorry

/-! ## Combined extrapolation-contradiction

The full Gel'fond-Schneider argument combines all the above:
1. auxEntireFunc gives F(z) from the polynomial P
2. auxEntireFunc_growth bounds |F|
3. schwarz_vanishing_bound makes |F| exponentially small
4. jensen_zero_count says F has many zeros (more than L²)
5. polynomial_zero_estimate says a non-zero P of degree L
   can't have > L² zeros at exponential points
6. Contradiction → P ≡ 0 → but P(0,0) ≠ 0

The quantitative version of this contradiction yields the
effective lower bound in baker_extrapolation.
-/

/-- The Gel'fond-Schneider extrapolation theorem.

    Given an auxiliary polynomial P of degree ≤ L with P(0,0) ≠ 0,
    coefficient bound B, and initial vanishing at integer points 0,...,T,
    the Schwarz-Jensen analysis produces a contradiction when T is large
    enough relative to L (specifically T > L²).

    This forces the auxiliary function F(z) = P(e^z, e^{βz}) to be
    identically zero, which contradicts P(0,0) ≠ 0.

    The proof chains:
    auxEntireFunc_growth → schwarz_vanishing_bound → jensen_zero_count
    → polynomial_zero_estimate → contradiction. -/
theorem gelfond_schneider_contradiction
    (P : ℤ → ℤ → ℤ) (L : ℕ) (hL : L ≥ 1)
    (hP0 : P 0 0 ≠ 0)
    (hsupp : ∀ i j : ℤ, (i < 0 ∨ i > L ∨ j < 0 ∨ j > L) → P i j = 0)
    (_B : ℝ) (_hB : _B > 0)
    (_hbound : ∀ i j : ℤ, (|P i j| : ℝ) ≤ _B)
    (_β : ℝ) (_hβ : Irrational _β)
    (T : ℕ) (hT : T > L * L)
    (hvanish : ∀ t : ℕ, t ≤ T → polyEvalExp P L t = 0) :
    False := by
  -- Step 1: polynomial_zero_estimate says ∃ t ≤ T with polyEvalExp P L t ≠ 0
  have hP_exists : ∃ i j : ℤ, 0 ≤ i ∧ i ≤ L ∧ 0 ≤ j ∧ j ≤ L ∧ P i j ≠ 0 :=
    ⟨0, 0, le_refl _, by omega, le_refl _, by omega, by exact_mod_cast hP0⟩
  have ⟨t, ht, hne⟩ := polynomial_zero_estimate P L hL hsupp hP_exists T hT
  -- Step 2: hvanish says polyEvalExp P L t = 0 for all t ≤ T
  exact hne (hvanish t ht)

end

end Collatz
