#!/usr/bin/env python3
"""
Branch Locus Visualizer — 100B Run Results
============================================
Produces 7 publication-quality figures from the 100B branch locus computation
(61.5h, 25.1T steps, 27 k-levels, all consistent).

Output: visualizations/branch_locus_fig{1..7}.png (180 DPI)
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm, Normalize, LinearSegmentedColormap
from matplotlib.gridspec import GridSpec
import matplotlib.ticker as ticker
import math, time, os, sys

# ─── Paths ────────────────────────────────────────────────────────────
DATA = os.path.join(os.path.dirname(__file__), '..', 'saved_output')
OUT  = os.path.join(os.path.dirname(__file__), '..', 'visualizations')
os.makedirs(OUT, exist_ok=True)

# ─── Style (matching collatz_anosov.py / collatz_winding.py) ─────────
BG      = '#08080f'
AX_BG   = '#0e0e1a'
TXT     = '#c8c8d8'
GRID_C  = '#444466'
GRID_A  = 0.12
SPINE_C = '#333348'
TICK_C  = '#888898'
LEG_BG  = '#1a1a2e'

GREEN   = '#00ff88'
PINK    = '#e85d75'
PURPLE  = '#7b68ee'
GOLD    = '#ffaa00'
CYAN    = '#00ddff'

DPI = 180
LOG2_3 = math.log2(3)


def style_ax(ax, title, xlabel='', ylabel='', fontsize=12):
    ax.set_facecolor(AX_BG)
    ax.set_title(title, color=TXT, fontsize=fontsize, fontweight='bold', pad=10)
    ax.set_xlabel(xlabel, color=TXT, fontsize=10)
    ax.set_ylabel(ylabel, color=TXT, fontsize=10)
    ax.tick_params(colors=TICK_C)
    for sp in ax.spines.values():
        sp.set_color(SPINE_C)
    ax.grid(True, alpha=GRID_A, color=GRID_C)


def legend(ax, **kw):
    defaults = dict(fontsize=8, facecolor=LEG_BG, edgecolor=SPINE_C,
                    labelcolor=TXT, loc='best')
    defaults.update(kw)
    ax.legend(**defaults)


def savefig(fig, name):
    path = os.path.join(OUT, name)
    fig.savefig(path, dpi=DPI, facecolor=fig.get_facecolor(),
                bbox_inches='tight', pad_inches=0.15)
    plt.close(fig)
    print(f"  Saved {path}")


# ─── Load data ────────────────────────────────────────────────────────
print("Loading data...")
t0 = time.time()

summary = pd.read_csv(os.path.join(DATA, 'branch_summary.csv'))
params  = pd.read_csv(os.path.join(DATA, 'branch_params.csv'))
params_dict = dict(zip(params['key'], params['value']))

cells   = pd.read_csv(os.path.join(DATA, 'branch_cells.csv'))
trans   = pd.read_csv(os.path.join(DATA, 'branch_transitions.csv'))
shadow  = pd.read_csv(os.path.join(DATA, 'branch_shadow.csv'))
foli    = pd.read_csv(os.path.join(DATA, 'branch_foliation.csv'))
ckpts   = pd.read_csv(os.path.join(DATA, 'branch_checkpoints.csv'))

print(f"  Loaded in {time.time()-t0:.1f}s  "
      f"(cells: {len(cells):,}, shadow: {len(shadow):,}, "
      f"foliation: {len(foli):,}, checkpoints: {len(ckpts):,})")

N_total = int(float(params_dict['N']))
total_steps = int(float(params_dict['total_steps']))
global_p_odd = float(params_dict['global_p_odd'])

# ═════════════════════════════════════════════════════════════════════
# FIGURE 1: Cell Saturation & Scale Overview (2×2)
# ═════════════════════════════════════════════════════════════════════
print("\nFigure 1: Cell Saturation & Scale Overview...")

fig = plt.figure(figsize=(16, 13), facecolor=BG)
gs = GridSpec(2, 2, figure=fig, hspace=0.35, wspace=0.30,
              left=0.08, right=0.95, top=0.93, bottom=0.06)

# ── 1a: Branch cell count vs k (log-log) ──
ax = fig.add_subplot(gs[0, 0])
style_ax(ax, 'Branch Cell Count vs k', 'k', 'Branch cells')
ks = summary['k'].values
bc = summary['branch_cells'].values
ax.loglog(ks, bc, 'o-', color=GREEN, ms=5, lw=1.5, label='Branch cells')
# k² reference
k_ref = np.logspace(0, np.log10(ks.max()), 100)
ax.loglog(k_ref, k_ref**2, '--', color=GOLD, alpha=0.5, lw=1, label='k²')
ax.axhline(21632, color=PINK, ls=':', lw=1.5, alpha=0.7, label='Saturation: 21,632')
legend(ax)

# ── 1b: Occupancy fraction vs k (log-log) ──
ax = fig.add_subplot(gs[0, 1])
style_ax(ax, 'Occupancy Fraction vs k', 'k', 'Occupied / k²')
occupied = summary['branch_cells'] + summary['pure_even'] + summary['pure_odd']
k2 = summary['k']**2
frac = occupied / k2
ax.loglog(ks, frac, 's-', color=CYAN, ms=5, lw=1.5, label='Occupancy')
ax.axhline(1.0, color=GREEN, ls='--', lw=1, alpha=0.5, label='Full occupancy')
ax.set_ylim(frac.min() * 0.5, 2.0)
ax.yaxis.set_major_formatter(ticker.ScalarFormatter())
legend(ax)

# ── 1c: Cell type composition stacked bars ──
ax = fig.add_subplot(gs[1, 0])
style_ax(ax, 'Cell Type Composition by k-Level', 'k-level index', 'Cell count')
x_idx = np.arange(len(ks))
labels_k = [str(k) for k in ks]
bottom = np.zeros(len(ks))
for col, color, lbl in [('branch_cells', GREEN, 'Branch'),
                         ('pure_even', CYAN, 'Pure even'),
                         ('pure_odd', PURPLE, 'Pure odd'),
                         ('empty', '#444466', 'Empty')]:
    vals = summary[col].values.astype(float)
    # Clip empty for visibility: show log-proportional bars
    ax.bar(x_idx, vals, bottom=bottom, color=color, alpha=0.85, label=lbl, width=0.8)
    bottom += vals
ax.set_xticks(x_idx[::3])
ax.set_xticklabels([labels_k[i] for i in range(0, len(labels_k), 3)],
                    rotation=45, fontsize=7)
ax.set_yscale('log')
ax.set_ylim(0.5, bottom.max() * 2)
legend(ax, fontsize=7, ncol=2)

# ── 1d: Key statistics text panel ──
ax = fig.add_subplot(gs[1, 1])
ax.set_facecolor(AX_BG)
ax.set_title('100B Branch Locus — Key Statistics',
             color=TXT, fontsize=12, fontweight='bold', pad=10)
for sp in ax.spines.values():
    sp.set_color(SPINE_C)
ax.set_xticks([])
ax.set_yticks([])

# Count zero-oo transitions
oo_zero = (summary['total_oo'] == 0).sum()
stats_text = (
    f"N = {N_total:,}\n"
    f"Total steps = {total_steps:,}\n"
    f"Mean trajectory length = {float(params_dict['mean_traj_len']):.2f}\n"
    f"Global p_odd = {global_p_odd:.9f}\n"
    f"\n"
    f"Number of k-levels: {len(ks)}\n"
    f"Max branch cells: {bc.max():,}  (saturates at k ≥ 216)\n"
    f"Pure even cells: {summary['pure_even'].iloc[-1]:,}\n"
    f"Pure odd cells: {summary['pure_odd'].iloc[-1]:,}\n"
    f"\n"
    f"Zero oo-transitions: {oo_zero} of {len(ks)} levels\n"
    f"k-levels with transitions: 81, 108, 144, 729\n"
    f"\n"
    f"Runtime: 61.5 hours (24-thread OpenMP)\n"
    f"Hardware: Intel Core Ultra 9 275HX"
)
ax.text(0.08, 0.92, stats_text, transform=ax.transAxes,
        fontsize=10, color=TXT, va='top', ha='left',
        fontfamily='monospace', linespacing=1.5)

savefig(fig, 'branch_locus_fig1.png')

# ═════════════════════════════════════════════════════════════════════
# FIGURE 2: Torus Heatmaps at 4 Scales (2×2)
# ═════════════════════════════════════════════════════════════════════
print("Figure 2: Torus Heatmaps...")

fig = plt.figure(figsize=(16, 14), facecolor=BG)
gs = GridSpec(2, 2, figure=fig, hspace=0.32, wspace=0.28,
              left=0.07, right=0.96, top=0.93, bottom=0.06)

heatmap_ks = [81, 144, 216, 729]
cmap_hot = LinearSegmentedColormap.from_list('dark_hot',
    ['#000000', '#1a0a2e', '#4a1942', '#e85d75', '#ffaa00', '#ffffff'])

for idx, hk in enumerate(heatmap_ks):
    ax = fig.add_subplot(gs[idx // 2, idx % 2])
    style_ax(ax, f'p_odd on T² at k = {hk}', 'r₂', 'r₃', fontsize=11)

    sub = cells[cells['k'] == hk].copy()
    grid = np.full((hk, hk), np.nan)
    grid[sub['r3'].values, sub['r2'].values] = sub['p_odd'].values

    im = ax.imshow(grid, origin='lower', cmap=cmap_hot,
                   vmin=0, vmax=0.5, aspect='equal',
                   interpolation='nearest', extent=[0, hk, 0, hk])

    # Mark pure_even cells
    pe = sub[sub['cell_type'] == 'pure_even']
    if len(pe) > 0 and len(pe) < 5000:
        ax.scatter(pe['r2'].values + 0.5, pe['r3'].values + 0.5,
                   s=max(1, 80 / (hk / 81)), color=CYAN, alpha=0.7,
                   marker='s', linewidths=0, label=f'Pure even ({len(pe)})')

    # Irrational foliation line: r3/r2 = log₂(3)
    r2_line = np.linspace(0, hk, 500)
    r3_line = LOG2_3 * r2_line % hk
    ax.plot(r2_line, r3_line, ',', color=GREEN, alpha=0.3, ms=0.5)

    cb = fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    cb.set_label('p_odd', color=TXT, fontsize=9)
    cb.ax.tick_params(colors=TICK_C)
    if len(pe) > 0 and len(pe) < 5000:
        legend(ax, fontsize=7, loc='upper right')

savefig(fig, 'branch_locus_fig2.png')

# ═════════════════════════════════════════════════════════════════════
# FIGURE 3: Diophantine Signature (1×3)
# ═════════════════════════════════════════════════════════════════════
print("Figure 3: Diophantine Signature...")

fig = plt.figure(figsize=(22, 7), facecolor=BG)
gs = GridSpec(1, 3, figure=fig, wspace=0.28,
              left=0.05, right=0.97, top=0.90, bottom=0.12)

sh729 = shadow[shadow['k'] == 729].copy()

# ── 3a: dist_irrational vs p_odd colored by cell_type ──
ax = fig.add_subplot(gs[0, 0])
style_ax(ax, 'Diophantine Distance vs p_odd  (k=729)',
         'Distance to irrational foliation', 'p_odd')

type_colors = {'branch': GREEN, 'pure_even': CYAN, 'pure_odd': PURPLE}
for ct, color in type_colors.items():
    sub = sh729[sh729['cell_type'] == ct]
    if len(sub) == 0:
        continue
    ax.scatter(sub['dist_irrational'], sub['p_odd'],
               s=1.5, color=color, alpha=0.4, label=ct, rasterized=True)
ax.axhline(global_p_odd, color=PINK, ls=':', lw=1, alpha=0.6,
           label=f'Global p_odd = {global_p_odd:.4f}')
legend(ax, fontsize=7)

# ── 3b: Shadow offset histogram (branch vs pure_even) ──
ax = fig.add_subplot(gs[0, 1])
style_ax(ax, 'Shadow Offset Distribution  (k=729)',
         'Shadow offset', 'Count')

branch_off = sh729[sh729['cell_type'] == 'branch']['shadow_offset']
pe_off = sh729[sh729['cell_type'] == 'pure_even']['shadow_offset']
bins = np.linspace(0, max(branch_off.max(), pe_off.max()) * 1.02, 80)
ax.hist(branch_off, bins=bins, color=GREEN, alpha=0.7, label='Branch')
ax.hist(pe_off, bins=bins, color=CYAN, alpha=0.7, label='Pure even')
ax.set_yscale('log')
legend(ax)

# ── 3c: dist_irrational vs dist_rational colored by p_odd ──
ax = fig.add_subplot(gs[0, 2])
style_ax(ax, 'Irrational vs Rational Distance  (k=729)',
         'dist_irrational', 'dist_rational')

sc = ax.scatter(sh729['dist_irrational'], sh729['dist_rational'],
                c=sh729['p_odd'], cmap=cmap_hot, s=1.5, alpha=0.5,
                vmin=0, vmax=0.5, rasterized=True)
cb = fig.colorbar(sc, ax=ax, fraction=0.046, pad=0.04)
cb.set_label('p_odd', color=TXT, fontsize=9)
cb.ax.tick_params(colors=TICK_C)
# Diagonal
lim = max(sh729['dist_irrational'].max(), sh729['dist_rational'].max())
ax.plot([0, lim], [0, lim], '--', color=GOLD, alpha=0.4, lw=1)

savefig(fig, 'branch_locus_fig3.png')

# ═════════════════════════════════════════════════════════════════════
# FIGURE 4: SFT Forbidden Transitions (1×3)
# ═════════════════════════════════════════════════════════════════════
print("Figure 4: SFT Forbidden Transitions...")

fig = plt.figure(figsize=(22, 7), facecolor=BG)
gs = GridSpec(1, 3, figure=fig, wspace=0.28,
              left=0.05, right=0.97, top=0.90, bottom=0.12)

# ── 4a: Transition composition heatmap at k=81 ──
ax = fig.add_subplot(gs[0, 0])
style_ax(ax, 'Transition Matrix Composition  (k=81)',
         'Cell index (sorted by valence)', 'Transition fraction')

tr81 = trans[trans['k'] == 81].copy().sort_values('valence')
total_tr = tr81['ee'] + tr81['eo'] + tr81['oe'] + tr81['oo']
total_tr = total_tr.replace(0, 1)  # avoid div-by-0
for col, color, lbl in [('ee', '#4488ff', 'ee'), ('eo', GREEN, 'eo'),
                         ('oe', PINK, 'oe'), ('oo', GOLD, 'oo')]:
    frac = tr81[col].values / total_tr.values
    ax.scatter(np.arange(len(tr81)), frac, s=1, color=color,
               alpha=0.5, label=lbl, rasterized=True)
ax.axhline(0, color='white', alpha=0.2, lw=0.5)
legend(ax, fontsize=8)

# ── 4b: Valence distribution across k-levels ──
ax = fig.add_subplot(gs[0, 1])
style_ax(ax, 'Valence Distribution by k-Level', 'Valence', 'Fraction of cells')

trans_ks = sorted(trans['k'].unique())
bar_width = 0.8 / len(trans_ks)
for i, tk in enumerate(trans_ks):
    sub = trans[trans['k'] == tk]
    vcounts = sub['valence'].value_counts(normalize=True).sort_index()
    ax.bar(vcounts.index + i * bar_width - 0.3, vcounts.values,
           width=bar_width, alpha=0.8,
           color=[GREEN, PINK, PURPLE, CYAN][i % 4],
           label=f'k={tk}')
ax.set_xticks([0, 1, 2, 3, 4])
legend(ax, fontsize=7)

# ── 4c: Entry type specialization across k ──
ax = fig.add_subplot(gs[0, 2])
style_ax(ax, 'Entry Type Specialization by k', 'k-level', 'Fraction')

for i, tk in enumerate(trans_ks):
    sub = trans[trans['k'] == tk]
    n_total = len(sub)
    for etype, color, marker in [('branch', GREEN, 'o'), ('mixed', PURPLE, 's'),
                                  ('none', '#666666', 'x')]:
        frac_e = (sub['entry_type'] == etype).sum() / n_total
        ax.scatter(tk, frac_e, color=color, s=60, marker=marker,
                   alpha=0.8, zorder=3,
                   label=etype if i == 0 else None)

ax.set_xscale('log')
legend(ax, fontsize=8)

savefig(fig, 'branch_locus_fig4.png')

# ═════════════════════════════════════════════════════════════════════
# FIGURE 5: Foliation Enrichment Collapse (2×2)
# ═════════════════════════════════════════════════════════════════════
print("Figure 5: Foliation Enrichment Collapse...")

fig = plt.figure(figsize=(16, 13), facecolor=BG)
gs = GridSpec(2, 2, figure=fig, hspace=0.35, wspace=0.30,
              left=0.08, right=0.95, top=0.93, bottom=0.06)

# Merge foliation with cells for p_odd
foli_cells = foli.merge(cells[['k', 'r2', 'r3', 'p_odd', 'cell_type']],
                         on=['k', 'r2', 'r3'], how='left')

# ── 5a: Fraction of cells on unstable foliation vs k ──
ax = fig.add_subplot(gs[0, 0])
style_ax(ax, 'Fraction on Unstable Foliation vs k', 'k', 'Fraction on_unstable')

foli_ks = sorted(foli['k'].unique())
frac_unstable = []
for fk in foli_ks:
    sub = foli[foli['k'] == fk]
    occupied = sub[sub.index.isin(cells[(cells['k'] == fk) &
                  (cells['cell_type'] != 'empty')].merge(
                  sub[['k', 'r2', 'r3']], on=['k', 'r2', 'r3']).index)]
    # Simpler: count on_unstable among all cells at this k
    frac_u = sub['on_unstable'].sum() / len(sub) if len(sub) > 0 else 0
    frac_unstable.append(frac_u)

ax.semilogy(foli_ks, frac_unstable, 'o-', color=GREEN, ms=5, lw=1.5)
ax.set_xscale('log')
legend(ax)

# ── 5b: p_odd for on-foliation vs off-foliation cells ──
ax = fig.add_subplot(gs[0, 1])
style_ax(ax, 'p_odd: On vs Off Unstable Foliation  (k=81)',
         'p_odd', 'Density')

fc81 = foli_cells[foli_cells['k'] == 81]
on_u = fc81[fc81['on_unstable'] == 1]['p_odd'].dropna()
off_u = fc81[fc81['on_unstable'] == 0]['p_odd'].dropna()
bins_p = np.linspace(0, 0.5, 60)
if len(on_u) > 0:
    ax.hist(on_u, bins=bins_p, color=GREEN, alpha=0.7, density=True,
            label=f'On unstable ({len(on_u)})')
if len(off_u) > 0:
    ax.hist(off_u, bins=bins_p, color=PINK, alpha=0.5, density=True,
            label=f'Off unstable ({len(off_u)})')
ax.axvline(global_p_odd, color=GOLD, ls=':', lw=1.5, alpha=0.7,
           label=f'Global p_odd = {global_p_odd:.4f}')
legend(ax)

# ── 5c: Foliation distance map at k=81 ──
ax = fig.add_subplot(gs[1, 0])
style_ax(ax, 'Unstable Foliation Distance  (k=81)', 'r₂', 'r₃')

f81 = foli[foli['k'] == 81]
grid_d = np.full((81, 81), np.nan)
grid_d[f81['r3'].values, f81['r2'].values] = f81['dist_unstable'].values

cmap_dist = LinearSegmentedColormap.from_list('dark_dist',
    ['#000000', '#1a0a2e', '#7b68ee', '#00ddff', '#00ff88'])
im = ax.imshow(grid_d, origin='lower', cmap=cmap_dist, aspect='equal',
               extent=[0, 81, 0, 81])
# Overlay on_unstable cells
on_cells = f81[f81['on_unstable'] == 1]
if len(on_cells) > 0:
    ax.scatter(on_cells['r2'].values + 0.5, on_cells['r3'].values + 0.5,
               s=3, color=GREEN, alpha=0.8, zorder=3)
cb = fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
cb.set_label('dist_unstable', color=TXT, fontsize=9)
cb.ax.tick_params(colors=TICK_C)

# ── 5d: On-unstable cells at k=729 scatter ──
ax = fig.add_subplot(gs[1, 1])
style_ax(ax, 'Cells on Unstable Foliation  (k=729)', 'r₂', 'r₃')

f729 = foli[foli['k'] == 729]
on729 = f729[f729['on_unstable'] == 1]
n_on = len(on729)
n_total_729 = len(f729[f729.index.isin(
    cells[(cells['k'] == 729) & (cells['cell_type'] != 'empty')].merge(
    f729[['k', 'r2', 'r3']], on=['k', 'r2', 'r3']).index)])

ax.set_xlim(0, 729)
ax.set_ylim(0, 729)
# Show all occupied cells faintly
occ729 = cells[(cells['k'] == 729) & (cells['cell_type'] != 'empty')]
ax.scatter(occ729['r2'].values + 0.5, occ729['r3'].values + 0.5,
           s=0.3, color='#333348', alpha=0.3, rasterized=True)
# Highlight on_unstable
if n_on > 0:
    ax.scatter(on729['r2'].values + 0.5, on729['r3'].values + 0.5,
               s=15, color=GREEN, alpha=0.9, zorder=3,
               label=f'On unstable ({n_on} cells)')
# Foliation line
r2_line = np.linspace(0, 729, 2000)
r3_line = LOG2_3 * r2_line % 729
ax.plot(r2_line, r3_line, ',', color=GOLD, alpha=0.3, ms=0.3)
ax.text(0.02, 0.02, f'{n_on} on-unstable of {len(occ729):,} occupied',
        transform=ax.transAxes, fontsize=9, color=TXT, va='bottom')
legend(ax)

savefig(fig, 'branch_locus_fig5.png')

# ═════════════════════════════════════════════════════════════════════
# FIGURE 6: Cell-Level Statistics (2×3)
# ═════════════════════════════════════════════════════════════════════
print("Figure 6: Cell-Level Statistics...")

fig = plt.figure(figsize=(22, 13), facecolor=BG)
gs = GridSpec(2, 3, figure=fig, hspace=0.35, wspace=0.30,
              left=0.06, right=0.97, top=0.93, bottom=0.06)

c216 = cells[(cells['k'] == 216) & (cells['cell_type'] == 'branch')].copy()

# ── 6a: p_odd histogram at k=216 ──
ax = fig.add_subplot(gs[0, 0])
style_ax(ax, 'p_odd Distribution  (k=216, branch)', 'p_odd', 'Count')
ax.hist(c216['p_odd'], bins=80, color=PURPLE, alpha=0.85, edgecolor='none')
ax.axvline(global_p_odd, color=GREEN, ls='--', lw=1.5, alpha=0.8,
           label=f'Global: {global_p_odd:.4f}')
ax.axvline(c216['p_odd'].mean(), color=PINK, ls=':', lw=1.5, alpha=0.8,
           label=f'Mean: {c216["p_odd"].mean():.4f}')
ax.axvline(1/3, color=GOLD, ls='-.', lw=1, alpha=0.6, label='1/3')
legend(ax)

# ── 6b: Entropy histogram ──
ax = fig.add_subplot(gs[0, 1])
style_ax(ax, 'Entropy Distribution  (k=216, branch)', 'Entropy H', 'Count')
ax.hist(c216['entropy'], bins=80, color=CYAN, alpha=0.85, edgecolor='none')
ax.axvline(c216['entropy'].mean(), color=PINK, ls=':', lw=1.5, alpha=0.8,
           label=f'Mean: {c216["entropy"].mean():.4f}')
legend(ax)

# ── 6c: Slope deviation histogram ──
ax = fig.add_subplot(gs[0, 2])
style_ax(ax, 'Slope Deviation  (k=216, branch)', 'slope_dev', 'Count')
ax.hist(c216['slope_dev'], bins=80, color=PINK, alpha=0.85, edgecolor='none')
ax.axvline(c216['slope_dev'].mean(), color=GREEN, ls=':', lw=1.5, alpha=0.8,
           label=f'Mean: {c216["slope_dev"].mean():.4f}')
legend(ax)

# ── 6d: p_odd vs slope_dev colored by entropy ──
ax = fig.add_subplot(gs[1, 0])
style_ax(ax, 'p_odd vs Slope Deviation  (k=216)', 'p_odd', 'slope_dev')
sc = ax.scatter(c216['p_odd'], c216['slope_dev'], c=c216['entropy'],
                cmap='plasma', s=3, alpha=0.6, rasterized=True)
cb = fig.colorbar(sc, ax=ax, fraction=0.046, pad=0.04)
cb.set_label('Entropy H', color=TXT, fontsize=9)
cb.ax.tick_params(colors=TICK_C)

# ── 6e: Mean p_odd vs k with error bars ──
ax = fig.add_subplot(gs[1, 1])
style_ax(ax, 'Mean p_odd vs k (± σ)', 'k', 'Mean p_odd')
ax.errorbar(summary['k'], summary['mean_p_odd'], yerr=summary['std_p_odd'],
            fmt='o-', color=GREEN, ms=4, lw=1, ecolor=GREEN, elinewidth=0.5,
            alpha=0.8, capsize=2)
ax.axhline(global_p_odd, color=GOLD, ls=':', lw=1, alpha=0.6,
           label=f'Global: {global_p_odd:.4f}')
ax.axhline(1/3, color=PINK, ls='--', lw=1, alpha=0.4, label='1/3')
ax.set_xscale('log')
legend(ax)

# ── 6f: Mean entropy + std_slope_dev vs k (dual axis) ──
ax = fig.add_subplot(gs[1, 2])
style_ax(ax, 'Entropy & Slope Spread vs k', 'k', 'Mean entropy H')
l1, = ax.plot(summary['k'], summary['mean_H_branch'], 'o-', color=CYAN,
              ms=4, lw=1.2, alpha=0.8, label='Mean H')
ax.set_xscale('log')
ax2 = ax.twinx()
l2, = ax2.plot(summary['k'], summary['std_slope_dev'], 's-', color=PINK,
               ms=4, lw=1.2, alpha=0.8, label='σ(slope_dev)')
ax2.set_ylabel('σ(slope_dev)', color=TXT, fontsize=10)
ax2.tick_params(colors=TICK_C)
ax2.spines['right'].set_color(SPINE_C)
ax.legend(handles=[l1, l2], fontsize=8, facecolor=LEG_BG,
          edgecolor=SPINE_C, labelcolor=TXT)

savefig(fig, 'branch_locus_fig6.png')

# ═════════════════════════════════════════════════════════════════════
# FIGURE 7: Convergence over N (2×2)
# ═════════════════════════════════════════════════════════════════════
print("Figure 7: Convergence over N...")

fig = plt.figure(figsize=(16, 13), facecolor=BG)
gs = GridSpec(2, 2, figure=fig, hspace=0.35, wspace=0.30,
              left=0.08, right=0.95, top=0.93, bottom=0.06)

# ── 7a: Branch cell count at k=216 vs N ──
ax = fig.add_subplot(gs[0, 0])
style_ax(ax, 'Branch Cell Convergence  (k=216)', 'N', 'Branch cells')
c216_ck = ckpts[ckpts['k'] == 216]
ax.semilogx(c216_ck['checkpoint_N'], c216_ck['branch'], 'o-',
             color=GREEN, ms=3, lw=1.2)
ax.axhline(21632, color=PINK, ls=':', lw=1.5, alpha=0.7,
           label='Final: 21,632')
legend(ax)

# ── 7b: Multiple k-levels showing universal saturation ──
ax = fig.add_subplot(gs[0, 1])
style_ax(ax, 'Branch Cell Saturation Across k-Levels', 'N', 'Branch cells')
show_ks = [81, 108, 144, 162, 216]
colors_k = [GREEN, CYAN, PURPLE, PINK, GOLD]
for sk, sc in zip(show_ks, colors_k):
    sub = ckpts[ckpts['k'] == sk]
    ax.semilogx(sub['checkpoint_N'], sub['branch'], '-',
                 color=sc, lw=1.2, alpha=0.8, label=f'k={sk}')
ax.set_yscale('log')
legend(ax, fontsize=7)

# ── 7c: Empty cells at k=729 vs N ──
ax = fig.add_subplot(gs[1, 0])
style_ax(ax, 'Empty Cell Count vs N  (k=729)', 'N', 'Empty cells')
c729_ck = ckpts[ckpts['k'] == 729]
ax.semilogx(c729_ck['checkpoint_N'], c729_ck['empty'], 'o-',
             color=PURPLE, ms=3, lw=1.2)
ax.axhline(c729_ck['empty'].iloc[-1], color=PINK, ls=':', lw=1,
           alpha=0.6, label=f'Final: {c729_ck["empty"].iloc[-1]:,}')
legend(ax)

# ── 7d: Pure-even and pure-odd counts vs N ──
ax = fig.add_subplot(gs[1, 1])
style_ax(ax, 'Pure-Even & Pure-Odd Convergence  (k=216)', 'N', 'Cell count')
ax.semilogx(c216_ck['checkpoint_N'], c216_ck['pure_even'], 'o-',
             color=CYAN, ms=3, lw=1.2, label='Pure even')
ax.semilogx(c216_ck['checkpoint_N'], c216_ck['pure_odd'], 's-',
             color=PINK, ms=3, lw=1.2, label='Pure odd')
legend(ax)

savefig(fig, 'branch_locus_fig7.png')

# ═════════════════════════════════════════════════════════════════════
print(f"\nAll 7 figures saved to {OUT}/")
print(f"Total time: {time.time()-t0:.1f}s")
