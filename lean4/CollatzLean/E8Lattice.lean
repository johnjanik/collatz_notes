/-
  CollatzLean/E8Lattice.lean

  Constructive E₈ root lattice: all 240 roots enumerated over ℚ,
  with cardinality, norm, and inner product properties proved by native_decide.

  Phase 1 of axiom reduction for RiemannHypothesis.lean.
  The ℝ bridge (casting ℚ → ℝ) is in RiemannHypothesis.lean.
-/

import Mathlib.Algebra.BigOperators.Group.Finset.Defs
import Mathlib.Data.Rat.Defs
import Mathlib.Data.Fintype.Pi

set_option linter.style.nativeDecide false

namespace E8Lattice

open scoped BigOperators

-- =====================================================
-- ROOT GENERATORS
-- =====================================================

/-- All elements of Fin 8 as a list. -/
private def fins : List (Fin 8) := List.ofFn id

/-- Extract bit k from natural number n. -/
def getBit (n k : ℕ) : Bool := (n / 2 ^ k) % 2 == 1

/-- Type I root: value s₁ at position i, value s₂ at position j, zero elsewhere. -/
def mkTypeI (i j : Fin 8) (s1 s2 : ℚ) : Fin 8 → ℚ :=
  fun k => if k = i then s1 else if k = j then s2 else 0

/-- Type II root: (±½)⁸ from bitmask. Bit 1 → +½, bit 0 → -½. -/
def mkTypeII (mask : ℕ) : Fin 8 → ℚ :=
  fun k => if getBit mask k.val then (1 : ℚ) / 2 else -(1 : ℚ) / 2

-- =====================================================
-- ROOT ENUMERATION
-- =====================================================

/-- All 112 Type I roots: ±eᵢ ± eⱼ for 0 ≤ i < j ≤ 7. -/
def rootsTypeI : List (Fin 8 → ℚ) :=
  fins.flatMap fun i => fins.flatMap fun j =>
    if i < j then
      [(1 : ℚ), -1].flatMap fun s1 =>
        [(1 : ℚ), -1].flatMap fun s2 =>
          [mkTypeI i j s1 s2]
    else []

/-- All 128 Type II roots: (±½)⁸ with even number of minus signs. -/
def rootsTypeII : List (Fin 8 → ℚ) :=
  (List.range 256).filterMap fun mask =>
    if (fins.countP fun k => !getBit mask k.val) % 2 == 0
    then some (mkTypeII mask)
    else none

/-- All 240 E₈ roots as a list over ℚ. -/
def allRootsQ : List (Fin 8 → ℚ) := rootsTypeI ++ rootsTypeII

/-- The E₈ root system as a Finset over ℚ. -/
def e8RootsQ : Finset (Fin 8 → ℚ) := allRootsQ.toFinset

-- =====================================================
-- OPERATIONS
-- =====================================================

/-- Squared norm of a rational 8-vector: ∑ᵢ vᵢ². -/
def normSqQ (v : Fin 8 → ℚ) : ℚ := ∑ i : Fin 8, v i * v i

/-- Inner product of two rational 8-vectors: ∑ᵢ vᵢwᵢ. -/
def innerQ (v w : Fin 8 → ℚ) : ℚ := ∑ i : Fin 8, v i * w i

-- =====================================================
-- PROOFS BY NATIVE COMPUTATION
-- =====================================================

/-- The E₈ root system has exactly 240 elements. -/
theorem card_eq_240 : e8RootsQ.card = 240 := by native_decide

/-- Every E₈ root has squared norm exactly 2. -/
theorem norm_sq_eq_2 : ∀ α ∈ e8RootsQ, normSqQ α = 2 := by native_decide

/-- The inner product of any two E₈ roots lies in {-2, -1, 0, 1, 2}. -/
theorem inner_in_range : ∀ α ∈ e8RootsQ, ∀ β ∈ e8RootsQ,
    innerQ α β = -2 ∨ innerQ α β = -1 ∨ innerQ α β = 0 ∨
    innerQ α β = 1 ∨ innerQ α β = 2 := by native_decide

end E8Lattice
