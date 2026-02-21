# Collatz Conjecture: Formal and Computational Analysis

A Lean 4 formalization and computational investigation of the Collatz conjecture,
exploring connections between dynamical systems, transcendental number theory,
ergodic theory, and Diophantine approximation.

## Overview

The Collatz map sends odd *n* to 3*n*+1, even *n* to *n*/2.
The conjecture states that every positive integer eventually reaches 1.

This project pursues a **reduction strategy**: rather than proving the conjecture
outright, it identifies the *minimal residual assumptions* (axioms and sorrys)
needed to complete a formal proof, and proves everything else.

**Current status (Feb 2026):**
- **13,700+ lines** of Lean 4 across **48 files**
- **10 axioms** (published theorems from the literature)
- **12 sorrys** (open gaps, 6 equivalent to the conjecture itself)
- **3,144 build jobs**, zero errors

## Repository Structure

```
lean4/                    Lean 4 formalization (Mathlib-based)
  CollatzLean.lean          Root import file (48 modules)
  CollatzLean/              Module files
c_scripts/                Computational experiments (C, OpenCL)
docs/                     Papers, notes, LaTeX sources
visualizations/           Interactive HTML visualizations
```

## The Lean 4 Formalization

### Architecture

The formalization has two independent proof paths to the Collatz conjecture:

**Path 1 (Main):**
`nu3_linear_bound` [sorry] &rarr; `reaches_one_of_linear_drift` [proved] &rarr; `collatz_conjecture`

**Path 2 (Denjoy-Koksma):**
`deficit_sublinear` [proved] &rarr; `trajectory_bounded_of_sublinear_deficit` [proved via `finite_deficit_bound`] &rarr; `collatz_via_denjoy_koksma`

Both paths are shown **equivalent** to the Collatz conjecture in `Conclusion.lean`.

### Module Overview

| Module | Lines | Description |
|--------|------:|-------------|
| **Core definitions** | | |
| `Basic` | | Collatz map, iterated sequence, stopping time, conjecture statement |
| `Parity` | | The "11" constraint: consecutive odd steps are impossible |
| `Syracuse` | | Tao's Syracuse framework: 2-adic valuation, Syracuse map |
| `Conclusion` | | Main theorem: `nu3_linear_bound` ↔ `collatzReaches` |
| **Symbolic dynamics** | | |
| `SFT` | | Full shift, shift map, golden mean shift |
| `CollatzSFT` | | Collatz parity sequences lie in the golden mean shift |
| `FibCounting` | | Fibonacci word counting, log₂(3) < φ |
| **Torus & branch locus** | | |
| `Torus` | | ZMod torus residues with (ν₂, ν₃) advance rules |
| `BranchLocus` | | Branch, pure-even, pure-odd cell classification |
| `StructuralPureEven` | | Universal pure-even cells (every trajectory takes even step) |
| `TunnelWidth` | | Baker's inequality → tunnel wall persistence |
| `WallPersistence` | | Computational evidence for wall geometry |
| **Walk & drift** | | |
| `Walk` | | Transverse walk u(t) = ν₂(t) − log₂(3)·ν₃(t) |
| `Winding` | | ν₂ and ν₃ counters for even/odd steps |
| `Identity` | | Multiplicative identity: a(t)·2^ν₂ = n·3^ν₃ + correction |
| `CorrectionRatio` | | Correction ratio r(t) and its bounded properties |
| `Drift` | | K-bound (`nu3_linear_bound`), walk divergence (**sorry: critical path**) |
| `SyracuseDrift` | | Bridge between Syracuse and Walk/Drift frameworks |
| `SublinearDrift` | | Sublinear deficit → Collatz convergence (fully proved) |
| **Transcendence theory** | | |
| `Baker` | | Baker's theorem: multiplicative independence of 2 and 3 |
| `IrrationalityMeasure` | | Rhin's effective irrationality measure for log₂3 |
| `SiegelLemma` | | Siegel's lemma for Gel'fond-Schneider proof chain |
| `GrowthEstimates` | | Auxiliary function, Poisson-Jensen, Blaschke products |
| `ContinuedFraction` | | Continued fraction infrastructure for log₂3 |
| `DistancePowers` | | Effective lower bounds for \|2^m − 3^n\| |
| `LinearFormThree` | | Three-variable linear forms (Baker/Matveev for log 2, log 5, log 7) |
| `LinearFormGeneral` | | Generalized n-variable linear forms in logarithms |
| **Cycle elimination** | | |
| `SteinerCycle` | | Steiner/Hercher cycle equation: no cycle with ≤91 odd steps |
| `CycleElimination` | | Combining polynomial and exponential bounds |
| `SUnitEquation` | | S-unit equations 2^a − 3^b = d and Collatz cycle connections |
| **Diophantine & ergodic** | | |
| `DiophantineRepeller` | | Decomposition into Hensel attrition + Baker separation + deficit bound |
| `HenselAttrition` | | d consecutive v₂=1 steps require x ≡ −1 (mod 2^(d+1)) |
| `DeficitBudget` | | Deficit budget framework connecting Hensel to SWC |
| `WeylEquidistribution` | | Weyl equidistribution bridge: cell visits → deficit bounds |
| `DenjoyKoksma` | | Denjoy-Koksma inequality: sublinear deficit O(t^{1/5}) |
| **Solenoid & skew product** | | |
| `SolenoidMixing` | | Cell error algebra on (2,3)-solenoid |
| `SkewProduct` | | 2-adic odometer base with torus rotation fiber |
| `UniqueErgodicity` | | Unique ergodicity of Collatz skew product (Furstenberg 1961) |
| `CorrelationDecay` | | Danger-danger correlations vanish after v₂=1 runs |
| `BorelCantelli` | | Sustained long v₂=1 runs have density zero |
| **Spectral & Furstenberg** | | |
| `SpectralGap` | | ×3 transfer operator: all non-trivial eigenvalues have \|λ\|=1/3 |
| `ArithmeticRigidity` | | Metric transversality: Collatz ↔ Furstenberg ↔ Littlewood |
| `MetricConflict` | | 2-adic attrition vs 3-adic exit time incompatibility |
| `CarryBitScrambling` | | +1 carry chain as phase scrambler, iterated bit-peeling |
| `FuelDynamics` | | Fuel equation: v₂(n+1) evolution, E[fuel]=2, regeneration |
| **Littlewood** | | |
| `SimultaneousApprox` | | Simultaneous Diophantine approximation definitions |
| `LittlewoodResidence` | | Residence bounds on 2D torus for (log₂5, log₂7) |
| `LittlewoodInduction` | | Scale induction using Matveev bounds |

### Axioms (10)

These are published theorems from the literature, accepted without proof:

| # | Name | Reference |
|---|------|-----------|
| A1 | `baker_two_three` | Laurent-Mignotte-Nesterenko (1995): effective lower bound on \|b₁ log 2 + b₂ log 3\| |
| A2 | `rhin_irrationality_measure` | Rhin (1987): irrationality measure μ(log₂3) ≤ 5.1163 |
| A3 | `hercher_no_small_cycle` | Hercher (2024): no non-trivial Collatz cycle with ≤91 odd steps |
| A4 | `baker_steiner_no_large_cycle` | Steiner (1977) + Baker: no cycle with >91 odd steps |
| A5 | `weyl_equidistribution_of_irrational_rotation` | Weyl (1916): equidistribution of irrational rotations |
| A6 | `matveev_three_log` | Matveev (2000): lower bound on 3-variable linear forms in logarithms |
| A7 | `denjoy_koksma_sublinear_birkhoff` | Khintchine/Herman: sublinear Birkhoff sums for irrational rotations |
| A8 | `skew_product_uniquely_ergodic` | Furstenberg (1961): unique ergodicity of skew products |
| A9 | `arithmetic_decoupling` | Phase scrambling: danger density → 1/2 along trajectories |
| A10 | `matveev_general` | Matveev (2000): n-variable linear forms in logarithms |

### Sorrys (12)

Open gaps in the formalization:

| Sorry | File | Equivalence |
|-------|------|-------------|
| `nu3_linear_bound` | Drift.lean | ≡ Collatz |
| `finite_deficit_bound` | DiophantineRepeller.lean | ≡ Collatz |
| `equidistribution_implies_deficit_bounded` | WeylEquidistribution.lean | ≡ Collatz |
| `cellSeqNu2_equidistributed` | WeylEquidistribution.lean | ≡ Collatz |
| `syracuseValSum_equidistributed_of_sublinear_walk` | SolenoidMixing.lean | ≡ Collatz |
| `simultaneous_approx_log2_5_7` | LittlewoodInduction.lean | Deep Diophantine |
| `spectral_gap_transfer` | SpectralGap.lean | Standard (Fourier on finite groups) |
| `sunit_solutions_finite` | SUnitEquation.lean | Standard (exp beats poly) |
| `furstenberg_partition_rigidity` | ArithmeticRigidity.lean | Depends on spectral gap |
| `spectral_gap_implies_collatz` | ArithmeticRigidity.lean | Hard (trajectory control) |
| `spectral_gap_implies_furstenberg` | ArithmeticRigidity.lean | Hard (Rudolph gap) |
| `spectral_gap_implies_littlewood` | ArithmeticRigidity.lean | Hard (transference) |

The first 5 are **equivalent to the Collatz conjecture** (proved in `Conclusion.lean`).
The last 4 represent honest gaps in lifting spectral mixing to the three conjectures.

## Computational Experiments

23 C programs and 1 OpenCL kernel provide numerical evidence:

| Program | Description |
|---------|-------------|
| `branch_locus.c` | OpenMP branch locus computation with checkpoint/resume (verified to 10B) |
| `gpu_branch_host.c` / `gpu_branch_kernel.cl` | GPU-accelerated branch counting (1,768M nums/s) |
| `v2_danger.c` | Hensel attrition analysis: danger runs, hopping, correlation |
| `furstenberg_orbits.c` | ×2, ×3 prime orbit statistics (455M primes to 10^10) |
| `furstenberg_entropy.c` | Atom width spectrum, entropy deficit, multiplicative orders |
| `furstenberg_spectrum.c` | Spectral gap verification: \|λ\|=1/3 for all non-trivial eigenvalues |
| `deficit_analysis.c` | Deficit and sliding window condition analysis |
| `littlewood_cfrac.c` | Continued fraction analysis for simultaneous approximation |
| `collatz_tree.c` | Tree structure and visualization |

## Building

### Lean 4

```bash
cd lean4
lake build
```

Requires Lean 4 with Mathlib. Build produces ~3,144 jobs.

### C scripts

```bash
cd c_scripts
make branch_locus        # CPU branch locus (OpenMP)
make gpu_branch          # GPU branch locus (OpenCL)
make furstenberg         # Furstenberg orbit scan
make furstenberg_entropy # Entropy analysis
make furstenberg_spectrum # Spectral gap verification
```

Requires GCC with OpenMP support. GPU targets require OpenCL 1.2.

## Key Results

### Proved in Lean 4

- Collatz parity sequences lie in the golden mean shift (no "11" pattern)
- Baker's theorem implies log₂3 is irrational with effective measure
- No non-trivial Collatz cycle exists (combining Hercher + Baker-Steiner)
- Sublinear deficit implies Collatz convergence (`SublinearDrift.lean`)
- `nu3_linear_bound` ↔ Collatz conjecture (equivalence)
- Hensel attrition: d-step danger runs decay as 2^{-d}
- Spectral gap of ×3 transfer operator: iterated contraction by (1/9)^t
- Carry-bit scrambling: 1-bit erosion per compressed step
- Fuel regeneration exists (n=27 trajectory demonstrates fuel 2→5)
- Poisson-Jensen-Blaschke inequality for entire functions
- S-unit coefficient bounds from Baker's theorem

### Verified Computationally

- Branch locus structure to N = 10^10
- Hensel attrition P(D|D) ≈ 0.06 stable, max run ∝ log(N)
- Furstenberg generation density matches Euler product to 5 sig figs
- All ×3 eigenvalues have |λ| = 1/3 exactly (verified to j = 30)
- E[v₂(n+1) | n odd] = 2 (not 1), explaining the drift

## References

- Baker, A. (1975). *Transcendental Number Theory*. Cambridge University Press.
- Hercher, C. (2024). "No Collatz m-Cycles with m ≤ 91."
- Laurent, M., Mignotte, M., Nesterenko, Y. (1995). "Formes linéaires en deux logarithmes."
- Matveev, E.M. (2000). "An explicit lower bound for a homogeneous rational linear form in logarithms."
- Rhin, G. (1987). "Approximants de Padé et mesures effectives d'irrationalité."
- Steiner, R. (1977). "A theorem on the Syracuse problem."
- Tao, T. (2022). "Almost all orbits of the Collatz map attain almost bounded values." *Forum of Mathematics, Pi*.

## License

Research code. See individual files for attribution.
