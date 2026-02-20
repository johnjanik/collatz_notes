/-
  CollatzLean/SolenoidMixing.lean

  Cell error algebra on the (2,3)-solenoid and structural consequences
  of the Hensel-Baker conflict.

  This file connects the three proved components:
  1. Hensel attrition (HenselAttrition.lean) -- v₂=1 runs ↔ 2^{d+1} | (x+1)
  2. Baker cell separation (DiophantineRepeller.lean) -- cells Diophantine-separated
  3. Cell error shift algebra (this file) -- d·(1-log₂3) shift per d-run

  Key content (all sorry-free, no axioms):
  - walkCellError: the walk as a cell error on the torus
  - cellError_shift_of_v2_run: cell error shifts by d·(1-log₂3) during d-run
  - cellError_shift_exceeds_one: |shift| > 1 for d ≥ 2
  - hensel_baker_conflict: exact cell error tracking during runs
  - HasBoundedRuns / HasBoundedDangerousRuns: Hensel equivalence for runs

  NOTE (2026-02-19): The former `solenoid_mixing` axiom
  (∀ n ≥ 1, ∃ W, HasCompensatedRuns n W) has been REMOVED because
  HasCompensatedRuns ↔ SlidingWindowCondition, and SWC is FALSE for n=27
  and ~42.6% of starting values. See BUG NOTE in DiophantineRepeller.lean.
  The correct gap is finite_deficit_bound (∃ D, ∀ t, deficit ≤ D) in
  DiophantineRepeller.lean, which is equivalent to the Collatz conjecture.
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

/-! ## Section 5: BUG NOTE — SlidingWindowCondition is FALSE

    The former `solenoid_mixing` axiom asserted:
      ∀ n ≥ 1, ∃ W ≥ 1, HasCompensatedRuns n W
    where HasCompensatedRuns ↔ SlidingWindowCondition ↔ ∀ t, deficit(t+W) ≤ deficit(t).

    This is FALSE. Counterexample: n = 27.
    - deficit(0) = 0, deficit(111) = 12 (41 odd steps in 111 total)
    - After reaching 1→4→2→1 cycle, deficit stabilizes at {12, 13, 14}
    - For any W: deficit(0+W) ≈ 12 > 0 = deficit(0), so SWC fails at t=0
    - Similarly fails for n=31,63,97 and ~42.6% of n ≤ 10^7

    The correct formulation is the **finite deficit bound**:
      ∀ n ≥ 1, ∃ D : ℤ, ∀ t, deficit(n, t) ≤ D
    This IS true (for n=27: D=14) and is equivalent to the K-bound and to
    the Collatz conjecture. See finite_deficit_bound in DiophantineRepeller.lean.

    The proved infrastructure in this file (cell error shift, Hensel-Baker
    conflict, bounded runs) remains correct and does NOT depend on SWC.
    The HasCompensatedRuns definition is retained as valid but not universally
    satisfiable. -/

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

/-! ## Section 8: Solenoid bridge infrastructure

    Supporting lemmas for closing `cellSeqNu2_equidistributed`
    (WeylEquidistribution.lean). At Syracuse step k:
      ν₂ = syracuseValSum n k = log₂3 · k + walk(syracuseTime n k)
    The Weyl sequence is k ↦ ⌊k · log₂3⌋, so the distance between
    the Collatz cell sequence and the irrational rotation is |walk|. -/

/-- At Syracuse step k, ν₂ decomposes as log₂3 · k plus walk correction. -/
theorem nu2_syracuse_decomposition (n k : ℕ) (hn : n ≥ 1) (hodd : n % 2 = 1) :
    (nu2 n (syracuseTime n k) : ℝ) = logb 2 3 * ↑k + walk n (syracuseTime n k) := by
  rw [nu2_at_syracuseTime n k hn hodd]; linarith [walk_from_syracuse n k hn hodd]

/-- Distance between syracuseValSum and log₂3 · k equals |walk|. -/
theorem syracuseValSum_near_rotation (n k : ℕ) (hn : n ≥ 1) (hodd : n % 2 = 1) :
    |(↑(syracuseValSum n k) : ℝ) - logb 2 3 * ↑k| = |walk n (syracuseTime n k)| := by
  congr 1; exact (walk_from_syracuse n k hn hodd).symm

/-- cellSeqNu2 equals syracuseValSum mod N (definitional unfolding). -/
theorem cellSeqNu2_eq_syracuseValSum_mod (n N k : ℕ) (hn : n ≥ 1) (hodd : n % 2 = 1) :
    cellSeqNu2 n N k = syracuseValSum n k % N := by
  unfold cellSeqNu2; rw [nu2_at_syracuseTime n k hn hodd]

/-- Equidistribution is invariant under mod-reduction: seq % N and seq
    have the same residue statistics mod N. -/
theorem isEquidistributed_mod_eq (seq : ℕ → ℕ) (N : ℕ) (hN : N ≥ 2) :
    IsEquidistributed (fun k => seq k % N) N ↔ IsEquidistributed seq N := by
  have key : ∀ k, seq k % N % N = seq k % N :=
    fun k => Nat.mod_eq_of_lt (Nat.mod_lt (seq k) (by omega))
  simp_rw [IsEquidistributed, key]

/-- **Equidistribution transfer for perturbed irrational rotations**.
    If α is irrational and seq(k) tracks α·k with o(k) error,
    then seq is equidistributed mod N.

    NOTE: The analogous statement for GENERAL equidistributed sequences
    is FALSE. Counterexample: seq1(k) = k is equidistributed mod 4,
    e(k) = k mod 4 = o(k), but (k + k mod 4) mod 4 ∈ {0, 2} only.
    The irrational rotation structure is essential.

    Proof would use quantitative Weyl discrepancy bounds for irrational
    rotations, which absorb sublinear perturbations. -/
theorem perturbed_rotation_equidistributed (α : ℝ) (hα : Irrational α)
    (seq : ℕ → ℕ) (N : ℕ) (hN : N ≥ 2)
    (hclose : ∀ ε : ℝ, ε > 0 → ∃ K₀ : ℕ, ∀ k : ℕ, k ≥ K₀ →
      |(↑(seq k) : ℝ) - α * ↑k| ≤ ε * ↑k) :
    IsEquidistributed seq N := by
  sorry

/-- If the walk grows sublinearly at Syracuse boundaries, then
    syracuseValSum is equidistributed mod N. -/
theorem syracuseValSum_equidistributed_of_sublinear_walk (n : ℕ) (hn : n ≥ 1)
    (hodd : n % 2 = 1) (N : ℕ) (hN : N ≥ 2)
    (hwalk : ∀ ε : ℝ, ε > 0 → ∃ K₀ : ℕ, ∀ k : ℕ, k ≥ K₀ →
      |walk n (syracuseTime n k)| ≤ ε * ↑k) :
    IsEquidistributed (fun k => syracuseValSum n k) N := by
  apply perturbed_rotation_equidistributed (logb 2 3) irrational_logb_two_three _ N hN
  intro ε hε
  obtain ⟨K₀, hK⟩ := hwalk ε hε
  exact ⟨K₀, fun k hk => by rw [syracuseValSum_near_rotation n k hn hodd]; exact hK k hk⟩

/-- **Full solenoid bridge assembly**: sublinear walk → cellSeqNu2 equidistributed.
    This is exactly the hypothesis needed to close `cellSeqNu2_equidistributed`
    in WeylEquidistribution.lean, modulo proving the walk is sublinear. -/
theorem cellSeqNu2_of_sublinear_walk (n : ℕ) (hn : n ≥ 1) (hodd : n % 2 = 1)
    (N : ℕ) (hN : N ≥ 2)
    (hwalk : ∀ ε : ℝ, ε > 0 → ∃ K₀ : ℕ, ∀ k : ℕ, k ≥ K₀ →
      |walk n (syracuseTime n k)| ≤ ε * ↑k) :
    IsEquidistributed (cellSeqNu2 n N) N := by
  have h1 := syracuseValSum_equidistributed_of_sublinear_walk n hn hodd N hN hwalk
  rw [show cellSeqNu2 n N = fun k => syracuseValSum n k % N from
    funext (fun k => cellSeqNu2_eq_syracuseValSum_mod n N k hn hodd)]
  exact (isEquidistributed_mod_eq _ N hN).mpr h1

/-! ## Summary -/

/-
  === FILE STATUS ===

  Proved (no sorry, 15 theorems):
  - logb_two_three_gt_one, logb_two_three_gt_three_halves
  - walk_eq_walkCellError
  - cellError_shift_of_v2_run (KEY: cell error shifts linearly during runs)
  - cellError_shift_magnitude, cellError_shift_exceeds_one (d ≥ 2 ⟹ shift > 1)
  - hasBoundedRuns_iff, hasCompensatedRuns_iff_slidingWindow
  - cellError_moved_after_long_run, hensel_baker_conflict
  - nu2_syracuse_decomposition (ν₂ = log₂3·k + walk)
  - syracuseValSum_near_rotation (|valSum - log₂3·k| = |walk|)
  - cellSeqNu2_eq_syracuseValSum_mod (cellSeqNu2 = valSum % N)
  - isEquidistributed_mod_eq (seq%N equidist ↔ seq equidist)
  - syracuseValSum_equidistributed_of_sublinear_walk (chains rotation+walk)
  - cellSeqNu2_of_sublinear_walk (full assembly: walk sublinear → equidist)

  Sorry'd: 1
  - perturbed_rotation_equidistributed (Weyl + discrepancy, NOT Collatz-equiv)

  Axioms: 0

  === SOLENOID BRIDGE DECOMPOSITION ===

  cellSeqNu2_equidistributed (WeylEquidistribution.lean sorry) decomposes as:
    1. walk sublinear at Syracuse boundaries [open — related to ergodicity]
    2. perturbed_rotation_equidistributed [sorry — standard number theory]
    3. syracuseValSum_equidistributed_of_sublinear_walk [proved, chains 1+2]
    4. cellSeqNu2_of_sublinear_walk [proved, chains 3 + mod reduction]

  This isolates the Collatz-specific content (sublinear walk, item 1) from
  the pure number theory (perturbed Weyl, item 2). Neither is Collatz-equivalent
  individually; together they close the solenoid bridge.
-/

end Collatz
