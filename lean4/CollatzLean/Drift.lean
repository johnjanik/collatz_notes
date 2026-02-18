/-
  CollatzLean/Drift.lean
  The K-bound (nu3_linear_bound) and walk divergence infrastructure.

  Critical path sorry: nu3_linear_bound — the sole hypothesis needed by
  reaches_one_of_linear_drift and hence collatz_conjecture.

  Off critical path: podd_uniform_bound (now proved from nu3_linear_bound),
  walk_lower_bound_linear, walk_diverges_of_podd_bound — proved infrastructure
  for the ε-drift and walk divergence narrative, retained but not used by
  the main theorem.
-/
import CollatzLean.Walk
import Mathlib.Topology.Order.Basic
import Mathlib.Order.Filter.AtTopBot.Basic

namespace Collatz

open Real Filter

/-! ## The linear bound on odd-step count (critical path) -/

/-- The K-bound: the sole sorry on the critical path to collatz_conjecture.
    Equivalent to the Collatz conjecture for n: implies trajectory bounded
    (a(t) ≤ n·2^K), hence eventually periodic, hence cycle = {1,2,4}. -/
theorem nu3_linear_bound (n : ℕ) (hn : n ≥ 1) :
    ∃ K : ℕ, ∃ T₀ : ℕ, ∀ t, t ≥ T₀ → 3 * nu3 n t ≤ t + K := by
  sorry

/-! ## Deriving the ε-bound from the K-bound -/

private lemma logb_two_three_lt_two : logb 2 3 < 2 := by
  have hlog2 : (0 : ℝ) < log 2 := log_pos (by norm_num)
  rw [logb, div_lt_iff₀ hlog2]
  calc log 3 < log 4 := log_lt_log (by positivity) (by norm_num)
    _ = log (2 ^ 2) := by norm_num
    _ = 2 * log 2 := by rw [log_pow]; ring

private lemma one_plus_logb23_pos : (0 : ℝ) < 1 + logb 2 3 := by
  linarith [logb_pos (by norm_num : (1 : ℝ) < 2) (by norm_num : (1 : ℝ) < 3)]

private lemma p_equilibrium_gt_one_third : p_equilibrium > 1 / 3 := by
  show 1 / 3 < p_equilibrium
  unfold p_equilibrium
  exact div_lt_div_of_pos_left one_pos one_plus_logb23_pos (by linarith [logb_two_three_lt_two])

/-- Uniform ε-gap derived from nu3_linear_bound.
    Since 3·ν₃ ≤ t + K gives ν₃/t ≤ 1/3 + K/(3t), and p_equilibrium > 1/3
    (because log₂3 < 2, i.e. 3 < 4), for large enough t the ε-bound holds. -/
theorem podd_uniform_bound (n : ℕ) (hn : n ≥ 1) :
    ∃ ε > 0, ∃ T₀, ∃ K : ℕ,
      (∀ t, t ≥ T₀ → (↑(nu3 n t) / ↑t : ℝ) ≤ p_equilibrium - ε) ∧
      (∀ t, t ≥ T₀ → 3 * nu3 n t ≤ t + K) := by
  obtain ⟨K, T₀, hbound3⟩ := nu3_linear_bound n hn
  have hpeq := p_equilibrium_gt_one_third
  set gap := p_equilibrium - 1 / 3 with hgap_def
  have hgap_pos : gap > 0 := by linarith
  -- ε = gap/2, T₁ = ⌈2K/(3·gap)⌉₊ + 1 ensures K/(3t) < gap/2 for t ≥ T₁
  refine ⟨gap / 2, by linarith, max T₀ (⌈2 * (↑K : ℝ) / (3 * gap)⌉₊ + 1), K, ?_,
         fun t ht => hbound3 t (le_trans (le_max_left ..) ht)⟩
  intro t ht
  have ht0 : t ≥ T₀ := le_trans (le_max_left ..) ht
  have htN : t ≥ ⌈2 * (↑K : ℝ) / (3 * gap)⌉₊ + 1 := le_trans (le_max_right ..) ht
  have ht_pos : (0 : ℝ) < ↑t := Nat.cast_pos.mpr (by omega)
  -- ν₃ ≤ (t + K) / 3 in ℝ
  have hnu3_le : (↑(nu3 n t) : ℝ) ≤ (↑t + ↑K) / 3 := by
    have : (3 : ℝ) * ↑(nu3 n t) ≤ ↑t + ↑K := by exact_mod_cast hbound3 t ht0
    linarith
  -- t > 2K/(3·gap)
  have ht_gt : (↑t : ℝ) > 2 * ↑K / (3 * gap) := by
    have hceil : 2 * (↑K : ℝ) / (3 * gap) ≤ ↑(⌈2 * (↑K : ℝ) / (3 * gap)⌉₊) :=
      Nat.le_ceil _
    have : (↑t : ℝ) ≥ ↑(⌈2 * (↑K : ℝ) / (3 * gap)⌉₊) + 1 := by exact_mod_cast htN
    linarith
  -- Cross-multiply: 2K < 3·gap·t
  have h_key : 2 * (↑K : ℝ) < 3 * gap * ↑t := by
    have h3g_pos : (0 : ℝ) < 3 * gap := by positivity
    calc 2 * (↑K : ℝ) = 3 * gap * (2 * ↑K / (3 * gap)) := by field_simp
      _ < 3 * gap * ↑t := by nlinarith
  -- Goal: ν₃/t ≤ p_eq - gap/2. Rewrite as ν₃ ≤ (p_eq - gap/2) * t.
  rw [div_le_iff₀ ht_pos]
  -- p_eq - gap/2 = 1/3 + gap/2, so suffices ν₃ ≤ (1/3 + gap/2) * t
  suffices (↑(nu3 n t) : ℝ) ≤ (1 / 3 + gap / 2) * ↑t by
    have : p_equilibrium - gap / 2 = 1 / 3 + gap / 2 := by simp only [hgap_def]; ring
    nlinarith
  -- From ν₃ ≤ (t+K)/3 and 2K < 3·gap·t → K/3 < gap·t/2
  nlinarith [hnu3_le, h_key]

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
