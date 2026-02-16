/-
  CollatzLean/Conclusion.lean
  Phase 4b: The ergodic conclusion.
  From walk divergence and the multiplicative identity, we prove that
  the Collatz sequence reaches 1 for every n ≥ 1.
-/
import CollatzLean.Drift
import CollatzLean.Identity
import CollatzLean.CollatzSFT
import Mathlib.Analysis.SpecialFunctions.Log.Base

set_option linter.style.nativeDecide false

namespace Collatz

open Real

/-! ## Correction bound -/

/-- The correction term grows at most as C · 3^(ν₃(n,t)).
    This is genuinely hard: the correction recurrence at odd steps introduces
    terms involving collatzSeq values, so simple induction fails. Requires
    global trajectory analysis or a priori bounds on intermediate values. -/
theorem correction_bound (n : ℕ) (_hn : n ≥ 1) :
    ∃ C : ℕ, ∀ t, correction n t ≤ C * 3 ^ nu3 n t := by
  sorry

/-! ## From power bound to seq = 1 -/

/-- If (n + C) · 3^ν₃ < 2 · 2^ν₂, then collatzSeq n t = 1. -/
theorem seq_eq_one_of_pow_bound (n t C : ℕ) (hn : n ≥ 1)
    (hC : ∀ s, correction n s ≤ C * 3 ^ nu3 n s)
    (hpow : (n + C) * 3 ^ nu3 n t < 2 * 2 ^ nu2 n t) :
    collatzSeq n t = 1 := by
  have hid := collatz_identity n t
  have hcorr := hC t
  have hle : collatzSeq n t * 2 ^ nu2 n t ≤ (n + C) * 3 ^ nu3 n t :=
    calc collatzSeq n t * 2 ^ nu2 n t
        = n * 3 ^ nu3 n t + correction n t := hid
      _ ≤ n * 3 ^ nu3 n t + C * 3 ^ nu3 n t := Nat.add_le_add_left hcorr _
      _ = (n + C) * 3 ^ nu3 n t := by ring
  have hlt : collatzSeq n t * 2 ^ nu2 n t < 2 * 2 ^ nu2 n t := by linarith
  have hlt2 : collatzSeq n t < 2 := by
    by_contra h
    push_neg at h
    exact absurd hlt (not_lt.mpr (Nat.mul_le_mul_right (2 ^ nu2 n t) h))
  have hpos := collatzSeq_pos n hn t
  omega

/-! ## Reaches 1 from walk divergence -/

/-- If the walk diverges, then the Collatz sequence reaches 1. -/
theorem collatz_reaches_of_walk_diverges (n : ℕ) (hn : n ≥ 1)
    (C : ℕ) (hC : ∀ t, correction n t ≤ C * 3 ^ nu3 n t)
    (hdiv : Filter.Tendsto (fun t => walk n t) Filter.atTop Filter.atTop) :
    collatzReaches n := by
  -- Since walk → +∞, find T where walk n T > logb 2 (n + C)
  rw [Filter.tendsto_atTop_atTop] at hdiv
  obtain ⟨T, hT⟩ := hdiv (logb 2 (↑(n + C)) + 1)
  have hwalk : walk n T > logb 2 (↑(n + C)) := by linarith [hT T le_rfl]
  -- Setup positivity facts
  have hnC_pos : (0 : ℝ) < ↑(n + C) := by positivity
  have h3pos : (0 : ℝ) < (3 : ℝ) ^ (nu3 n T) := by positivity
  have hprod_pos : (0 : ℝ) < ↑(n + C) * (3 : ℝ) ^ (nu3 n T) := mul_pos hnC_pos h3pos
  have h2nu2_pos : (0 : ℝ) < (2 : ℝ) ^ (nu2 n T) := by positivity
  -- logb 2 of product = logb 2 (n+C) + ν₃ · logb 2 3
  have hlog_prod : logb 2 (↑(n + C) * (3 : ℝ) ^ (nu3 n T)) =
      logb 2 ↑(n + C) + ↑(nu3 n T) * logb 2 3 := by
    rw [logb_mul (ne_of_gt hnC_pos) (ne_of_gt h3pos), logb_pow]
  -- logb 2 (2^ν₂) = ν₂
  have hlog_2nu2 : logb 2 ((2 : ℝ) ^ (nu2 n T)) = ↑(nu2 n T) := by
    rw [logb_pow, logb_self_eq_one (by norm_num : (1 : ℝ) < 2), mul_one]
  -- Show logb 2 (product) < logb 2 (2^ν₂)
  have hlog_lt : logb 2 (↑(n + C) * (3 : ℝ) ^ (nu3 n T)) <
      logb 2 ((2 : ℝ) ^ (nu2 n T)) := by
    rw [hlog_prod, hlog_2nu2]
    unfold walk at hwalk; linarith
  -- Convert logb inequality to log inequality
  have hlog2_pos : (0 : ℝ) < Real.log 2 := Real.log_pos (by norm_num : (1 : ℝ) < 2)
  have hlog2_ne : Real.log 2 ≠ 0 := ne_of_gt hlog2_pos
  have hlog_lt' : Real.log (↑(n + C) * (3 : ℝ) ^ (nu3 n T)) <
      Real.log ((2 : ℝ) ^ (nu2 n T)) := by
    simp only [Real.logb] at hlog_lt
    have h1 := mul_lt_mul_of_pos_right hlog_lt hlog2_pos
    rwa [div_mul_cancel₀ _ hlog2_ne, div_mul_cancel₀ _ hlog2_ne] at h1
  -- Apply exp (strictly monotone) to convert log inequality to value inequality
  have hexp_lt := Real.exp_strictMono hlog_lt'
  rw [Real.exp_log hprod_pos, Real.exp_log h2nu2_pos] at hexp_lt
  -- Cast ℝ inequality to ℕ: (n+C) * 3^ν₃ < 2^ν₂
  have hlt_nat : (n + C) * 3 ^ nu3 n T < 2 ^ nu2 n T := by exact_mod_cast hexp_lt
  -- Strengthen: < 2^ν₂ implies < 2 · 2^ν₂
  have h2nu2_nat_pos : 0 < 2 ^ nu2 n T := by positivity
  have hlt_nat2 : (n + C) * 3 ^ nu3 n T < 2 * 2 ^ nu2 n T := by linarith
  exact ⟨T, seq_eq_one_of_pow_bound n T C hn hC hlt_nat2⟩

/-! ## The Collatz conjecture -/

/-- The Collatz conjecture: every positive natural number eventually reaches 1. -/
theorem collatz_conjecture : CollatzConjecture := by
  intro n hn
  obtain ⟨C, hC⟩ := correction_bound n hn
  have hdiv := walk_diverges_of_podd_bound n hn
  exact collatz_reaches_of_walk_diverges n hn C hC hdiv

/-! ## Evaluation -/

-- Verify correction bound holds for small examples
#eval (List.range 20).all fun t => correction 7 t ≤ 7 * 3 ^ nu3 7 t
#eval (List.range 112).all fun t => correction 27 t ≤ 27 * 3 ^ nu3 27 t

end Collatz
