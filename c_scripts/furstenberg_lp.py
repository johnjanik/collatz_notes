#!/usr/bin/env python3
"""
furstenberg_lp.py — LP Polytope Probe for Furstenberg ×2,×3

Probes the polytope P_j = { w >= 0 : A_j w = 0, Σ_coarse = 1 } to determine:
  1. Off-line max deviation (orthogonal to δ₀-λ direction)
  2. Orbit-concentrated max(p_k) per T₃-orbit
  3. Bounded-density max deviation (p_k ≤ C/N)

Usage: python3 furstenberg_lp.py [--jmax N]
"""

import sys, time
import numpy as np
from scipy.optimize import linprog

def build_T3(A, row0, col0, N_s):
    for m in range(N_s):
        for s in range(3):
            A[row0 + m, col0 + 3*m + s] += 1.0
        for r in range(3):
            a = m + r * N_s
            A[row0 + m, col0 + 3*(a // 3) + (a % 3)] -= 1.0

def build_refine(A, row0, col_c, col_f, N_c):
    for k in range(N_c):
        for s in range(3):
            row = row0 + 3*k + s
            a1 = 6*k + 2*s; a2 = a1 + 1
            A[row, col_c + 3*k + s] += 1.0
            A[row, col_f + 3*(a1//3) + a1%3] -= 1.0
            A[row, col_f + 3*(a2//3) + a2%3] -= 1.0

def build_T2(A, row0, col_c, col_f, N_c):
    for k in range(N_c):
        for s in range(3):
            row = row0 + 3*k + s
            A[row, col_c + 3*k + s] += 1.0
            A[row, col_f + 3*k + s] -= 1.0
            A[row, col_f + 3*(k + N_c) + s] -= 1.0

def build_system(j):
    N = 1 << j; cols = 9*N
    A = np.zeros((9*N, cols))
    r = 0
    build_T3(A, r, 0, N);          r += N
    build_T3(A, r, 3*N, 2*N);      r += 2*N
    build_refine(A, r, 0, 3*N, N);  r += 3*N
    build_T2(A, r, 0, 3*N, N)
    return A, N

def atom_masses(w, N):
    return np.array([w[3*k]+w[3*k+1]+w[3*k+2] for k in range(N)])

def t3_orbits(N):
    visited = set(); orbits = []
    for start in range(N):
        if start in visited: continue
        orb = []; k = start
        while k not in visited:
            visited.add(k); orb.append(k); k = (3*k) % N
        orbits.append(orb)
    return orbits

def analyze(j):
    t0 = time.time()
    N = 1 << j; cols = 9*N; u = 1.0/N

    # Reference solutions
    w_leb = np.zeros(cols)
    w_leb[:3*N] = 1.0/(3*N); w_leb[3*N:] = 1.0/(6*N)
    w_d0 = np.zeros(cols)
    w_d0[0] = 1.0; w_d0[3*N] = 1.0

    # Build constraint system
    A, _ = build_system(j)
    assert np.allclose(A @ w_leb, 0, atol=1e-12)
    assert np.allclose(A @ w_d0, 0, atol=1e-12)

    norm_row = np.zeros((1, cols)); norm_row[0, :3*N] = 1.0
    A_eq = np.vstack([A, norm_row])
    b_eq = np.zeros(A_eq.shape[0]); b_eq[-1] = 1.0
    bnds = [(0, None)] * cols

    rk = np.linalg.matrix_rank(A_eq, tol=1e-10)
    pdim = cols - rk

    print(f"\n{'='*70}")
    print(f"  j={j}, N={N}, 9N={cols}, polytope dim={pdim}")
    print(f"{'='*70}")

    # ── Probe A: max(p_k) per T₃-orbit ──────────────────────────────
    orbits = t3_orbits(N)
    print(f"\n  Probe A: T₃ orbit max(p_k)  ({len(orbits)} orbits)")
    orbit_results = []
    for orb in sorted(orbits, key=len):
        k = orb[0]
        c = np.zeros(cols)
        c[3*k]=1; c[3*k+1]=1; c[3*k+2]=1
        res = linprog(-c, A_eq=A_eq, b_eq=b_eq, bounds=bnds,
                      method='highs', options={'disp':False})
        mpk = -res.fun if res.success else 0
        orbit_results.append((len(orb), k, mpk))
        print(f"    |orb|={len(orb):4d}  rep={k:5d}  max(p_k)={mpk:.6f}"
              f"  ({mpk/u:.1f}x uniform)")

    # ── Probe B: off-line max deviation ──────────────────────────────
    # Add constraint: orthogonal to δ₀-λ at Lebesgue
    d = w_d0 - w_leb
    A_eq_o = np.vstack([A_eq, d.reshape(1,-1)])
    b_eq_o = np.append(b_eq, np.dot(d, w_leb))

    print(f"\n  Probe B: off-line max(p_k) per atom (orthog to δ₀-λ)")

    # Sample atoms: first 16 + orbit reps
    atoms = list(range(min(N, 16)))
    for orb in orbits:
        if orb[0] not in atoms: atoms.append(orb[0])
    atoms = sorted(set(atoms))

    omax = {}; omin = {}
    for k in atoms:
        c = np.zeros(cols)
        c[3*k]=1; c[3*k+1]=1; c[3*k+2]=1
        rM = linprog(-c, A_eq=A_eq_o, b_eq=b_eq_o, bounds=bnds,
                     method='highs', options={'disp':False})
        rm = linprog(c, A_eq=A_eq_o, b_eq=b_eq_o, bounds=bnds,
                     method='highs', options={'disp':False})
        omax[k] = -rM.fun if rM.success else u
        omin[k] = rm.fun if rm.success else u

    off_max_above = max(v - u for v in omax.values())
    off_max_below = max(u - v for v in omin.values())
    off_max_dev = max(off_max_above, off_max_below)

    print(f"  max off-line |p_k - 1/N| = {off_max_dev:.8f} "
          f"(relative: {off_max_dev/u:.4f})")
    for k in atoms[:16]:
        rng = (omax[k] - omin[k]) / u
        print(f"    k={k:5d}: p∈[{omin[k]:.8f}, {omax[k]:.8f}]  range={rng:.3f}×(1/N)")

    # ── Probe C: bounded-density off-line max deviation ──────────────
    # Add p_k ≤ C/N for ALL atoms (excludes atomic measures)
    C_vals = [2.0, 4.0]
    print(f"\n  Probe C: bounded-density off-line max(p_k)")
    bd_results = {}
    for C in C_vals:
        # Upper bound constraints: p_k ≤ C*u for all k
        A_ub = np.zeros((N, cols))
        b_ub = np.full(N, C * u)
        for k in range(N):
            A_ub[k, 3*k]=1; A_ub[k, 3*k+1]=1; A_ub[k, 3*k+2]=1

        # Maximize p_0 (representative)
        c = np.zeros(cols); c[0]=1; c[1]=1; c[2]=1
        res = linprog(-c, A_ub=A_ub, b_ub=b_ub,
                      A_eq=A_eq_o, b_eq=b_eq_o, bounds=bnds,
                      method='highs', options={'disp':False})
        if res.success:
            mpk = -res.fun
            p = atom_masses(res.x, N)
            sd = np.std(p)
            p_pos = p[p > 1e-15]
            ent = -np.sum(p_pos * np.log(p_pos))
            ent_def = np.log(N) - ent
            nz = np.sum(p < 1e-12)
            bd_results[C] = {'max_p0': mpk, 'std': sd, 'ent_def': ent_def, 'nzero': nz}
            print(f"    C={C:.0f}: max(p_0)={mpk:.8f} ({mpk/u:.3f}×u), "
                  f"std/u={sd/u:.4f}, ent_deficit={ent_def:.6f}, "
                  f"zeros={nz}/{N}")
        else:
            bd_results[C] = None
            print(f"    C={C:.0f}: {res.message}")

    dt = time.time() - t0
    print(f"\n  time: {dt:.1f}s")

    return {
        'j': j, 'N': N, 'pdim': pdim,
        'n_orbits': len(orbits),
        'off_max_dev': off_max_dev,
        'off_max_rel': off_max_dev / u,
        'bd2_std_rel': bd_results[2.0]['std']/u if bd_results.get(2.0) else None,
        'bd2_ent_def': bd_results[2.0]['ent_def'] if bd_results.get(2.0) else None,
        'bd4_std_rel': bd_results[4.0]['std']/u if bd_results.get(4.0) else None,
        'bd4_ent_def': bd_results[4.0]['ent_def'] if bd_results.get(4.0) else None,
        'time': dt,
    }

def main():
    j_max = 10
    for i, a in enumerate(sys.argv[1:]):
        if a == '--jmax': j_max = int(sys.argv[i+2])

    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  Furstenberg LP Polytope Probe: Phase A                    ║")
    print("╚══════════════════════════════════════════════════════════════╝")

    results = []
    for j in range(3, j_max + 1):
        results.append(analyze(j))

    print("\n" + "="*100)
    print("  GRAND SUMMARY")
    print("="*100)
    print(f"  {'j':>3} | {'N':>6} | {'pdim':>5} | {'off-rel':>8} | "
          f"{'bd2-std/u':>9} | {'bd2-entdef':>10} | "
          f"{'bd4-std/u':>9} | {'bd4-entdef':>10} | {'time':>6}")
    print(f"  {'─'*3}─┼─{'─'*6}─┼─{'─'*5}─┼─{'─'*8}─┼─"
          f"{'─'*9}─┼─{'─'*10}─┼─"
          f"{'─'*9}─┼─{'─'*10}─┼─{'─'*6}")
    for r in results:
        def f(v, fmt): return fmt.format(v) if v is not None else "N/A"
        print(f"  {r['j']:3d} | {r['N']:6d} | {r['pdim']:5d} | "
              f"{r['off_max_rel']:8.3f} | "
              f"{f(r['bd2_std_rel'],'{:9.4f}')} | {f(r['bd2_ent_def'],'{:10.6f}')} | "
              f"{f(r['bd4_std_rel'],'{:9.4f}')} | {f(r['bd4_ent_def'],'{:10.6f}')} | "
              f"{r['time']:5.1f}s")

    # Key finding: off-line relative deviation trend
    print("\n  KEY: off-line relative deviation (should shrink if polytope collapses)")
    for r in results:
        bar = '#' * int(r['off_max_rel'] * 2)
        print(f"    j={r['j']:2d}: {r['off_max_rel']:8.4f}  {bar}")

if __name__ == '__main__':
    main()
