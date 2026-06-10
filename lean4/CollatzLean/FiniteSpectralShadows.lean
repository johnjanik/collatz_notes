/-
  CollatzLean/FiniteSpectralShadows.lean

  Formalization companion to "Finite Spectral Shadows for the Collatz
  Valuation Cocycle" (J. A. Janik, 2026).

  FULLY PROVED (sorry-free):
    * `word_congr`            — 2-adic coding: equal valuation words of length p
                                force congruence mod 2^(B+1), B = word sum.
    * `repetition_rigidity`   — equal words + band proximity force exact equality
                                (the heart of the aperiodic exclusion: repeated
                                blocks ARE cycles).
    * `orbit_periodic_of_eq`  — orbit equality propagates to periodicity.
    * `bval_one`, `trivial_cycle` — the trivial cycle data.

  STATED as `proof_wanted` (analytic stack; proofs in the manuscript):
    Baker cycle bound (genuinely stated); placeholders documenting the
    threshold flattening, level-cost, cascade contraction, finite gap,
    keystone arrow, and complexity–height results.
-/
import Mathlib

namespace Collatz.Shadows

/-- Accelerated valuation `b(x) = v₂(3x+1)`. -/
def bval (x : ℕ) : ℕ := padicValNat 2 (3 * x + 1)

/-- Accelerated Syracuse map. -/
def syr (x : ℕ) : ℕ := (3 * x + 1) / 2 ^ bval x

/-- Forward orbit. -/
def orbit (x₀ : ℕ) : ℕ → ℕ
  | 0 => x₀
  | n + 1 => syr (orbit x₀ n)

@[simp] lemma orbit_zero (x : ℕ) : orbit x 0 = x := rfl
@[simp] lemma orbit_succ (x n : ℕ) : orbit x (n + 1) = syr (orbit x n) := rfl

/-- Valuation (word) sum along the orbit. -/
def valSum (x : ℕ) (p : ℕ) : ℕ := ∑ i ∈ Finset.range p, bval (orbit x i)

lemma valSum_zero (x : ℕ) : valSum x 0 = 0 := rfl

lemma orbit_shift (x : ℕ) : ∀ n, orbit x (n + 1) = orbit (syr x) n
  | 0 => rfl
  | n + 1 => by rw [orbit_succ, orbit_shift x n, ← orbit_succ]

lemma valSum_succ' (x : ℕ) (p : ℕ) :
    valSum x (p + 1) = bval x + valSum (syr x) p := by
  unfold valSum
  rw [Finset.sum_range_succ']
  simp only [orbit_shift, orbit_zero]
  exact Nat.add_comm _ _

/-- `3x+1` is divisible by `2^{bval x}`. -/
lemma pow_bval_dvd (x : ℕ) : 2 ^ bval x ∣ 3 * x + 1 := pow_padicValNat_dvd

lemma syr_mul (x : ℕ) : 2 ^ bval x * syr x = 3 * x + 1 :=
  Nat.mul_div_cancel' (pow_bval_dvd x)

/-- The Syracuse image of any `x` is odd. -/
lemma syr_odd (x : ℕ) : Odd (syr x) := by
  have hne : 3 * x + 1 ≠ 0 := by omega
  rcases Nat.even_or_odd (syr x) with he | ho
  · exfalso
    obtain ⟨k, hk⟩ := he
    have h2 : 2 ^ (bval x + 1) ∣ 3 * x + 1 := ⟨k, by rw [← syr_mul x, hk]; ring⟩
    exact pow_succ_padicValNat_not_dvd hne h2
  · exact ho

/-- **The 2-adic coding lemma.** Equal valuation words of length `p` force
    congruence modulo `2^(valSum + 1)`. -/
theorem word_congr : ∀ (p x y : ℕ), Odd x → Odd y →
    (∀ i < p, bval (orbit x i) = bval (orbit y i)) →
    x ≡ y [MOD 2 ^ (valSum x p + 1)]
  | 0, x, y, hx, hy, _ => by
    have h1 : x % 2 = 1 := Nat.odd_iff.mp hx
    have h2 : y % 2 = 1 := Nat.odd_iff.mp hy
    show x % 2 ^ (valSum x 0 + 1) = y % 2 ^ (valSum x 0 + 1)
    rw [valSum_zero, pow_one, h1, h2]
  | p + 1, x, y, hx, hy, hw => by
    have hb : bval x = bval y := by simpa using hw 0 (by omega)
    have hw' : ∀ i < p, bval (orbit (syr x) i) = bval (orbit (syr y) i) := by
      intro i hi
      have h := hw (i + 1) (by omega)
      rwa [orbit_shift x i, orbit_shift y i] at h
    have ih := word_congr p (syr x) (syr y) (syr_odd x) (syr_odd y) hw'
    have hmul := ih.mul_left' (c := 2 ^ bval x)
    rw [syr_mul x] at hmul
    have hmul2 : (2:ℕ) ^ bval x * syr y = 3 * y + 1 := by rw [hb]; exact syr_mul y
    rw [hmul2, ← pow_add] at hmul
    have hexp : bval x + (valSum (syr x) p + 1) = valSum x (p + 1) + 1 := by
      rw [valSum_succ']; omega
    rw [hexp] at hmul
    have h3 : 3 * x ≡ 3 * y [MOD 2 ^ (valSum x (p + 1) + 1)] :=
      Nat.ModEq.add_right_cancel' 1 hmul
    have hcop : Nat.gcd (2 ^ (valSum x (p + 1) + 1)) 3 = 1 :=
      Nat.Coprime.pow_left _ (by decide)
    exact Nat.ModEq.cancel_left_of_coprime hcop h3

/-- **Repetition rigidity** (the heart of the aperiodic exclusion): two orbit
    points carrying the same valuation word of length `p`, lying within
    `2^(valSum+1)` of each other, are EQUAL.  Repeated blocks are not
    approximate cycles; they are exact cycles. -/
theorem repetition_rigidity (p x y : ℕ) (hx : Odd x) (hy : Odd y)
    (hw : ∀ i < p, bval (orbit x i) = bval (orbit y i))
    (hband : Nat.dist x y < 2 ^ (valSum x p + 1)) : x = y := by
  have h := word_congr p x y hx hy hw
  rcases le_total x y with hle | hle
  · have hb : y - x < 2 ^ (valSum x p + 1) := by
      rwa [Nat.dist_eq_sub_of_le hle] at hband
    have hdvd : 2 ^ (valSum x p + 1) ∣ y - x := (Nat.modEq_iff_dvd' hle).mp h
    have h0 : y - x = 0 := Nat.eq_zero_of_dvd_of_lt hdvd hb
    omega
  · have hb : x - y < 2 ^ (valSum x p + 1) := by
      rwa [Nat.dist_comm, Nat.dist_eq_sub_of_le hle] at hband
    have hdvd : 2 ^ (valSum x p + 1) ∣ x - y := (Nat.modEq_iff_dvd' hle).mp h.symm
    have h0 : x - y = 0 := Nat.eq_zero_of_dvd_of_lt hdvd hb
    omega

/-- An orbit equality propagates: the orbit is periodic from then on. -/
theorem orbit_periodic_of_eq (x n m : ℕ) (h : orbit x n = orbit x m) :
    ∀ k, orbit x (n + k) = orbit x (m + k) := by
  intro k; induction k with
  | zero => simpa using h
  | succ k ih => rw [← Nat.add_assoc, ← Nat.add_assoc, orbit_succ, orbit_succ, ih]

/-- The trivial cycle: `bval 1 = 2`. -/
lemma bval_one : bval 1 = 2 := by native_decide

/-- The trivial cycle: `syr 1 = 1`. -/
lemma trivial_cycle : syr 1 = 1 := by native_decide

/-! ## The analytic stack (proofs in the manuscript) -/

/-- **Baker cycle bound** (manuscript `thm:bakercycle`): every nontrivial
    positive cycle has minimum polynomially bounded in its period. -/
proof_wanted baker_cycle_bound :
  ∃ C τ : ℝ, 0 < C ∧ 0 < τ ∧ ∀ x p : ℕ, 0 < p → Odd x → 1 < x →
    orbit x p = x → (x : ℝ) ≤ C * (p : ℝ) ^ (τ + 1)

/-- Placeholders documenting the analytic theorems of the manuscript:
    threshold flattening (`Q̃_L ≤ 3C₁ < 5.16`), the one-condition level cost
    (`λ = 4/7 < 3^{-1/2}`), cascade row contraction at rate `(√3/2)^c`,
    the finite H23a gap `sup_c γ_c(0) < 1`, the keystone arrow, and the
    complexity–height tradeoff.  Their formalization requires the character
    and transfer-operator apparatus and is left as the formal program. -/
proof_wanted analytic_stack_documented : True

end Collatz.Shadows
