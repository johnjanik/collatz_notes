# Why Your Piano Can't Play a Perfect Major Third (And What That Has to Do With the Collatz Conjecture)

*The same number-theoretic obstruction that makes equal temperament slightly out of tune also governs why 3n+1 trajectories can't stagnate.*

---

Here is a graph that contains, in one image, the core mechanism of [my recent paper](https://github.com/johnjanik/syracuse-confinement) on the Collatz conjecture.

It has nothing to do with 3n+1. It's about music.

[IMAGE: Error in Best Approximation to 5/4 in N-tone Equal Temperament]

## The question

A "just" major third -- the interval from C to E that sounds perfectly consonant -- is the frequency ratio 5/4. When you play a major third on a piano, you don't get 5/4. You get 2^(4/12) = 2^(1/3) = 1.2599..., which is about 0.8% sharp.

This is the original sin of the twelve-tone scale. We divide the octave into 12 equal logarithmic steps, and it turns out that none of the 12 steps lands exactly on 5/4.

Fine. So try more notes. What about 24 notes per octave? Or 31? Or 53?

The graph above plots, for each N from 24 to 100, the best possible major-third error in N-tone equal temperament. That is: for each N, we find the integer m that makes 2^(m/N) closest to 5/4, and plot the absolute error.

Something jumps out immediately: the data separates into **three distinct strands**.

Why three?

## The answer: a Diophantine bottleneck

Finding the best major third in N-TET is equivalent to finding the integer m closest to N times a specific irrational number:

> alpha = log_2(5/4) = 0.32192809489...

This number has a continued fraction expansion that begins [0; 3, 9, 2, 1, 1, 3, ...], and its very first convergent is **1/3**.

That's the whole answer. The number 0.32193 is very close to 1/3 (within 3.5%), so the behavior of any particular N depends almost entirely on **N mod 3**.

- **N divisible by 3**: The nearest m gives m/N = 1/3 exactly. The error is locked at |2^(1/3) - 5/4| = 0.00992, no matter how large N is. This is the flat band across the top of the graph. N = 12, 24, 27, 30, 33, 36 -- they all give the exact same error, because they're all just repeating the approximation 1/3.

- **N = 1 mod 3**: These land near the "good" approximations. N = 28 (the next convergent denominator, with 9/28 = 0.32143) nearly nails it. This strand starts low and slowly rises.

- **N = 2 mod 3**: These start high and descend, hitting a spectacular near-zero at N = 59 (where 19/59 = 0.32203).

Three residue classes, three strands. The strands drift and weave as N grows, because 0.32193 isn't *exactly* 1/3 -- but the three-fold structure persists.

## The N = 24 mystery

Here's a fact that has irritated microtonal musicians for decades: **24-tone equal temperament does no better than 12-tone at the major third.**

Now you can see exactly why. Both 12 and 24 are divisible by 3, so both are trapped in the top strand. For N = 12, the best m is 4, giving 4/12 = 1/3. For N = 24, the best m is 8, giving 8/24 = 1/3. You've doubled the number of notes and learned absolutely nothing new.

Improvement requires escaping this strand entirely. The first escape hatch is N = 28 (one of the convergent denominators), which drops the error from 0.01 to 0.0004 -- a factor of 25 improvement. The next is N = 59, which drops it below 0.0001.

The pattern: doubling the resolution doesn't help. You need to reach the *next convergent denominator* of the continued fraction.

This is called **Diophantine stagnation**. And it is *exactly* what happens in the Collatz problem.

## The connection to Collatz

The Collatz map takes n to n/2 (if even) or (3n+1)/2 (if odd). A trajectory starting at some n generates a sequence of halvings and triplings. After t steps, if you've tripled nu_3 times and halved nu_2 times, the iterate is approximately:

> n_t ~ n_0 * 3^(nu_3) / 2^(nu_2)

For the trajectory to eventually reach 1, the halvings have to win: we need nu_2 to outpace nu_3 * log_2(3). The **deficit** -- the amount by which halvings are winning -- is:

> deficit(t) = nu_2(t) - nu_3(t) * log_2(3)

The Collatz conjecture says this deficit grows without bound.

And here's the parallel:

| Musical thirds | Collatz dynamics |
|---|---|
| Irrational constant: log_2(5/4) | Irrational constant: log_2(3) |
| Lattice parameter: N (notes per octave) | Lattice parameter: t (trajectory time) |
| Integer to approximate: m (scale degree) | Integer to approximate: nu_3 (odd steps) |
| Error: \|N * alpha - m\| | Deficit: nu_2 - nu_3 * log_2(3) |
| Convergent denominators: 3, 28, 59, ... | Convergent denominators of log_2(3) |

In music, the irrational number log_2(5/4) must be approximated by m/N, and the quality of the approximation is controlled by the continued fraction. In Collatz, the irrational number log_2(3) must be approximated by nu_3/nu_2, and the quality of *that* approximation is controlled by *its* continued fraction.

**The three strands of the musical graph are the one-dimensional version of the torus sieve in my paper.**

In the paper, I work on a two-dimensional torus (Z/kZ)^2, where k = 3, 9, 27, 81, ..., and track which "cell" the trajectory occupies. Each cell has a "cell error" -- its distance from the equilibrium line where tripling and halving exactly balance. At k = 3, there are three cells, and they have three different errors. Those are the three strands.

## The moat

Now look at the graph again. Notice the *white space* between the strands. There are no dots there. That gap is not a coincidence -- it is guaranteed by a theorem.

Baker's theorem (1966) on linear forms in logarithms says:

> |p log 2 - q log 5| > C / (p + q)^mu

for an effective constant C and exponent mu. In plain English: you can never approximate log_2(5/4) *too* well with a rational number. There is always a minimum error, and it shrinks very slowly (polynomially, not exponentially).

That minimum error is the **moat** between the strands. In the musical graph, it's the white space. In the Collatz torus sieve, it's the "Baker gap" that prevents the trajectory from hovering on the equilibrium line forever.

This is the deepest connection. The reason a piano can't play a perfect major third is the same reason a Collatz trajectory can't stagnate: the relevant logarithms are not just irrational, but *badly approximable* in a precise, quantitative sense that Baker's theorem makes effective.

## The kick

One more thing. As N increases, the strands drift and cross each other. The top strand (multiples of 3) eventually descends; the bottom strand rises to meet it. Around N = 45, the strands begin to reorder. By N = 87, what was the top strand has become the bottom (N = 87 = 3 * 29, and 28/87 = 0.32184 is very close to alpha).

This crossing happens because the accumulated drift -- the difference between alpha and 1/3, multiplied by N -- eventually exceeds half a step, forcing the optimal m to jump from one integer to the next. In the Collatz setting, the analogous phenomenon is what I call a **kick vector**: the trajectory is "kicked" from one cell of the torus sieve to another, and the Baker bound ensures that these kicks always produce net positive drift toward descent.

## The punchline

The graph of equal temperament errors is a one-dimensional cross-section of a two-dimensional object (the torus sieve) that governs the Collatz conjecture.

The three strands exist because log_2(5/4) is close to 1/3.

The stagnation at N = 24 happens because doubling a convergent denominator doesn't help -- you need the *next* convergent.

The moat between strands is Baker's theorem, preventing the error from ever vanishing.

And the slow drift of strands, eventually crossing and reordering, is the mechanism by which the deficit accumulates over time.

In the words of equal temperament: *the twelve-tone scale cannot perfectly tune the major third, because log_2(5) is irrational and its continued fraction traps every multiple of 12 in the same strand.*

In the words of the Collatz conjecture: *the trajectory cannot stagnate, because log_2(3) is irrational and Baker's theorem forces the deficit to grow.*

Same theorem. Same obstruction. Different primes.

---

*The formal treatment is in the companion note ["Equal Temperament and Diophantine Confinement: Why the Major Third Has Three Strands."](docs/musical_thirds.pdf) The Lean 4 formalization and computational tools are at [github.com/johnjanik/syracuse-confinement](https://github.com/johnjanik/syracuse-confinement). Previous post: [I Spent Two Weeks Building a 9,000-Line Proof Assistant Formalization of the Collatz Conjecture with an AI.](substack_article.md)*
