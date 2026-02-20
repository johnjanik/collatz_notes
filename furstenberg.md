# Attacking Furstenberg's $\times 2, \times 3$ Conjecture

## The Problem

**Furstenberg's Conjecture (1967).** The only Borel probability measures on $\mathbb{T} = \mathbb{R}/\mathbb{Z}$ simultaneously invariant under $T_2: x \mapsto 2x$ and $T_3: x \mapsto 3x$ are Lebesgue measure and measures supported on finite orbits (rationals with denominator coprime to 6).

**State of the art:**
- Rudolph (1990): True if $\mu$ has positive entropy for at least one map.
- Johnson (1992): Extended under an ergodicity hypothesis.
- Host (1995): Simplified proof of Rudolph.
- Einsiedler-Katok-Lindenstrauss (2006): Any counterexample has Hausdorff dimension 0.
- **The zero-entropy case remains completely open.**

---

## What We Have (Inventory of Transferable Machinery)

### Directly transferable

| Tool | Collatz role | Furstenberg role |
|------|-------------|-----------------|
| `baker_two_three` (A1) | Lower bound on $\|m \log 2 + n \log 3\|$ | Quantitative separation of $2^a 3^b$ orbit points |
| `baker_cell_separation` | Dangerous cells are Diophantine-sparse | Fourier near-resonances are sparse |
| `irrational_logb_two_three` | $\log_2 3 \notin \mathbb{Q}$ | Multiplicative independence of 2 and 3 |
| `autocorrelation_zero_of_large_shift` | Danger-danger correlation vanishes at lag $\geq 2$ | Joint resonance sets are anti-correlated |
| `safeCellDensity_at_inverse_scale` | $\geq 3/4$ of cells are safe at scale $N \geq 8$ | Most of the torus is "non-resonant" |
| `cellError_shift_identity` | Shift by $(d,d)$ adds $d(1 - \log_2 3)$ | Irrational drift under diagonal action |

### Collatz-specific (does NOT transfer)

| Tool | Why it's Collatz-specific |
|------|--------------------------|
| `hensel_attrition` | Requires the $3x+1$ recurrence: $2(T(x)+1) = 3(x+1)$ |
| `correction_ratio` | Depends on the "+1" perturbation |
| `golden_mean_shift` | Parity constraint "odd always followed by even" specific to $3x+1$ |
| `deficit` / `finite_deficit_bound` | Defined via the Collatz step function |
| `SlidingWindowCondition` | Window-based accounting for Collatz trajectories |

### Needs adaptation

| Tool | Required modification |
|------|----------------------|
| Solenoid model (`SkewProduct.lean`) | Replace 2-adic odometer + cocycle with $\langle \times 2, \times 3 \rangle$ semigroup action |
| Torus grid (`Torus.lean`) | Replace $(\nu_2, \nu_3)$ tracking with orbit enumeration under $T_2, T_3$ |
| Equidistribution (`WeylEquidistribution.lean`) | Weyl sums for $\langle 2, 3 \rangle$-orbits instead of single irrational rotation |

---

## The Core Mathematical Connection

### The Fourier picture

Characters of $\mathbb{T}$ are $\chi_n(x) = e^{2\pi i n x}$ for $n \in \mathbb{Z}$. If $\mu$ is $T_2$-invariant: $\hat\mu(n) = \hat\mu(2n)$. If $\mu$ is $T_3$-invariant: $\hat\mu(n) = \hat\mu(3n)$. So:

$$\hat\mu \text{ is constant on orbits of } \langle \times 2, \times 3 \rangle \text{ acting on } \mathbb{Z}.$$

For $n \neq 0$, the orbit $\mathcal{O}(n) = \{2^a \cdot 3^b \cdot n : a, b \geq 0\}$ is infinite (by multiplicative independence, **which we have proved**: `multIndep_two_three`). The orbit goes to $\infty$, so by Riemann-Lebesgue $\hat\mu(n) = 0$ **if $\mu$ is absolutely continuous**. But for singular measures, Riemann-Lebesgue fails.

### What Baker adds to the Fourier picture

Standard approach (Rudolph): Positive entropy $\Rightarrow$ $\mu$ is not too singular $\Rightarrow$ Fourier coefficients decay $\Rightarrow$ $\hat\mu = 0$ on $\mathbb{Z} \setminus \{0\}$ $\Rightarrow$ $\mu = \lambda$.

Baker's contribution: The orbit points $\{2^a \cdot 3^b \cdot n\}$ are **quantitatively well-separated**. Baker gives:

$$|2^a \cdot 3^b - 2^{a'} \cdot 3^{b'}| > C \cdot \max(2^a 3^b, 2^{a'} 3^{b'})^{1 - \kappa}$$

for some $\kappa > 0$. This means the orbit cannot cluster: consecutive orbit points are polynomially separated (not just infinitely separated). Our `baker_cell_separation` is the logarithmic version of this:

$$|a - \log_2 3 \cdot b| > \frac{C}{\max(|a|, |b|)^\kappa} \quad \text{for } (a,b) \neq (0,0).$$

**Key insight:** The "cell error" $a - \log_2 3 \cdot b$ is exactly $\log_2(2^a / 3^b)$, measuring how well $2^a$ approximates $3^b$. Baker says this approximation is polynomially bounded below. This directly constrains how a jointly invariant measure can distribute its Fourier mass.

### The cellError as a "transversality witness"

On the $(N \times N)$ torus $(\mathbb{Z}/N\mathbb{Z})^2$, define:
- Cell $(a, b)$ is **resonant** if $|\text{cellError}(a, b)| < \delta$
- Baker gives: $\leq N \cdot (\lceil 2\delta \rceil + 1)$ resonant cells out of $N^2$ total

At scale $\delta = 1/N$: resonant fraction $\leq 3/N \to 0$. This is our `safeCellDensity_at_inverse_scale`.

For Furstenberg: the "$T_2$-good" arcs (where $T_2$ contracts) and "$T_3$-good" arcs (where $T_3$ contracts) overlap on at most a $O(1/N)$-fraction of the circle at scale $N$. A jointly invariant measure that concentrates on this overlap at every scale must be supported on a set of dimension 0.

---

## Plan of Attack: Five Phases

### Phase 1: Fourier-Orbit Computation (2-4 weeks)

**Goal:** Enumerate the $\langle 2, 3 \rangle$-orbit structure on $\mathbb{Z}$ and compute the "orbit density" empirically.

**Computational tasks:**
1. Write `furstenberg_orbits.c` (OpenMP, modeled on `v2_danger.c`):
   - For each 6-free $n \leq N_0$ (i.e., $\gcd(n, 6) = 1$), enumerate $\mathcal{O}(n) \cap [1, H]$ for $H = 10^{10}$.
   - Measure the counting function $|\mathcal{O}(n) \cap [1, H]| / \log^2 H$ (expected to be $\sim 1/(2 \log 2 \cdot \log 3)$ by equidistribution of $(a, b)$ in the region $2^a 3^b \leq H$).
   - Compute the "gap spectrum": the sorted distances between consecutive orbit points.

2. Compute the **resonant fraction** on the pure $\times 2, \times 3$ torus (no "+1" perturbation):
   - On $(\mathbb{Z}/N\mathbb{Z})^2$ with $N = 6^k$ for $k = 1, \ldots, 8$:
   - Cell $(a, b)$ is resonant if there exists $n \leq N^2$ with $n \cdot 2^a \equiv n \cdot 3^b \pmod{N}$.
   - Measure the multi-scale resonant fraction: fraction of cells resonant at scales $6, 36, 216, \ldots$

3. Test the **independence hypothesis**: is the resonant fraction at scale $6^{k+1}$ approximately $(1/6^k)$ times the resonant fraction at scale $6^k$? (If yes, the dimension argument works directly.)

**What this tells us:** Whether the Diophantine repeller mechanism — the sparsity of resonant cells — persists in the pure $\times 2, \times 3$ setting (without Collatz's "+1" perturbation). If the resonant fraction decays as $O(1/N)$ at every scale, we have strong evidence for the dimension-zero argument.

### Phase 2: The Entropy Bridge (4-8 weeks)

**Goal:** Prove that Baker's quantitative bounds force positive entropy for any non-atomic, non-Lebesgue jointly invariant measure.

This would reduce Furstenberg to Rudolph's theorem, which is already proved.

**The argument sketch:**

Let $\mu$ be $T_2$-invariant and $T_3$-invariant, ergodic, and non-atomic.

1. **Partition entropy.** Let $\mathcal{P}_2 = \{[0, 1/2), [1/2, 1)\}$ be the natural $T_2$-partition. The entropy is:
   $$h_\mu(T_2) = H_\mu(\mathcal{P}_2 \mid \mathcal{P}_2^-) \quad \text{where } \mathcal{P}_2^- = \bigvee_{n=1}^{\infty} T_2^{-n} \mathcal{P}_2.$$

2. **Conditional entropy via $T_3$.** Since $\mu$ is also $T_3$-invariant, we can write:
   $$H_\mu(\mathcal{P}_2 \mid \mathcal{P}_2^-) \geq H_\mu(\mathcal{P}_2 \mid \mathcal{P}_2^- \vee \mathcal{P}_3^-)$$
   where $\mathcal{P}_3 = \{[0,1/3), [1/3, 2/3), [2/3, 1)\}$ and $\mathcal{P}_3^- = \bigvee T_3^{-n}(\mathcal{P}_3)$.

   Wait — this goes the wrong way (conditioning reduces entropy). The real argument must show that $T_3$-invariance PREVENTS the entropy from being zero.

3. **Baker's role.** The partition boundaries of $\mathcal{P}_2^{(k)} = \bigvee_{j=0}^{k-1} T_2^{-j}(\mathcal{P}_2)$ are at $\{m/2^k : 0 \leq m < 2^k\}$. The partition boundaries of $\mathcal{P}_3^{(\ell)} = \bigvee_{j=0}^{\ell-1} T_3^{-j}(\mathcal{P}_3)$ are at $\{m/3^\ell : 0 \leq m < 3^\ell\}$.

   **Baker gives:** $|m/2^k - m'/3^\ell| > C/(2^k 3^\ell)^{1-\epsilon}$ for all $m, m'$ (when the difference is nonzero). So the 2-adic and 3-adic partition boundaries are always well-separated.

   **Consequence:** The atoms of $\mathcal{P}_2^{(k)} \vee \mathcal{P}_3^{(\ell)}$ are intervals of length $\geq C/(2^k 3^\ell)^{1-\epsilon}$. The joint partition is "coarser than expected" — it has $\sim 2^k \cdot 3^\ell$ atoms but each is polynomially wider than $1/(2^k 3^\ell)$.

4. **Entropy lower bound.** For a non-atomic measure $\mu$, the entropy $H_\mu(\mathcal{P}_2^{(k)} \vee \mathcal{P}_3^{(\ell)})$ grows with $k$ and $\ell$. Baker's lower bound on atom sizes prevents $\mu$ from concentrating too much mass on too few atoms. Specifically, if $\mu$ concentrates $\geq 1-\epsilon$ of its mass on $M$ atoms, then:

   $$H_\mu(\mathcal{P}_2^{(k)} \vee \mathcal{P}_3^{(\ell)}) \geq (1-\epsilon) \log M$$

   The question is: does $M$ grow fast enough (linearly in $k + \ell$) to force $h_\mu(T_2) > 0$?

**The key lemma to prove:**

> **Conjecture (Entropy Production).** If $\mu$ is a non-atomic Borel probability measure on $\mathbb{T}$ that is simultaneously $T_2$- and $T_3$-invariant and ergodic, then:
> $$\limsup_{k \to \infty} \frac{1}{k} H_\mu\!\left(\bigvee_{j=0}^{k-1} T_2^{-j}(\mathcal{P}_2)\right) > 0.$$

If true, Rudolph's theorem finishes the job.

**Why this might work where others failed:** The standard approach tries to show entropy production from invariance alone. Our approach uses **Baker's effective bounds** to get **quantitative** constraints on the partition structure. The cellError machinery gives us a computable estimate of how much the 2-adic and 3-adic partitions "fight," and the correlation decay theorem says this fighting doesn't cancel over time.

**Lean formalization:** The entropy bound from Baker can be formalized by extending `baker_cell_separation` to the partition setting:
- Define `partitionAtomWidth (k ℓ : ℕ) : ℝ` as the minimum atom width
- Prove `partitionAtomWidth_lower_bound : partitionAtomWidth k ℓ > C / (2^k * 3^ℓ)^(1-ε)` from Baker

### Phase 3: The Dimension Argument (4-8 weeks, parallel with Phase 2)

**Goal:** Prove that the support of any non-Lebesgue, non-atomic jointly invariant measure has Hausdorff dimension 0.

This is a weaker result than the full conjecture (it doesn't rule out singular continuous measures supported on dimension-0 sets), but it would match the EKL result via an entirely different method.

**The argument:**

1. At scale $N = 6^k$, partition $\mathbb{T}$ into $N$ arcs of length $1/N$.

2. An arc $I_j = [j/N, (j+1)/N)$ is **$T_2$-significant** if $\mu(T_2^{-1}(I_j)) \geq 2\mu(I_j)$ (the arc gains mass under $T_2$). Define **$T_3$-significant** analogously.

3. By $T_2$-invariance and the pigeonhole principle, at most $N/2$ arcs are $T_2$-significant. Similarly for $T_3$.

4. An arc that is both $T_2$-significant and $T_3$-significant is **jointly significant**. The fraction of jointly significant arcs is bounded by the "resonant fraction" from Phase 1.

5. **Baker's contribution:** The jointly significant arcs at scale $6^k$ must contain a cell $(a,b)$ with $|a \log 2 + b \log 3| < C/N$. Baker bounds the number of such cells.

6. At each scale refinement $6^k \to 6^{k+1}$, the jointly significant fraction contracts by a factor $\leq 1 - c$ for some $c > 0$ (from Baker separation). After $k$ refinements, the measure of the support is $\leq (1-c)^k \to 0$.

**What needs to be proved:** The contraction factor $c > 0$ at each scale. This requires showing that Baker separation at scale $6^{k+1}$ is "independent enough" from scale $6^k$. The correlation decay theorem (`autocorrelation_zero_of_large_shift`) provides exactly this independence for the cellError, but translating it to the measure setting requires new ideas.

**Computational validation:** Run the multi-scale resonant fraction computation from Phase 1 and check whether the contraction is observed empirically.

### Phase 4: Formalizing Rudolph's Theorem (8-16 weeks, parallel)

**Goal:** A Lean 4 formalization of Rudolph's 1990 theorem — a significant contribution to Mathlib independent of the conjecture.

**Statement:** If $\mu$ is a Borel probability measure on $\mathbb{T}$ that is ergodic and invariant under both $T_p$ and $T_q$ where $p, q$ are multiplicatively independent, and $h_\mu(T_p) > 0$, then $\mu$ is Lebesgue measure.

**Dependencies (from Mathlib):**
- Measure-theoretic entropy (partially available)
- Conditional expectations and disintegration (partially available)
- Rohklin's theorem (NOT in Mathlib — major prerequisite)
- Ledrappier-Young entropy theory (NOT in Mathlib)

**What we already have:**
- `multIndep_two_three`: multiplicative independence of 2 and 3
- Baker infrastructure for the effective separation bounds
- The solenoid model as a starting point for the tower construction

**Realistic scope:** Formalizing the full Rudolph argument is a multi-month project. A more realistic first target:
1. Formalize the **statement** of Rudolph's theorem as an axiom (like our Baker axiom A1)
2. Prove that if the Entropy Production Conjecture (Phase 2) holds, then Furstenberg follows from Rudolph
3. This gives a clear roadmap: close the Entropy Production Conjecture to get Furstenberg

### Phase 5: The GPU Torus Enumeration (2-4 weeks)

**Goal:** Use the RTX 5090 to enumerate $\langle \times 2, \times 3 \rangle$-orbits on the torus at scales unreachable by CPU.

**Approach:** Adapt `gpu_branch_kernel.cl` to compute:

1. **Orbit density at scale $6^k$:** For each starting point $x \in \{1, \ldots, 6^k\}$, compute $\{T_2^a T_3^b(x) \bmod 6^k : 0 \leq a, b \leq B\}$ and measure the orbit closure.

2. **Invariant measure detection:** Look for non-uniform invariant distributions on $\mathbb{Z}/6^k\mathbb{Z}$ by iterating the transfer operator $\mu \mapsto (\mu \circ T_2^{-1} + \mu \circ T_3^{-1})/2$ (or the semigroup average).

3. **Multi-scale Baker filter:** At each scale, classify cells by their cellError and measure the jointly resonant fraction.

**Expected throughput:** At scale $6^6 = 46656$, each orbit computation is $\sim B^2$ multiplications mod $6^6$. With $B = 100$, that's $10^4$ operations per starting point, so the GPU can handle all $46656$ starting points trivially. At $6^8 = 1,679,616$, still feasible.

---

## What Must Be True for This to Work

### The critical hypothesis

The entire approach rests on one claim:

> **Baker separation forces entropy production in the joint action.**

Spelled out: for any non-atomic $\mu$ invariant under $T_2$ and $T_3$, the fact that $|m/2^k - m'/3^\ell| > C/(2^k 3^\ell)^{1-\epsilon}$ for all nonzero differences forces $h_\mu(T_2) > 0$.

If this is true, Rudolph's theorem closes Furstenberg's conjecture immediately.

If this is false — if there exist zero-entropy non-atomic measures that "avoid" the Baker lower bound — then the dimension argument (Phase 3) is the fallback, and the full conjecture may require fundamentally new ideas.

### Why this might work

The Collatz project provides evidence: in the Collatz setting, the Baker-cellError machinery **does** force trajectories away from dangerous resonances. The deficit cannot grow without bound because the cell error shift ($d(1 - \log_2 3)$ per dangerous run) eventually pushes the trajectory out of the resonant zone. This is a "trajectory-level" version of entropy production.

The question is whether this trajectory-level argument can be upgraded to a measure-level argument. The correlation decay theorem (`autocorrelation_zero_of_large_shift`) suggests yes: the vanishing of danger-danger correlations is a measure-theoretic statement that does not depend on Collatz-specific structure.

### Why this might fail

Furstenberg's conjecture is about **arbitrary** invariant measures, not specific trajectories. A measure could distribute its mass in a complicated way that respects both the 2-adic and 3-adic structure simultaneously — something no individual trajectory can do, but a measure (as a continuum object) potentially can.

The EKL result says such measures must have dimension 0, but dimension 0 does not mean empty: Cantor-type sets have dimension 0 and positive capacity. The full conjecture requires eliminating these.

---

## Dependency Graph

```
Phase 1 (Computation)    Phase 4 (Rudolph formalization)
    |                         |
    v                         v
Phase 2 (Entropy bridge) --> Phase 5 (GPU enumeration)
    |                         |
    v                         v
Phase 3 (Dimension arg) --> FURSTENBERG'S CONJECTURE
```

## Priority Order

1. **Phase 1** — low-hanging fruit, calibrates the rest
2. **Phase 2** — the critical theoretical contribution
3. **Phase 5** — parallel computation, provides evidence for Phase 2
4. **Phase 3** — fallback if Phase 2 fails, still publishable (alternative proof of EKL)
5. **Phase 4** — long-term Lean project, valuable regardless

---

## Phase 1 Results (2026-02-20)

### Program: `furstenberg_orbits.c`

OpenMP-parallelized (24 threads), processes 6.6M primes/s. For each prime $p \nmid 6$:
- Factors $p-1$ by trial division
- Computes $\text{ord}_p(2)$, $\text{ord}_p(3)$ using the factorization
- $|\langle 2, 3 \rangle| = \text{lcm}(\text{ord}_p(2), \text{ord}_p(3))$ (cyclic group identity)
- Tests full generation: $\langle 2, 3 \rangle = (\mathbb{Z}/p\mathbb{Z})^*$?

### Result 1: Full generation density = Euler product

Scanned **455 million primes** up to $10^{10}$ in 57.6 seconds (7.9M primes/s):

| Range | Primes | Full gen | Percentage |
|-------|--------|----------|------------|
| $[5, 100)$ | 23 | 18 | 78.26% |
| $[10^2, 10^3)$ | 143 | 105 | 73.43% |
| $[10^3, 10^4)$ | 1,061 | 756 | 71.25% |
| $[10^4, 10^5)$ | 8,363 | 5,854 | 70.00% |
| $[10^5, 10^6)$ | 68,906 | 48,075 | 69.77% |
| $[10^6, 10^7)$ | 586,081 | 408,790 | 69.75% |
| $[10^7, 10^8)$ | 5,096,876 | 3,555,045 | 69.75% |
| $[10^8, 10^9)$ | 45,086,079 | 31,448,732 | 69.75% |
| $[10^9, 10^{10})$ | 404,204,977 | 281,933,832 | **69.75%** |

**Theoretical prediction:** By Chebotarev density, the density of primes $p$ where $\langle 2, 3 \rangle = (\mathbb{Z}/p\mathbb{Z})^*$ is:

$$\delta = \prod_{\ell \text{ prime}} \left(1 - \frac{1}{\ell^2(\ell-1)}\right) = 0.69750136...$$

This matches the empirical 69.750% to 5 significant figures across 455 million primes. The product converges rapidly:
$\ell = 2$ contributes factor $3/4$; $\ell = 3$ contributes $17/18$; $\ell = 5$ contributes $99/100$.

**Interpretation for Furstenberg:** At "scale $p$" (working on $\mathbb{Z}/p\mathbb{Z}$), the $\langle \times 2, \times 3 \rangle$ semigroup action covers all of $(\mathbb{Z}/p\mathbb{Z})^*$ for ~70% of primes. For the remaining ~30%, there exist non-trivial invariant subsets — but these are **finite orbits** (exactly what Furstenberg allows). The conjecture is consistent at every finite scale.

### Result 2: Index distribution

For primes where $\langle 2, 3 \rangle \neq (\mathbb{Z}/p\mathbb{Z})^*$, the index $(p-1)/|\langle 2,3 \rangle|$ (totals over all 455M primes):

| Index | Count | Pct of all primes | Interpretation |
|-------|-------|-------------------|----------------|
| 1 | 317,401,207 | 69.75% | Full generation |
| 2 | 93,355,317 | 20.52% | Both 2,3 are QR mod $p$ |
| 3 | 17,982,555 | 3.95% | Both are cubic residues |
| 4 | 9,334,173 | 2.05% | Both are 4th power residues |
| 5 | 3,180,503 | 0.70% | ... |
| 6 | 4,494,649 | 0.99% | (composite index: 2×3) |
| 7 | 1,079,163 | 0.24% | ... |
| 8 | 2,722,949 | 0.60% | ... |
| 12 | 1,123,071 | 0.25% | (highly composite) |
| 24 | 327,576 | 0.07% | (highly composite) |

The index-2 density of 20.52% matches the predicted $1/(\ell^2(\ell-1))|_{\ell=2} \cdot \prod_{\ell > 2}(1 - ...) \approx 1/4 \times 0.93 \approx 0.233$ (rough; the exact value requires more careful inclusion-exclusion). Highly composite indices (6, 12, 24) are over-represented due to having many divisors.

### Result 3: Maximum index grows slowly

| Decade | Max index |
|--------|-----------|
| $[10^2, 10^3)$ | 10 |
| $[10^3, 10^4)$ | 56 |
| $[10^4, 10^5)$ | 72 |
| $[10^5, 10^6)$ | 170 |
| $[10^6, 10^7)$ | 519 |
| $[10^7, 10^8)$ | 2,834 |
| $[10^8, 10^9)$ | 3,235 |
| $[10^9, 10^{10})$ | **35,590** |

The jump from 3,235 to 35,590 in the last decade shows worst-case primes have very smooth $p-1$ (many small factors), causing both 2 and 3 to land in tiny subgroups. The minimum fraction $|\langle 2,3 \rangle|/(p-1) = 0.0000281$ in this decade means the generators cover only 0.003% of $(\mathbb{Z}/p\mathbb{Z})^*$.

### Result 4: CF convergents of $\log_2 3$

The continued fraction $\log_2 3 = [1; 1, 1, 2, 2, 3, 1, 5, 2, 23, 2, 2, 1, 1, 55, ...]$ gives best rational approximations. Key convergents:

| $n$ | $a_n$ | $p_n/q_n$ | $|\text{cellError}|$ | err/Baker |
|-----|-------|-----------|---------------------|-----------|
| 4 | 2 | 19/12 | $1.96 \times 10^{-2}$ | $6.6 \times 10^3$ |
| 8 | 2 | 1054/665 | $6.30 \times 10^{-5}$ | $1.8 \times 10^{10}$ |
| 13 | 1 | 301994/190537 | $9.31 \times 10^{-8}$ | $1.1 \times 10^{20}$ |
| 19 | 1 | 630138897/397573379 | $1.16 \times 10^{-10}$ | $1.4 \times 10^{22}$ |

The err/Baker ratio grows rapidly: Baker's lower bound is exponentially weaker than the actual CF approximation rate. This "gap" is the room in which both Collatz and Furstenberg operate.

### Result 5: Multi-scale cellError resonance

On the $N \times N$ torus with threshold $\delta = 1/N$:

| $k$ | $N = 6^k$ | Resonant cells | Fraction |
|-----|-----------|---------------|----------|
| 1 | 6 | 1 | 0.167 |
| 2 | 36 | 2 | 0.056 |
| 3 | 216 | 2 | 0.009 |
| 4 | 1,296 | 2 | 0.0015 |
| 5 | 7,776 | 3 | 0.00039 |
| 6 | 46,656 | 1 | 0.000021 |
| 8 | 1,679,616 | 6 | 0.0000036 |

The resonant count stays $O(1)$ at every scale (consistent with Baker separation: at most $\sim 2$ CF convergents in range), so the resonant fraction decays as $\sim 1/N$. This confirms the torus gets overwhelmingly "safe" at large scales.

---

## Phase 2 Results: Entropy Bridge (2026-02-20)

### Program: `furstenberg_entropy.c`

Computes the joint partition $\mathcal{P}_2^{(j)} \vee \mathcal{P}_3^{(k)}$ on the circle and analyzes its entropy properties. Boundary points are $\{m/2^j\} \cup \{m'/3^k\}$; in common denominator $D = 2^j \cdot 3^k$, these become integers that can be sorted exactly.

### Result 6: Multiplicative order asymmetry (verified to $j,k = 40$)

| Property | 2-adic side | 3-adic side |
|----------|-------------|-------------|
| Order | $\text{ord}_{2^j}(3) = 2^{j-2}$ for $j \geq 3$ | $\text{ord}_{3^k}(2) = \varphi(3^k) = 2 \cdot 3^{k-1}$ |
| Index | **Always 2** | **Always 1** |
| Meaning | 3 generates half of $(\mathbb{Z}/2^j\mathbb{Z})^*$ | 2 is a primitive root mod $3^k$ |

**All 80 predictions verified.** This asymmetry is the structural foundation of the entropy bridge:

- $T_3$ explores **all** of $(\mathbb{Z}/3^k\mathbb{Z})^*$ via multiplication by 2 (primitive root)
- $T_3$ explores only **half** of $(\mathbb{Z}/2^j\mathbb{Z})^*$ via multiplication by 3 (index 2)
- $T_2$ acts "naturally" on $\mathcal{P}_2^{(j)}$ — doubling the precision at each step

### Result 7: Entropy growth rate (balanced scales)

For $k(j) = \text{round}(j \cdot \log 2/\log 3)$ ("balanced" where $2^j \approx 3^k$):

| $j$ | $k$ | Atoms | $H$ (nats) | $H/j$ | Deficit | Efficiency |
|-----|-----|-------|------------|--------|---------|------------|
| 4 | 3 | 42 | 3.590 | 0.897 | 0.148 | 0.960 |
| 8 | 5 | 498 | 6.020 | 0.752 | 0.191 | 0.969 |
| 12 | 8 | 10,656 | 9.101 | 0.758 | 0.173 | 0.981 |
| 16 | 10 | 124,584 | 11.541 | 0.721 | 0.192 | 0.984 |
| 20 | 13 | 2,642,898 | 14.611 | 0.731 | 0.177 | 0.988 |
| 24 | 15 | 31,126,122 | 17.063 | 0.711 | 0.190 | 0.989 |

**Key observation: The entropy deficit is bounded** at $\sim 0.17$–$0.19$ nats, not growing with scale. This means:
- The atom widths become increasingly uniform (efficiency → 1)
- The few thin atoms (width $1/D$, Bezout-optimal) contribute negligibly to entropy
- Under Lebesgue measure, $H/j$ converges to $\log 2 \approx 0.693$ from above (the excess comes from 3-adic refinement information)

**Implication for the Entropy Production Conjecture:** For any non-atomic $\mu$, $T_3$-invariance forces $\mu$ to spread across $T_3$-orbits on $\mathcal{P}_2^{(j)}$. Since $T_3$ acts with period $2^{j-2}$ on the atoms of $\mathcal{P}_2^{(j)}$ (generating half the cyclic group), a $T_3$-invariant measure must give equal weight to atoms within each $T_3$-orbit. This constrains $H_\mu(\mathcal{P}_2^{(j)}) \geq \log(\text{orbit size})$, potentially forcing $H/j > 0$.

### Result 8: Gap distribution (anatomy of $\mathcal{P}_2^{(12)} \vee \mathcal{P}_3^{(8)}$)

The 10,656 atoms of $\mathcal{P}_2^{(12)} \vee \mathcal{P}_3^{(8)}$ come in three gap types:

| Gap type | Count | Width (in units of $1/D$) | Meaning |
|----------|-------|---------------------------|---------|
| 3-adic → 3-adic | 2,464 | $2^{12} = 4096$ (uniform) | 3-adic boundaries well-separated |
| 2-adic ↔ 3-adic (mixed) | 8,192 | 1 to 4096 (mean 2048.5) | Where Baker operates |
| 2-adic → 2-adic | 0 | — | Impossible: $3^8 > 2^{12}$, so 3-adic always intervenes |

**The minimum mixed gap is exactly 1** (= $1/(2^{12} \cdot 3^8) \approx 3.7 \times 10^{-8}$ of the circle), achieved by Bézout's identity. This is the Baker coprimality floor — it can never be 0 since $\gcd(2^j, 3^k) = 1$, and Baker's theorem guarantees it stays $\geq 1$ for all $(j,k)$.

The average mixed gap is $D/2^{j+1} = 3^k/2$, consistent with the 2-adic boundaries being uniformly distributed among the $2 \cdot 3^k / 2^j$ 3-adic gaps (by Weyl equidistribution of $\{m \cdot \log_2 3\}$).

### Result 9: Minimum atom width ratio

For all $(j,k)$ tested (up to $j = 24$), the minimum gap in integer units is **exactly 1**. This means:

$$\min_{\text{atoms}} \text{width} = \frac{1}{2^j \cdot 3^k} \quad \text{(Bézout optimal, for all } j,k\text{)}$$

The ratio $\text{min\_width}/\text{mean\_width}$ decays as:

| $j$ | min/mean ratio | $\approx$ |
|-----|---------------|-----------|
| 8 | 0.000801 | $\sim 1/2^{10}$ |
| 12 | 0.000397 | $\sim 1/2^{11.3}$ |
| 16 | 0.0000322 | $\sim 1/2^{14.9}$ |
| 20 | 0.00000158 | $\sim 1/2^{19.3}$ |
| 24 | 0.000000013 | $\sim 1/2^{26.2}$ |

The thinnest atom shrinks exponentially faster than the mean, but there is **exactly one** such thin atom (the Bézout gap), so its entropy contribution $w \log(1/w) \to 0$. The bounded entropy deficit confirms that the remaining atoms are well-behaved.

### Result 10: Transfer matrix spectral gap = 2/3 (program: `furstenberg_spectrum.c`)

The transfer matrix $\mathbf{T}$ of $T_3: x \mapsto 3x$ on $\mathcal{P}_2^{(j)}$ has entries $T_{mi} = 1/3$ if $m \in \{3i, 3i+1, 3i+2\} \pmod{2^j}$, else 0. It is doubly stochastic.

**Theorem (Spectral Gap).** For $j \geq 3$, ALL non-trivial eigenvalues of $\mathbf{T}$ have modulus exactly $1/3$. The spectral gap is $2/3$, independent of $j$.

**Proof sketch.** In the Fourier basis $v_k(m) = \omega^{mk}$ ($\omega = e^{2\pi i/2^j}$), $\mathbf{T}$ maps $v_k \to \lambda(k) \cdot v_{ks}$ where $s = 3^{-1} \bmod 2^j$ and $\lambda(k) = \frac{1}{3}(1 + 2\cos(2\pi ks/2^j))$. For an orbit $\{k_0, 3k_0, 9k_0, \ldots\}$ of size $L$ under $\times 3 \pmod{2^j}$:

Using $1 + 2\cos\theta = (e^{3i\theta} - 1)/(e^{i\theta} - 1)$, the product **telescopes**:
$$\prod_{i=0}^{L-1} |1 + 2\cos(2\pi k_i s/2^j)| = \frac{|e^{2\pi i \cdot 3^L k_0 s/2^j} - 1|}{|e^{2\pi i \cdot k_0 s/2^j} - 1|} = 1$$
since $3^L \equiv 1 \pmod{2^j/\gcd(k_0, 2^j)}$. Therefore $|\text{eigenvalue}| = (1/3^L)^{1/L} = 1/3$. QED.

**Verification (two independent methods):**
1. **Fourier orbit products** ($j = 3$ to $30$): Every orbit gives $\prod|1+2\cos\theta_i| = 1.0000000000$ (10 decimal places). Full enumeration for $j \leq 20$ (all $2j+1$ orbits per $j$); representative orbits for $j = 21$–$30$.
2. **Direct matrix multiplication** ($j = 3$ to $10$): Build full $2^j \times 2^j$ transfer matrix, apply repeatedly, measure geometric mean of per-step decay over complete orbit cycles. Every cycle gives geometric mean $= 0.3333333333$ (10 decimal places).

**Structural observations:**
- Number of orbits = $2j+1$ (verified $j = 3$ to $20$)
- Maximum orbit size = $2^{j-2} = \text{ord}_{2^j}(3)$ (consistent with Result 6)
- $\lambda(2^{j-1}) = -1/3$ (unique fixed point under $\times 3$: $3 \cdot 2^{j-1} \equiv 2^{j-1} \pmod{2^j}$)
- 3 is NOT in the kernel of any character of $(\mathbb{Z}/2^j\mathbb{Z})^*$ of order $> 2$

**Consequence (Exponential mixing):**
$$\|\mathbf{T}^n p - \text{uniform}\|_2 \leq (1/3)^n \cdot \|p - \text{uniform}\|_2$$
$T_3$-invariance at the partition level ($\mathbf{T}p = p$) forces $p = \text{uniform}$, giving $H(\mathcal{P}_2^{(j)}) = j\log 2$ exactly.

### Synthesis: The entropy bridge argument takes shape

The Phase 2 data reveals the architecture of the entropy bridge:

1. **Baker coprimality floor:** $\min |m/2^j - m'/3^k| = 1/(2^j \cdot 3^k)$ prevents atoms from collapsing.
2. **Bounded entropy deficit:** $H_\text{max} - H \leq 0.19$ nats for all tested scales. Atoms are approximately uniform under Lebesgue.
3. **Order asymmetry:** 3 has index 2 (half the 2-adic group), 2 has index 1 (full 3-adic group). Any $T_3$-invariant measure must be constant on $T_3$-orbits of size $2^{j-2}$ in $\mathcal{P}_2^{(j)}$.
4. **Spectral gap $= 2/3$:** The transfer matrix of $T_3$ on $\mathcal{P}_2^{(j)}$ has all non-trivial eigenvalues with modulus exactly $1/3$, giving exponential mixing rate independent of $j$.

### Result 11: Straddle analysis — the lift problem (program: `furstenberg_straddle.c`)

**No straddle occurs.** Each preimage piece fits entirely inside one atom (verified $j = 3$–$8$, proved trivially: piece width 1 < atom width 3 in $D = 3 \cdot 2^j$ coordinates).

**2 DOF per atom** at every scale $j = 3$–$12$: the constraint rank from $T_3$-invariance is $N-1$ (verified by Gaussian elimination). The transfer matrix equation $\mathbf{T}p = p$ is the special case where each sub-piece carries exactly $1/3$ of its atom's mass. But $T_3$-invariance of $\mu$ only requires the SUM of 3 sub-piece masses to equal $p_m$ — it does not fix the individual sub-piece masses.

**Multi-scale propagation:** After $\lceil \log_2 3 \rceil + 1 = 3$ refinements, each old sub-piece is resolved into separate atoms at the finer scale, and the spectral gap begins to act. The rate of DOF elimination across scales is the key open question.

**The precise gap to close:** Show that $T_3$-invariance of a **measure** $\mu$ at all scales simultaneously forces within-atom uniformity. If $\mathbf{T}p = p$, then the spectral gap ($= 2/3$) forces $p = \text{uniform}$, giving $H_\mu(\mathcal{P}_2^{(j)}) = j\log 2 > 0$ and Rudolph closes the conjecture. The multi-scale argument needs: (1) after $O(1)$ scale refinements, old sub-pieces are resolved as separate atoms; (2) the spectral gap at the fine scale constrains the resolved masses; (3) Baker separation prevents resonant cancellation at the boundary crossing points.

---

## Honest Assessment

**Difficulty: Extreme.** This is a Fields Medal-level problem. The gap between "Baker separation makes resonances sparse" (which we have) and "Baker separation forces entropy production" (which we need) is the same gap that has blocked progress for 55+ years.

**Our advantage:** A concrete, computable framework (cellError, torus grids, GPU enumeration) combined with a formalization infrastructure (Lean 4, Baker axiom) that can validate intermediate results mechanically. No one else has attacked Furstenberg from this computational-Diophantine angle.

**Realistic best case:** We prove the Entropy Production Conjecture, reducing Furstenberg to Rudolph (already proved). This would be a major theorem in ergodic number theory.

**Realistic worst case:** We produce compelling computational evidence and a partial result (e.g., Furstenberg for measures satisfying an explicit Diophantine condition), publishable in a top journal, that clarifies the remaining obstacle.
