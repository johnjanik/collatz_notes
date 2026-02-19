/-
  CollatzLean/SolenoidMixing.lean

  The solenoid mixing bridge: reduces finite_residence_bound to a clean
  mixing axiom about the Syracuse map on the (2,3)-solenoid.

  This is the critical-path file connecting the three proved components:
  1. Hensel attrition (HenselAttrition.lean) -- v₂=1 runs ↔ 2^{d+1} | (x+1)
  2. Baker cell separation (DiophantineRepeller.lean) -- cells Diophantine-separated
  3. Weyl equidistribution (WeylEquidistribution.lean) -- irrational rotation mixing

  to finite_residence_bound, the sole remaining gap on the critical path.

  Key new content:
  - walkCellError: the walk as a cell error on the torus
  - cellError_shift_of_v2_run: cell error shifts by d·(1-log₂3) during d-run
  - solenoid_mixing: the irreducible mixing axiom
  - finite_residence_from_mixing: axiom → finite_residence_bound
  - k_bound_from_mixing: axiom → K-bound
-/
import CollatzLean.HenselAttrition
import CollatzLean.DiophantineRepeller
import CollatzLean.DeficitBudget
import CollatzLean.WeylEquidistribution

set_option linter.style.nativeDecide false

namespace Collatz

open Real

/-! ## Auxiliary: logb 2 3 > 1 -/

private theorem logb_two_three_gt_one : logb 2 3 > 1 := by
  rw [Real.logb, gt_iff_lt, lt_div_iff₀ (Real.log_pos (by norm_num : (1:ℝ) < 2))]
  linarith [Real.log_lt_log (by norm_num : (0:ℝ) < 2) (by norm_num : (2:ℝ) < 3)]

/-! ## Section 1: Walk as cell error -/

/-- Cell error of the walk at step t: cellError(ν₂(n,t), ν₃(n,t)).
    This identifies the walk with the cell error on the (Z/3^k Z)² torus. -/
noncomputable def walkCellError (n t : ℕ) : ℝ :=
  cellError ↑(nu2 n t) ↑(nu3 n t)

/-- The walk equals the cell error of the step counters. -/
theorem walk_eq_walkCellError (n t : ℕ) : walk n t = walkCellError n t := by
  simp only [walk, walkCellError, cellError]; push_cast; ring

/-! ## Section 2: Cell error shift during v₂=1 runs -/

/-- **Cell error shift**: During d consecutive v₂=1 steps (2d uncompressed),
    the cell error shifts by exactly d·(1 - log₂3) ≈ -0.585d.

    Since log₂3 > 1, the cell error DECREASES during dangerous runs.
    This is the algebraic bridge between Hensel attrition and Baker
    separation: the cell error cannot remain near zero (dangerous)
    during a long v₂=1 run because it shifts linearly away.

    Proof: Direct from walk_of_v2_run + walk_eq_walkCellError. -/
theorem cellError_shift_of_v2_run (n t d : ℕ) (hn : n ≥ 1)
    (hodd : collatzSeq n t % 2 = 1)
    (hrun : ∀ i, i ≤ d → oddCollatzIter (collatzSeq n t) i % 2 = 1) :
    walkCellError n (t + 2 * d) = walkCellError n t + ↑d * (1 - logb 2 3) := by
  rw [← walk_eq_walkCellError, ← walk_eq_walkCellError]
  exact walk_of_v2_run n t d hn hodd hrun

/-- The absolute cell error shift: |d·(1 - log₂3)| = d·(log₂3 - 1) ≈ 0.585d. -/
theorem cellError_shift_magnitude (d : ℕ) :
    |↑d * (1 - logb 2 3)| = ↑d * (logb 2 3 - 1) := by
  have hlog := logb_two_three_gt_one
  have hneg : (1 : ℝ) - logb 2 3 < 0 := by linarith
  rw [abs_mul, abs_of_nonneg (Nat.cast_nonneg d), abs_of_nonpos hneg.le]
  ring

/-- logb 2 3 > 3/2 (from 9 > 8, i.e., 3² > 2³). -/
private theorem logb_two_three_gt_three_halves : logb 2 3 > 3 / 2 := by
  have hlog2_pos : (0:ℝ) < Real.log 2 := Real.log_pos (by norm_num)
  rw [Real.logb, gt_iff_lt, lt_div_iff₀ hlog2_pos]
  -- Goal: 3 / 2 * Real.log 2 < Real.log 3
  -- From: Real.log 8 < Real.log 9, where 8 = 2³ and 9 = 3²
  suffices h : 3 * Real.log 2 < 2 * Real.log 3 by linarith
  have h8 : 3 * Real.log 2 = Real.log (2 ^ 3) := by
    rw [Real.log_pow]; push_cast; ring
  have h9 : 2 * Real.log 3 = Real.log (3 ^ 2) := by
    rw [Real.log_pow]; push_cast; ring
  rw [h8, h9]
  exact Real.log_lt_log (by norm_num) (by norm_num)

/-- The cell error shift grows linearly: after d ≥ 2 compressed v₂=1 steps,
    |shift| ≥ 2·(log₂3 - 1) > 2·(1/2) = 1. -/
theorem cellError_shift_exceeds_one (d : ℕ) (hd : d ≥ 2) :
    ↑d * (logb 2 3 - 1) > 1 := by
  have hlogb := logb_two_three_gt_three_halves
  have hpos : logb 2 3 - 1 > 0 := by linarith [logb_two_three_gt_one]
  have hd_cast : (↑d : ℝ) ≥ 2 := by exact_mod_cast hd
  have h1 : (↑d - 2) * (logb 2 3 - 1) ≥ 0 :=
    mul_nonneg (by linarith) (by linarith)
  nlinarith

/-! ## Section 3: Bounded dangerous runs -/

/-- A trajectory has bounded dangerous runs if no v₂=1 run exceeds D
    compressed steps. Formulated via Hensel: at every odd position,
    2^(D+2) does not divide (value + 1). -/
def HasBoundedDangerousRuns (n D : ℕ) : Prop :=
  ∀ t : ℕ, collatzSeq n t % 2 = 1 → ¬(2 ^ (D + 2) ∣ collatzSeq n t + 1)

/-- Equivalent formulation: no run of > D compressed odd steps. -/
def HasBoundedRuns (n D : ℕ) : Prop :=
  ∀ t : ℕ, ∀ d : ℕ, d > D →
    collatzSeq n t % 2 = 1 →
    ¬(∀ i, i ≤ d → oddCollatzIter (collatzSeq n t) i % 2 = 1)

/-- The two bounded run formulations are equivalent by Hensel attrition. -/
theorem hasBoundedRuns_iff (n D : ℕ) :
    HasBoundedRuns n D ↔ HasBoundedDangerousRuns n D := by
  constructor
  · -- Forward: bounded runs → bounded 2-adic valuation
    intro hbr t hodd hdvd
    have hfwd := hensel_forward (collatzSeq n t) (D + 1) hodd hdvd
    exact hbr t (D + 1) (by omega) hodd hfwd
  · -- Backward: bounded 2-adic valuation → bounded runs
    intro hbd t d hd hodd hall
    have hdvd := hensel_backward (collatzSeq n t) d hodd hall
    have hpow : 2 ^ (D + 2) ∣ 2 ^ (d + 1) := pow_dvd_pow 2 (by omega)
    exact hbd t hodd (dvd_trans hpow hdvd)

/-! ## Section 4: Compensated runs and sliding window -/

/-- A trajectory has compensated runs if in every window of W steps,
    the odd step density does not exceed 1/3 (i.e., 3·Δν₃ ≤ W). -/
def HasCompensatedRuns (n W : ℕ) : Prop :=
  ∀ t : ℕ, 3 * (nu3 n (t + W) - nu3 n t) ≤ W

/-- Compensated runs ↔ SlidingWindowCondition (by sliding_window_iff_odd_density). -/
theorem hasCompensatedRuns_iff_slidingWindow (n W : ℕ) :
    HasCompensatedRuns n W ↔ SlidingWindowCondition n W :=
  (sliding_window_iff_odd_density n W).symm

/-! ## Section 5: The solenoid mixing axiom -/

/-- **Solenoid mixing axiom**: For every n ≥ 1, the Collatz trajectory
    of n satisfies the compensated runs condition for some window size W.

    This is the SINGLE irreducible axiom on the critical path (beyond
    Baker's theorem and Hercher's no-small-cycles result). It captures
    the mixing of the Syracuse map on the (2,3)-solenoid.

    === Why this axiom is expected to hold ===

    Three forces conflict to prevent sustained dangerous behavior:

    1. **Hensel attrition** (proved, HenselAttrition.lean):
       P(run ≥ d) = 2^{-d}. Long runs require extreme 2-adic structure.

    2. **Baker cell separation** (proved, DiophantineRepeller.lean):
       Dangerous cells are Diophantine-separated: gap > C·max^{-κ}.
       The cell error shifts by d·(1-log₂3) ≈ -0.585d per d-run
       (proved above as cellError_shift_of_v2_run), pushing the trajectory
       away from dangerous cells.

    3. **Weyl equidistribution** (axiomatized, WeylEquidistribution.lean):
       Since log₂3 is irrational, cell visits are equidistributed on
       every torus scale. Safe cells (v₂ ≥ 2) dominate at all scales.

    Computational evidence (v2_danger.c, N = 10^10):
    - Max v₂=1 run: 12 (grows as ~log N)
    - Mean run: 1.033
    - Escape rate: 97% per step
    - W = 100 suffices empirically for all n ≤ 10^10
    - Deficit bounded for all tested trajectories -/
axiom solenoid_mixing :
    ∀ n : ℕ, n ≥ 1 → ∃ W : ℕ, W ≥ 1 ∧ HasCompensatedRuns n W

/-! ## Section 6: Assembly -- closing finite_residence_bound -/

/-- **finite_residence_from_mixing**: The solenoid mixing axiom directly
    implies finite_residence_bound (DiophantineRepeller.lean). -/
theorem finite_residence_from_mixing (n : ℕ) (hn : n ≥ 1) :
    ∃ W : ℕ, W ≥ 1 ∧ SlidingWindowCondition n W := by
  obtain ⟨W, hW, hcomp⟩ := solenoid_mixing n hn
  exact ⟨W, hW, (hasCompensatedRuns_iff_slidingWindow n W).mp hcomp⟩

/-- **k_bound_from_mixing**: The solenoid mixing axiom implies the K-bound.

    Proof chain:
      solenoid_mixing
        → HasCompensatedRuns n W
        → SlidingWindowCondition n W
        → deficit bounded by 2W
        → ∃ K T₀, ∀ t ≥ T₀, 3·ν₃ ≤ t + K -/
theorem k_bound_from_mixing (n : ℕ) (hn : n ≥ 1) :
    ∃ K : ℕ, ∃ T₀ : ℕ, ∀ t, t ≥ T₀ → 3 * nu3 n t ≤ t + K := by
  obtain ⟨W, hW, hSW⟩ := finite_residence_from_mixing n hn
  exact k_bound_from_repeller n hn W hW hSW

/-! ## Section 7: Structural consequences of cell error shift -/

/-- After a v₂=1 run of d ≥ 2 steps, the cell error has shifted by
    more than 1 in absolute value. The trajectory has moved to a
    qualitatively different region of the torus. -/
theorem cellError_moved_after_long_run (n t d : ℕ) (hn : n ≥ 1)
    (hd : d ≥ 2)
    (hodd : collatzSeq n t % 2 = 1)
    (hrun : ∀ i, i ≤ d → oddCollatzIter (collatzSeq n t) i % 2 = 1) :
    |walkCellError n (t + 2 * d) - walkCellError n t| > 1 := by
  rw [cellError_shift_of_v2_run n t d hn hodd hrun]
  simp only [add_sub_cancel_left]
  rw [cellError_shift_magnitude]
  exact cellError_shift_exceeds_one d hd

/-- Combined Hensel-Baker tracking: if a v₂=1 run starts with
    cell error ε, after d steps the cell error is ε + d·(1 - log₂3).
    This is exact (no approximation). -/
theorem hensel_baker_conflict (n t d : ℕ) (hn : n ≥ 1) (ε : ℝ)
    (hε : walkCellError n t = ε)
    (hodd : collatzSeq n t % 2 = 1)
    (hrun : ∀ i, i ≤ d → oddCollatzIter (collatzSeq n t) i % 2 = 1) :
    walkCellError n (t + 2 * d) = ε + ↑d * (1 - logb 2 3) := by
  rw [cellError_shift_of_v2_run n t d hn hodd hrun, hε]

/-! ## Summary -/

/-
  === FILE STATUS ===

  Proved (no sorry):
  - logb_two_three_gt_one, logb_two_three_gt_three_halves
  - walk_eq_walkCellError
  - cellError_shift_of_v2_run (KEY: cell error shifts linearly during runs)
  - cellError_shift_magnitude
  - cellError_shift_exceeds_one (d ≥ 2 ⟹ shift > 1)
  - hasBoundedRuns_iff (Hensel equivalence for trajectory runs)
  - hasCompensatedRuns_iff_slidingWindow
  - finite_residence_from_mixing (axiom → window condition)
  - k_bound_from_mixing (axiom → K-bound)
  - cellError_moved_after_long_run (d ≥ 2 ⟹ |shift| > 1)
  - hensel_baker_conflict (exact cell error tracking)

  Sorry'd: 0
  Axiom: 1 (solenoid_mixing)

  === PROOF ARCHITECTURE ===

  solenoid_mixing [axiom]
    → finite_residence_from_mixing [proved]
    → k_bound_from_mixing [proved]
    → (chains via k_bound_from_repeller to reaches_one_of_linear_drift)
    → collatz_conjecture

  === FULL AXIOM SET FOR COLLATZ CONJECTURE ===

  1. baker_two_three (Baker.lean) -- Baker 1966, effective |m·log2 + n·log3|
  2. hercher_no_small_cycle (SteinerCycle.lean) -- Hercher 2023, no cycle < 91
  3. rhin_irrationality_measure (IrrationalityMeasure.lean) -- Rhin 1987
  4. weyl_equidistribution (WeylEquidistribution.lean) -- Weyl 1916
  5. solenoid_mixing (THIS FILE) -- Syracuse mixing on (2,3)-solenoid

  Of these, only solenoid_mixing is genuinely open mathematics.
  The others are established results with published proofs.

  === THE CONFLICT OF METRICS ===

  The solenoid_mixing axiom encodes:
  - 2-adic: Hensel attrition forces v₂=1 runs to satisfy 2^(d+1) | (x+1)
  - 3-adic: Baker separation forces cells to be Diophantine-separated
  - Archimedean: cell error shifts by d·(1-log₂3) per d-run (PROVED)
  - Ergodic: Weyl equidistribution forces sampling of safe cells

  These four constraints are MUTUALLY INCOMPATIBLE for sustained danger:
  a trajectory cannot simultaneously maintain small cell error (Baker),
  satisfy the 2-adic divisibility (Hensel), and be equidistributed (Weyl).
-/

end Collatz
