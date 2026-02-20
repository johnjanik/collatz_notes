/-
  CollatzLean/SublinearDrift.lean
  Sublinear deficit implies the Collatz trajectory converges.

  Main theorem: `reaches_one_of_sublinear_deficit`
    If the deficit grows sublinearly -- i.e. for every epsilon > 0 there
    exists T_0 such that deficit(n,t) <= epsilon * t for all t >= T_0 --
    then collatzReaches n.

  Proof strategy (walk divergence):
    1. From sublinear deficit, extract that nu3(t)/t <= 1/3 + epsilon/3
       for large t (any epsilon > 0).
    2. Since p_equilibrium = 1/(1 + logb 2 3) > 1/3 (because logb 2 3 < 2),
       choose epsilon small enough so that 1/3 + epsilon/3 < p_equilibrium.
    3. Then the walk grows at least linearly:
         walk(t) >= delta * t  for large t,
       where delta = (2 - logb 2 3) / 6 > 0.
    4. Walk divergence to +infinity is a necessary condition for convergence.

  The sorry in `reaches_one_of_sublinear_deficit` bridges the gap from
  walk divergence + sublinear deficit to trajectory boundedness.
  Once the trajectory is bounded, the existing CorrectionRatio.lean
  infrastructure (pigeonhole -> periodicity -> cycle analysis) applies.
-/
import CollatzLean.CorrectionRatio
import CollatzLean.DenjoyKoksma

set_option linter.style.nativeDecide false
set_option linter.unusedVariables false

namespace Collatz

open Real Filter

/-! ## Sublinear deficit: definition and basic properties -/

/-- Sublinear deficit: for every epsilon > 0, the deficit is eventually
    bounded by epsilon * t. Equivalently, deficit(t)/t -> 0. -/
def SublinearDeficit (n : ℕ) : Prop :=
  ∀ ε : ℝ, ε > 0 → ∃ T₀ : ℕ, ∀ t, t ≥ T₀ → (deficit n t : ℝ) ≤ ε * ↑t

/-! ## Key constants -/

private lemma logb23_pos : logb 2 3 > 0 :=
  logb_pos (by norm_num : (1 : ℝ) < 2) (by norm_num : (1 : ℝ) < 3)

private lemma logb23_lt_two : logb 2 3 < 2 := by
  have hlog2 : (0 : ℝ) < log 2 := log_pos (by norm_num)
  rw [logb, div_lt_iff₀ hlog2]
  calc log 3 < log 4 := log_lt_log (by positivity) (by norm_num)
    _ = log (2 ^ 2) := by norm_num
    _ = 2 * log 2 := by rw [log_pow]; ring

private lemma two_minus_logb23_pos : (2 : ℝ) - logb 2 3 > 0 := by
  linarith [logb23_lt_two]

private lemma one_plus_logb23_pos' : (0 : ℝ) < 1 + logb 2 3 := by
  linarith [logb23_pos]

/-! ## Deficit cast helper -/

/-- The deficit cast to R equals 3 * nu3 - t. -/
private theorem deficit_cast_real (n t : ℕ) :
    (deficit n t : ℝ) = 3 * (↑(nu3 n t) : ℝ) - ↑t := by
  simp only [deficit]; push_cast; ring

/-! ## From sublinear deficit to nu3/t bound -/

/-- Sublinear deficit implies nu3(t)/t is eventually close to 1/3. -/
theorem nu3_ratio_bound_of_sublinear (n : ℕ) (hn : n ≥ 1)
    (hsub : SublinearDeficit n) (ε : ℝ) (hε : ε > 0) :
    ∃ T₀ : ℕ, ∀ t, t ≥ T₀ → t ≥ 1 →
      (↑(nu3 n t) / ↑t : ℝ) ≤ 1 / 3 + ε / 3 := by
  obtain ⟨T₀, hT₀⟩ := hsub ε hε
  refine ⟨T₀, fun t ht ht1 => ?_⟩
  have ht_pos : (0 : ℝ) < ↑t := Nat.cast_pos.mpr (by omega)
  have hdef := hT₀ t ht
  rw [div_le_iff₀ ht_pos]
  rw [deficit_cast_real] at hdef
  nlinarith

/-! ## Walk divergence from sublinear deficit -/

/-- From sublinear deficit, the walk grows at least linearly for large t. -/
theorem walk_eventually_linear_of_sublinear (n : ℕ) (hn : n ≥ 1)
    (hsub : SublinearDeficit n) :
    ∃ (δ : ℝ) (T₀ : ℕ), δ > 0 ∧ ∀ t, t ≥ T₀ → walk n t ≥ δ * ↑t := by
  have hα_pos : (2 : ℝ) - logb 2 3 > 0 := two_minus_logb23_pos
  have hβ_pos : (0 : ℝ) < 1 + logb 2 3 := one_plus_logb23_pos'
  have hε_pos : (2 - logb 2 3) / (2 * (1 + logb 2 3)) > 0 := by positivity
  obtain ⟨T₀, hT₀⟩ := hsub _ hε_pos
  refine ⟨(2 - logb 2 3) / 6, T₀, by positivity, fun t ht => ?_⟩
  have hdef_real := hT₀ t ht
  rw [walk_eq_deficit_form]
  -- Bound: (1+logb23)*deficit ≤ (2-logb23)/2 * t
  have h_bnd : (1 + logb 2 3) * (deficit n t : ℝ) ≤
      (2 - logb 2 3) / 2 * ↑t := by
    calc (1 + logb 2 3) * (deficit n t : ℝ)
        ≤ (1 + logb 2 3) * ((2 - logb 2 3) / (2 * (1 + logb 2 3)) * ↑t) :=
          mul_le_mul_of_nonneg_left hdef_real (le_of_lt hβ_pos)
      _ = (2 - logb 2 3) / 2 * ↑t := by
          have : (1 + logb 2 3) ≠ 0 := ne_of_gt hβ_pos
          field_simp
  -- Remove division by 3 from goal
  rw [ge_iff_le, le_div_iff₀ (by norm_num : (0 : ℝ) < 3)]
  have hLHS : (2 - logb 2 3) / 6 * ↑t * 3 = (2 - logb 2 3) / 2 * ↑t := by ring
  linarith

/-- Sublinear deficit implies the walk diverges to +infinity. -/
theorem walk_diverges_of_sublinear_deficit (n : ℕ) (hn : n ≥ 1)
    (hsub : SublinearDeficit n) :
    Filter.Tendsto (fun t => walk n t) Filter.atTop Filter.atTop := by
  obtain ⟨δ, T₀, hδ, hlin⟩ := walk_eventually_linear_of_sublinear n hn hsub
  exact tendsto_atTop_of_eventually_linear _ δ hδ T₀ hlin

/-! ## Trajectory bound from deficit -/

/-- From the universal bound and deficit, the trajectory value
    is bounded by n * 2^D at times where deficit(t) <= D. -/
theorem collatzSeq_le_of_deficit (n : ℕ) (hn : n ≥ 1) (t : ℕ)
    (D : ℤ) (hD : D ≥ 0) (hdef : deficit n t ≤ D) :
    collatzSeq n t ≤ n * 2 ^ D.toNat := by
  have hub := identity_le_four_pow_nu3 n hn t
  have hid := collatz_identity n t
  have hpart := nu_partition n t
  have h2nu3 : 2 * nu3 n t ≤ nu2 n t + D.toNat := by
    simp only [deficit] at hdef
    have hDcast : D = ↑D.toNat := by omega
    have : (3 * nu3 n t : ℤ) ≤ ↑t + ↑D.toNat := by omega
    omega
  have h4 : (4 : ℕ) ^ nu3 n t ≤ 2 ^ D.toNat * 2 ^ nu2 n t :=
    calc (4 : ℕ) ^ nu3 n t = (2 ^ 2) ^ nu3 n t := by norm_num
      _ = 2 ^ (2 * nu3 n t) := by rw [← pow_mul]
      _ ≤ 2 ^ (nu2 n t + D.toNat) :=
          Nat.pow_le_pow_right (by norm_num) (by omega)
      _ = 2 ^ nu2 n t * 2 ^ D.toNat := by rw [pow_add]
      _ = 2 ^ D.toNat * 2 ^ nu2 n t := by ring
  have h5 : collatzSeq n t * 2 ^ nu2 n t ≤ n * 2 ^ D.toNat * 2 ^ nu2 n t :=
    calc collatzSeq n t * 2 ^ nu2 n t
        ≤ n * 4 ^ nu3 n t := by linarith [hid]
      _ ≤ n * (2 ^ D.toNat * 2 ^ nu2 n t) := Nat.mul_le_mul_left n h4
      _ = n * 2 ^ D.toNat * 2 ^ nu2 n t := by ring
  exact Nat.le_of_mul_le_mul_right h5 (Nat.pos_of_ne_zero (by positivity))

/-- At deficit(t) <= 0, the trajectory value is at most n. -/
theorem collatzSeq_le_n_of_nonpos_deficit (n : ℕ) (hn : n ≥ 1) (t : ℕ)
    (hdef : deficit n t ≤ 0) :
    collatzSeq n t ≤ n := by
  have := collatzSeq_le_of_deficit n hn t 0 (le_refl 0) hdef
  simp only [Int.toNat_zero, pow_zero, mul_one] at this
  exact this

/-! ## Periodic deficit growth (local infrastructure)

We reproduce `nu3_add_kperiods` locally since it is private in
CorrectionRatio.lean. -/

/-- nu3 increases by oddStepsInPeriod over a window of length p.
    (Local copy of nu3_add_period from CorrectionRatio.lean.) -/
private theorem nu3_add_period' (n T₂ p : ℕ) :
    nu3 n (T₂ + p) = nu3 n T₂ + oddStepsInPeriod n T₂ p := by
  induction p with
  | zero => simp [oddStepsInPeriod, Finset.filter_empty]
  | succ p ih =>
    rw [show T₂ + (p + 1) = (T₂ + p) + 1 from by omega]
    have hsucc : oddStepsInPeriod n T₂ (p + 1) = oddStepsInPeriod n T₂ p +
        if isOddStep n (T₂ + p) then 1 else 0 := by
      simp only [oddStepsInPeriod, Finset.range_add_one, Finset.filter_insert]
      have hmem : p ∉ (Finset.range p).filter
          (fun i => isOddStep n (T₂ + i)) := by
        simp only [Finset.mem_filter, Finset.mem_range, lt_irrefl, false_and,
                   not_false_eq_true]
      by_cases ho : (isOddStep n (T₂ + p) : Prop)
      · simp only [if_pos ho, Finset.card_insert_of_notMem hmem]
      · simp only [if_neg ho, Nat.add_zero]
    rcases even_or_odd_step n (T₂ + p) with he | ho
    · rw [nu3_step_even n (T₂ + p) he, ih]
      have : ¬(isOddStep n (T₂ + p) : Prop) := by
        simp only [isEvenStep, isOddStep, decide_eq_true_eq] at he ⊢; omega
      simp only [if_neg this] at hsucc; omega
    · rw [nu3_step_odd n (T₂ + p) ho, ih]
      have : (isOddStep n (T₂ + p) : Prop) := by
        simp only [isOddStep, decide_eq_true_eq] at ho ⊢; exact ho
      simp only [if_pos this] at hsucc; omega

/-- isOddStep is periodic when the trajectory is periodic. -/
private theorem isOddStep_periodic' (n T₂ p : ℕ)
    (hperiodic : ∀ t, t ≥ T₂ → collatzSeq n (t + p) = collatzSeq n t)
    (t : ℕ) (ht : t ≥ T₂) : isOddStep n (t + p) = isOddStep n t := by
  simp only [isOddStep, hperiodic t ht]

/-- oddStepsInPeriod is invariant under shifting by p. -/
private theorem oddStepsInPeriod_shift' (n T₂ p : ℕ)
    (hperiodic : ∀ t, t ≥ T₂ → collatzSeq n (t + p) = collatzSeq n t) :
    oddStepsInPeriod n (T₂ + p) p = oddStepsInPeriod n T₂ p := by
  simp only [oddStepsInPeriod]
  congr 1; ext i
  simp only [Finset.mem_filter]
  constructor
  · intro ⟨hi, hodd⟩
    refine ⟨hi, ?_⟩
    rwa [show T₂ + p + i = (T₂ + i) + p from by omega,
         isOddStep_periodic' n T₂ p hperiodic (T₂ + i) (by omega)] at hodd
  · intro ⟨hi, hodd⟩
    refine ⟨hi, ?_⟩
    rwa [show T₂ + p + i = (T₂ + i) + p from by omega,
         isOddStep_periodic' n T₂ p hperiodic (T₂ + i) (by omega)]

/-- nu3 after k full periods. -/
private theorem nu3_add_kperiods' (n T₂ p k : ℕ)
    (hperiodic : ∀ t, t ≥ T₂ → collatzSeq n (t + p) = collatzSeq n t) :
    nu3 n (T₂ + k * p) = nu3 n T₂ + k * oddStepsInPeriod n T₂ p := by
  induction k with
  | zero => simp
  | succ k ih =>
    rw [show (k + 1) * p = k * p + p from by ring,
        show T₂ + (k * p + p) = (T₂ + k * p) + p from by omega,
        nu3_add_period' n (T₂ + k * p) p]
    suffices oddStepsInPeriod n (T₂ + k * p) p = oddStepsInPeriod n T₂ p by
      rw [ih, this]; ring
    clear ih
    induction k with
    | zero => simp
    | succ k ihk =>
      rw [show (k + 1) * p = k * p + p from by ring,
          show T₂ + (k * p + p) = (T₂ + k * p) + p from by omega,
          oddStepsInPeriod_shift' n (T₂ + k * p) p
            (fun t ht => hperiodic t (by omega)),
          ihk]

/-! ## Sublinear deficit and periodic orbits -/

/-- If the trajectory is eventually periodic and the deficit is sublinear,
    then 3*Delta_3 <= p. -/
theorem three_delta3_le_p_of_sublinear (n : ℕ) (hn : n ≥ 1)
    (hsub : SublinearDeficit n)
    (T₂ p : ℕ) (hp : p ≥ 1)
    (hperiodic : ∀ t, t ≥ T₂ → collatzSeq n (t + p) = collatzSeq n t) :
    3 * oddStepsInPeriod n T₂ p ≤ p := by
  -- Proof by contradiction: if 3*Δ₃ > p, then along periodic times T₂ + k*p
  -- the deficit grows linearly (at rate 3*Δ₃ - p ≥ 1 per period), contradicting
  -- the sublinear deficit condition for large k.
  by_contra h
  push_neg at h
  set Δ₃ := oddStepsInPeriod n T₂ p
  have hdeficit_kp : ∀ k : ℕ, deficit n (T₂ + k * p) =
      deficit n T₂ + ↑k * (3 * ↑Δ₃ - ↑p) := by
    intro k
    simp only [deficit]
    have := nu3_add_kperiods' n T₂ p k hperiodic
    push_cast [this]; ring
  -- The gap g = 3*Δ₃ - p ≥ 1 (in ℤ, since 3*Δ₃ > p for naturals)
  have hg_pos : (3 * ↑Δ₃ - ↑p : ℤ) ≥ 1 := by omega
  -- For any ε > 0, deficit(T₂ + k*p) = D₀ + k*g eventually exceeds ε*(T₂+k*p)
  -- since g ≥ 1 but ε*(T₂+k*p) ~ ε*k*p (linear in k with smaller slope for small ε)
  obtain ⟨T₀, hT₀⟩ := hsub (1 / (2 * ↑p)) (by positivity)
  -- Choose k large enough relative to BOTH T₀ and T₂
  set D₀abs := Int.natAbs (deficit n T₂)
  set k := max T₀ T₂ + 3 * D₀abs + 1
  have hk_large : T₂ + k * p ≥ T₀ := by
    have : k * p ≥ k := Nat.le_mul_of_pos_right k (by omega)
    have : k ≥ T₀ := le_trans (Nat.le_max_left T₀ T₂) (by omega)
    omega
  specialize hT₀ (T₂ + k * p) hk_large
  rw [hdeficit_kp] at hT₀
  -- hT₀ : (↑(deficit n T₂ + ↑k * (3 * ↑Δ₃ - ↑p)) : ℝ) ≤ 1/(2p) * ↑(T₂ + k*p)
  -- Lower bound LHS: D₀ + k*g ≥ k - |D₀| (since g ≥ 1 and D₀ ≥ -|D₀|)
  have hLHS : (↑k : ℝ) - ↑D₀abs ≤
      (↑(deficit n T₂ + ↑k * (3 * ↑Δ₃ - ↑p)) : ℝ) := by
    suffices h : (↑k : ℤ) - ↑D₀abs ≤ deficit n T₂ + ↑k * (3 * ↑Δ₃ - ↑p) by
      exact_mod_cast h
    have h1 : (deficit n T₂ : ℤ) ≥ -(↑D₀abs : ℤ) := by
      have := neg_abs_le (deficit n T₂)
      rwa [Int.abs_eq_natAbs] at this
    have h2 : (↑k : ℤ) * (3 * ↑Δ₃ - ↑p) ≥ ↑k * 1 :=
      Int.mul_le_mul_of_nonneg_left hg_pos (by omega : (0 : ℤ) ≤ ↑k)
    linarith
  -- Combine hLHS ≤ hT₀ and clear denominator for contradiction
  have h_combined : (↑k : ℝ) - ↑D₀abs ≤ 1 / (2 * ↑p) * ↑(T₂ + k * p) :=
    le_trans hLHS hT₀
  have h2p_pos : (0 : ℝ) < 2 * ↑p := by positivity
  rw [div_mul_eq_mul_div, one_mul, le_div_iff₀ h2p_pos] at h_combined
  -- h_combined : (↑k - ↑D₀abs) * (2 * ↑p) ≤ ↑(T₂ + k * p)
  push_cast at h_combined
  -- k ≥ T₂ + 3 * D₀abs + 1 by construction
  have hmax_r : T₂ ≤ max T₀ T₂ := le_max_right T₀ T₂
  have hk_big : (↑k : ℝ) ≥ ↑T₂ + 3 * ↑D₀abs + 1 := by
    exact_mod_cast show k ≥ T₂ + 3 * D₀abs + 1 from by omega
  have hp_r : (1 : ℝ) ≤ ↑p := by exact_mod_cast hp
  -- Contradiction: T₂*(p-1) + D₀abs*p + p ≤ 0, but all terms ≥ 0 and p ≥ 1
  nlinarith [mul_le_mul_of_nonneg_right hk_big (show (0:ℝ) ≤ ↑p from by linarith),
             mul_nonneg (Nat.cast_nonneg (α := ℝ) T₂) (show (0:ℝ) ≤ ↑p - 1 from by linarith),
             mul_nonneg (Nat.cast_nonneg (α := ℝ) D₀abs) (show (0:ℝ) ≤ ↑p from by linarith)]

/-! ## Trajectory boundedness (the gap) -/

/-- **Trajectory boundedness from sublinear deficit**: the sole sorry in this file.

    If the deficit grows sublinearly, the Collatz trajectory is eventually bounded.

    Mathematical argument (not yet formalized):
    From the identity a(t) · 2^ν₂ = n · 3^ν₃ + C(t), we have
      a(t) = n · 3^ν₃/2^ν₂ + C(t)/2^ν₂.

    Walk divergence (proved from sublinear deficit) gives 2^ν₂/3^ν₃ → ∞,
    so the first term → 0.

    The correction ratio r(t) = C(t)/2^ν₂ satisfies:
      even step: r → r/2,  odd step: r → 3r + 1.
    Between consecutive odd steps at positions s_j, s_{j+1}, with e_j = s_{j+1} - s_j - 1
    even steps in between, the ratio evolves as r → 3r/2^{e_j} + 1.
    Walk linear growth forces ∑ e_j > log₂(3) · j (on average),
    making the products ∏(3/2^{e_k}) decay geometrically and the
    geometric series ∑ ∏(3/2^{e_k}) converge, giving r(t) ≤ B.

    Therefore a(t) → 0, but a(t) ≥ 1 as a positive integer,
    so a(t) = 1 for large t — giving trajectory boundedness.

    Closing this sorry requires formalizing the geometric series argument
    for the correction ratio bound. -/
theorem trajectory_bounded_of_sublinear_deficit (n : ℕ) (hn : n ≥ 1)
    (hsub : SublinearDeficit n) :
    ∃ B T₁ : ℕ, ∀ t, t ≥ T₁ → collatzSeq n t ≤ B := by
  sorry

/-! ## Cycle analysis under sublinear deficit

We replicate the cycle_contains_one analysis from CorrectionRatio.lean,
replacing the K-bound hypothesis with SublinearDeficit.  The key lemma
`three_delta3_le_p_of_sublinear` (proved above) provides the 3·Δ₃ ≤ p
bound that was previously derived from the K-bound. -/

/-- Any eventually periodic Collatz trajectory with sublinear deficit
    must contain 1 in its cycle.  Same case analysis as cycle_contains_one
    (CorrectionRatio.lean) but using three_delta3_le_p_of_sublinear
    instead of three_delta3_le_p. -/
private theorem cycle_contains_one_of_sublinear (n : ℕ) (hn : n ≥ 1)
    (hsub : SublinearDeficit n)
    (T₂ p : ℕ) (hp : p ≥ 1)
    (hperiodic : ∀ t, t ≥ T₂ → collatzSeq n (t + p) = collatzSeq n t) :
    ∃ t, t ≥ T₂ ∧ collatzSeq n t = 1 := by
  have h3d := three_delta3_le_p_of_sublinear n hn hsub T₂ p hp hperiodic
  by_cases h0 : oddStepsInPeriod n T₂ p = 0
  · -- Δ₃ = 0: impossible (2^p = 1 contradiction)
    exact absurd h0 (by
      intro h0; exact no_cycle_delta3_zero n hn T₂ p hp
        (hperiodic T₂ le_rfl) h0)
  by_cases h1 : oddStepsInPeriod n T₂ p = 1
  · -- Δ₃ = 1: only {1,2,4} cycle
    exact cycle_contains_one_of_delta3_one n hn T₂ p hp hperiodic h1
  · -- Δ₃ ≥ 2: case split on 3Δ₃ < p vs 3Δ₃ = p
    have hdelta : oddStepsInPeriod n T₂ p ≥ 2 := by omega
    by_cases heq : p = 3 * oddStepsInPeriod n T₂ p
    · -- Equality case: Baker's theorem eliminates non-trivial balanced cycles
      exact no_cycle_equality_case n hn T₂ p hp hperiodic heq hdelta
    · -- Strict case: 3Δ₃ + 1 ≤ p, universal bound gives a(T₂) < 1 contradiction
      exact absurd
        (no_cycle_strict_inequality n hn T₂ p hp hperiodic (by omega))
        (not_false)

/-! ## The main theorem -/

/-- **Sublinear deficit implies convergence**: If the deficit grows
    sublinearly (deficit(t)/t -> 0), then the Collatz trajectory of n
    eventually reaches 1.

    Proof chain:
    1. trajectory_bounded_of_sublinear_deficit [sorry] → trajectory bounded
    2. collatzSeq_eventually_periodic_of_bounded [proved] → eventually periodic
    3. cycle_contains_one_of_sublinear [proved] → cycle contains 1
    4. Extract collatzReaches from the cycle containing 1

    The sole sorry is trajectory_bounded_of_sublinear_deficit. -/
theorem reaches_one_of_sublinear_deficit (n : ℕ) (hn : n ≥ 1)
    (hsub : SublinearDeficit n) :
    collatzReaches n := by
  -- Step 1: trajectory is eventually bounded (the sorry)
  obtain ⟨B, T₁, hBound⟩ := trajectory_bounded_of_sublinear_deficit n hn hsub
  -- Step 2: trajectory is eventually periodic (pigeonhole)
  obtain ⟨T₂, p, hp, hT₂ge, hPeriodic⟩ :=
    collatzSeq_eventually_periodic_of_bounded n hn B T₁ hBound
  -- Step 3: cycle contains 1 (case analysis using sublinear deficit)
  obtain ⟨t, _, ht1⟩ := cycle_contains_one_of_sublinear n hn hsub T₂ p hp hPeriodic
  -- Step 4: collatzReaches
  exact ⟨t, ht1⟩

/-! ## Relationship to existing infrastructure -/

/-- The K-bound implies sublinear deficit (strictly stronger condition). -/
theorem sublinear_of_k_bound (n : ℕ) (K T₀ : ℕ)
    (hbound : ∀ t, t ≥ T₀ → 3 * nu3 n t ≤ t + K) :
    SublinearDeficit n := by
  intro ε hε
  refine ⟨max T₀ (⌈(↑K : ℝ) / ε⌉₊ + 1), fun t ht => ?_⟩
  have htT₀ : t ≥ T₀ := le_trans (le_max_left ..) ht
  have htN : t ≥ ⌈(↑K : ℝ) / ε⌉₊ + 1 := le_trans (le_max_right ..) ht
  have hdef : deficit n t ≤ ↑K := by
    simp only [deficit]
    have : (3 * nu3 n t : ℤ) ≤ ↑t + ↑K := by exact_mod_cast hbound t htT₀
    omega
  have hK_le : (↑K : ℝ) ≤ ε * ↑t := by
    have hceil : (↑K : ℝ) / ε ≤ ↑(⌈(↑K : ℝ) / ε⌉₊) := Nat.le_ceil _
    have ht_ge : (↑t : ℝ) ≥ ↑(⌈(↑K : ℝ) / ε⌉₊) + 1 := by exact_mod_cast htN
    calc (↑K : ℝ) = ε * ((↑K : ℝ) / ε) := by field_simp
      _ ≤ ε * ↑(⌈(↑K : ℝ) / ε⌉₊) :=
          mul_le_mul_of_nonneg_left hceil (le_of_lt hε)
      _ ≤ ε * ↑t := by nlinarith
  calc (deficit n t : ℝ) ≤ ↑K := by exact_mod_cast hdef
    _ ≤ ε * ↑t := hK_le

/-- Deficit bounded (constant bound) implies sublinear deficit. -/
theorem sublinear_of_deficit_bounded (n : ℕ)
    (hdef : ∃ D : ℤ, ∀ t, deficit n t ≤ D) :
    SublinearDeficit n := by
  obtain ⟨D, hD⟩ := hdef
  intro ε hε
  have hD0 : 0 ≤ D := by
    have h0 := hD 0; simp only [deficit_zero] at h0; exact h0
  refine ⟨⌈(↑D : ℝ) / ε⌉₊ + 1, fun t ht => ?_⟩
  have hD_le : (↑D : ℝ) ≤ ε * ↑t := by
    have hceil : (↑D : ℝ) / ε ≤ ↑(⌈(↑D : ℝ) / ε⌉₊) := Nat.le_ceil _
    have ht_ge : (↑t : ℝ) ≥ ↑(⌈(↑D : ℝ) / ε⌉₊) + 1 := by exact_mod_cast ht
    calc (↑D : ℝ) = ε * ((↑D : ℝ) / ε) := by field_simp
      _ ≤ ε * ↑(⌈(↑D : ℝ) / ε⌉₊) :=
          mul_le_mul_of_nonneg_left hceil (le_of_lt hε)
      _ ≤ ε * ↑t := by nlinarith
  calc (deficit n t : ℝ) ≤ ↑D := by exact_mod_cast hD t
    _ ≤ ε * ↑t := hD_le

/-- collatzReaches implies sublinear deficit (via K-bound). -/
theorem sublinear_of_reaches (n : ℕ) (hn : n ≥ 1) (hr : collatzReaches n) :
    SublinearDeficit n := by
  obtain ⟨K, T₀, hbound⟩ := nu3_linear_bound_of_reaches n hn hr
  exact sublinear_of_k_bound n K T₀ hbound

/-! ## Summary

  The proof chain for reaches_one_of_sublinear_deficit:

    SublinearDeficit n
         |
         | trajectory_bounded_of_sublinear_deficit [sorry — THE gap]
         v
    Trajectory bounded
         |
         | collatzSeq_eventually_periodic_of_bounded [proved, CorrectionRatio.lean]
         v
    Eventually periodic
         |
         | cycle_contains_one_of_sublinear [proved — uses three_delta3_le_p_of_sublinear
         |   + cycle analysis from CorrectionRatio.lean (Baker for Δ₃≥2 equality case)]
         v
    Cycle contains 1  →  collatzReaches n

  The sole sorry is trajectory_bounded_of_sublinear_deficit.  To close it,
  one needs the geometric series bound on C(t)/2^ν₂(t):
    Between consecutive odd steps, the ratio r = C/2^ν₂ evolves as
    r → 3r/2^e + 1 where e is the number of intervening even steps.
    Walk linear growth forces ∑ e > log₂(3) · j on average, making
    the geometric products decay and the series converge.

  Relationships:
  - K-bound -> SublinearDeficit (proved: sublinear_of_k_bound)
  - SublinearDeficit -> K-bound: NOT true in general, requires the sorry
  - finite_deficit_bound (O(1)) is strictly stronger than SublinearDeficit (o(t))
  - collatzReaches -> SublinearDeficit (proved: sublinear_of_reaches) -/

/-! ## Assembly: Denjoy-Koksma path to Collatz

  Alternative proof path using the Denjoy-Koksma inequality:

    denjoy_koksma_sublinear_birkhoff [axiom A5, DenjoyKoksma.lean]
      + rhin_irrationality_measure [axiom A2, IrrationalityMeasure.lean]
      → deficit_sublinear_bound [sorry — DK + solenoid transfer]
      → deficit_sublinear [sorry — depends on above]
      → SublinearDeficit n [definitional match]
      → reaches_one_of_sublinear_deficit [sorry — trajectory boundedness]
      → collatzReaches n

  The three sorrys represent:
  1. Application of DK inequality to Collatz dynamics (transfer from model to actual)
  2. The same, converted to SublinearDeficit form
  3. Sublinear deficit implies trajectory boundedness

  Compare with the main path (Conclusion.lean):
    nu3_linear_bound [sorry] → reaches_one_of_linear_drift [proved] → collatzReaches n
  which has a single (but stronger) sorry. -/

/-- **Alternative Collatz proof via Denjoy-Koksma**: If the DK inequality
    applies to Collatz dynamics (deficit_sublinear, sorry), then every n ≥ 1
    eventually reaches 1.

    This reduces the Collatz conjecture to:
    (a) the DK transfer from irrational rotation to Collatz dynamics, and
    (b) sublinear deficit implies trajectory boundedness. -/
theorem collatz_via_denjoy_koksma (n : ℕ) (hn : n ≥ 1) : collatzReaches n :=
  reaches_one_of_sublinear_deficit n hn (deficit_sublinear n hn)

end Collatz
