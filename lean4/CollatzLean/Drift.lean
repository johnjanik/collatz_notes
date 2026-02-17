/-
  CollatzLean/Drift.lean
  Phase 4a: Uniform drift bound and walk divergence.
  From a uniform ε-gap below equilibrium for the odd-step proportion,
  we derive a linear lower bound on the walk and conclude divergence.
-/
import CollatzLean.Walk
import Mathlib.Topology.Order.Basic
import Mathlib.Order.Filter.AtTopBot.Basic

namespace Collatz

open Real Filter

/-! ## Uniform bound on odd-step proportion -/

/-- Uniform ε-gap: ∃ ε > 0 and T₀ such that ν₃(n,t)/t ≤ p_eq - ε for all t ≥ T₀.
    Requires ergodic theory for the Collatz transfer operator combined with
    the golden mean SFT constraint. -/
theorem podd_uniform_bound (n : ℕ) (hn : n ≥ 1) :
    ∃ ε > 0, ∃ T₀, ∃ K : ℕ,
      (∀ t, t ≥ T₀ → (↑(nu3 n t) / ↑t : ℝ) ≤ p_equilibrium - ε) ∧
      (∀ t, t ≥ T₀ → 3 * nu3 n t ≤ t + K) := by
  sorry

/-! ## Walk drift form -/

/-- The walk can be written as t - (1 + logb 2 3) · ν₃. -/
theorem walk_eq_drift_form (n t : ℕ) :
    walk n t = ↑t - (1 + logb 2 3) * ↑(nu3 n t) := by
  unfold walk
  have hpart : (nu2 n t : ℝ) = ↑t - ↑(nu3 n t) := by
    have h := nu_partition n t
    have : (nu2 n t : ℝ) + ↑(nu3 n t) = ↑t := by exact_mod_cast h
    linarith
  rw [hpart]
  ring

/-! ## Linear lower bound -/

/-- From the uniform bound, the walk grows at least linearly. -/
theorem walk_lower_bound_linear (n : ℕ) (_hn : n ≥ 1) (ε : ℝ) (_hε : ε > 0)
    (T₀ : ℕ) (hbound : ∀ t, t ≥ T₀ → (↑(nu3 n t) / ↑t : ℝ) ≤ p_equilibrium - ε) :
    ∀ t, t ≥ T₀ → t ≥ 1 → walk n t ≥ (1 + logb 2 3) * ε * ↑t := by
  intro t ht ht1
  rw [walk_eq_drift_form]
  have hlog_pos : logb 2 3 > 0 :=
    logb_pos (by norm_num : (1 : ℝ) < 2) (by norm_num : (1 : ℝ) < 3)
  have h1log_pos : 1 + logb 2 3 > 0 := by linarith
  have ht_pos : (t : ℝ) > 0 := by positivity
  have ht_ne : (t : ℝ) ≠ 0 := ne_of_gt ht_pos
  have hnu3_bound : (↑(nu3 n t) : ℝ) ≤ (p_equilibrium - ε) * ↑t := by
    have h := hbound t ht
    rwa [div_le_iff₀ ht_pos] at h
  -- Goal: ↑t - (1 + logb 2 3) * ↑(nu3 n t) ≥ (1 + logb 2 3) * ε * ↑t
  -- From hnu3_bound: (1 + logb 2 3) * ↑(nu3 n t) ≤ (1 + logb 2 3) * (p_eq - ε) * t
  -- So: ↑t - (1 + logb 2 3) * ↑(nu3 n t) ≥ t - (1 + logb 2 3) * (p_eq - ε) * t
  --                                         = t * (1 - (1 + logb 2 3) * (p_eq - ε))
  -- Since (1 + logb 2 3) * p_eq = 1:
  --   = t * (1 - (1 - (1 + logb 2 3) * ε))
  --   = t * (1 + logb 2 3) * ε
  have step1 : (1 + logb 2 3) * ↑(nu3 n t) ≤ (1 + logb 2 3) * ((p_equilibrium - ε) * ↑t) := by
    exact mul_le_mul_of_nonneg_left hnu3_bound (le_of_lt h1log_pos)
  have peq_identity : (1 + logb 2 3) * p_equilibrium = 1 := by
    unfold p_equilibrium
    field_simp
  nlinarith

/-! ## Abstract divergence from linear growth -/

/-- If f(t) ≥ δ · t for all t ≥ T₀ with δ > 0, then f → +∞. -/
theorem tendsto_atTop_of_eventually_linear (f : ℕ → ℝ) (δ : ℝ) (hδ : δ > 0)
    (T₀ : ℕ) (hlin : ∀ t, t ≥ T₀ → f t ≥ δ * ↑t) :
    Filter.Tendsto f Filter.atTop Filter.atTop := by
  rw [Filter.tendsto_atTop_atTop]
  intro B
  -- Take T = max(T₀, ⌈B/δ⌉ + 1) to ensure δ · T > B
  obtain ⟨N, hN⟩ : ∃ N : ℕ, B < δ * ↑N := by
    refine ⟨T₀ + (Nat.ceil (max B 0 / δ) + 1), ?_⟩
    have hceil : (max B 0 / δ) ≤ ↑(Nat.ceil (max B 0 / δ)) := Nat.le_ceil _
    have : (T₀ + (Nat.ceil (max B 0 / δ) + 1) : ℝ) ≥ Nat.ceil (max B 0 / δ) + 1 := by
      exact_mod_cast Nat.le_add_left _ _
    calc B ≤ max B 0 := le_max_left B 0
      _ = δ * (max B 0 / δ) := by field_simp
      _ ≤ δ * ↑(Nat.ceil (max B 0 / δ)) := by exact mul_le_mul_of_nonneg_left hceil (le_of_lt hδ)
      _ < δ * ↑(T₀ + (Nat.ceil (max B 0 / δ) + 1)) := by
          apply mul_lt_mul_of_pos_left _ hδ
          push_cast; linarith [Nat.zero_le T₀]
  refine ⟨max T₀ N, fun t ht => ?_⟩
  have ht0 : t ≥ T₀ := le_of_max_le_left ht
  have htN : t ≥ N := le_of_max_le_right ht
  have h1 : f t ≥ δ * ↑t := hlin t ht0
  have h2 : δ * ↑t ≥ δ * ↑N := mul_le_mul_of_nonneg_left (by exact_mod_cast htN) (le_of_lt hδ)
  linarith

/-! ## Walk divergence from uniform bound -/

/-- Composition: uniform ε-bound → linear growth → walk diverges to +∞. -/
theorem walk_diverges_of_podd_bound (n : ℕ) (hn : n ≥ 1) :
    Filter.Tendsto (fun t => walk n t) Filter.atTop Filter.atTop := by
  obtain ⟨ε, hε, T₀, _K, hbound, _⟩ := podd_uniform_bound n hn
  have hlog_pos : logb 2 3 > 0 :=
    logb_pos (by norm_num : (1 : ℝ) < 2) (by norm_num : (1 : ℝ) < 3)
  have h1log_pos : 1 + logb 2 3 > 0 := by linarith
  set δ := (1 + logb 2 3) * ε with hδ_def
  have hδ : δ > 0 := mul_pos h1log_pos hε
  apply tendsto_atTop_of_eventually_linear _ δ hδ (max T₀ 1)
  intro t ht
  have ht0 : t ≥ T₀ := le_of_max_le_left ht
  have ht1 : t ≥ 1 := le_of_max_le_right ht
  have := walk_lower_bound_linear n hn ε hε T₀ hbound t ht0 ht1
  linarith

end Collatz
