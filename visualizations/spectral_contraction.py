#!/usr/bin/env python3
"""
spectral_contraction.py — Visualize the Furstenberg ×2,×3 spectral contraction

Shows how alternating T₃ (tripling transfer operator) and T₂ (doubling map)
drives ANY probability density toward Lebesgue measure (uniform).

The key insight: T₃ contracts non-uniform Fourier modes by factor 1/3
(spectral gap = 2/3), while T₂ merely rearranges them. The contraction wins.

Two starting densities:
  - Bumpy: a smooth mixture of 4 Gaussian bumps
  - Sharp spike: a very narrow peak at x=0

Both converge to uniform, illustrating that Lebesgue is the universal attractor
for densities under the joint T₂+T₃ action. The only other invariant object
is δ₀ (a true point mass, which can't be represented as a density).

Outputs:
  spectral_contraction.gif — animated GIF of the convergence
  spectral_contraction.html — interactive HTML with playback controls
"""

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
import matplotlib.animation as animation
import os

# ─── Operators on discretized densities ──────────────────────────────

def apply_T3(f):
    """Transfer operator for x ↦ 3x mod 1.
    (T₃f)(x) = (1/3) Σ_{k=0}^{2} f((x+k)/3)
    Each point has 3 preimages under ×3: (x+0)/3, (x+1)/3, (x+2)/3."""
    N = len(f)
    g = np.zeros(N)
    for k in range(3):
        preimage = (np.arange(N) + k * N) / 3.0
        preimage_idx = preimage % N
        lo = np.floor(preimage_idx).astype(int) % N
        hi = (lo + 1) % N
        frac = preimage_idx - np.floor(preimage_idx)
        g += (1.0/3.0) * ((1 - frac) * f[lo] + frac * f[hi])
    return g

def apply_T2(f):
    """Transfer operator for x ↦ 2x mod 1.
    (T₂f)(x) = (1/2)[f(x/2) + f((x+1)/2)]"""
    N = len(f)
    g = np.zeros(N)
    for k in range(2):
        preimage = (np.arange(N) + k * N) / 2.0
        preimage_idx = preimage % N
        lo = np.floor(preimage_idx).astype(int) % N
        hi = (lo + 1) % N
        frac = preimage_idx - np.floor(preimage_idx)
        g += 0.5 * ((1 - frac) * f[lo] + frac * f[hi])
    return g

# ─── Initial densities ──────────────────────────────────────────────

def bumpy_density(N):
    """A lumpy probability density: mixture of 4 Gaussian bumps."""
    x = np.linspace(0, 1, N, endpoint=False)
    f = np.ones(N) * 0.3

    centers = [0.15, 0.42, 0.67, 0.88]
    widths  = [0.04, 0.06, 0.03, 0.05]
    heights = [3.0, 2.0, 4.0, 1.5]

    for c, w, h in zip(centers, widths, heights):
        f += h * np.exp(-0.5 * ((x - c) / w) ** 2)

    f *= N / np.sum(f)
    return f

def sharp_spike(N, center=0.0, width=0.008):
    """Very narrow Gaussian spike at center.
    Note: a true δ₀ (point mass) IS a fixed point, but can't be a density.
    Any density, no matter how sharp, converges to Lebesgue."""
    x = np.linspace(0, 1, N, endpoint=False)
    f = np.zeros(N)
    for k in range(-3, 4):
        f += np.exp(-0.5 * ((x - center - k) / width) ** 2)
    f *= N / np.sum(f)
    return f

# ─── Compute all frames ─────────────────────────────────────────────

def compute_evolution(f0, n_steps=15):
    """Alternately apply T₃ then T₂, recording each intermediate."""
    frames = [('Initial', f0.copy())]
    f = f0.copy()
    for i in range(n_steps):
        f = apply_T3(f)
        frames.append((f'Step {i+1}: after T\u2083', f.copy()))
        f = apply_T2(f)
        frames.append((f'Step {i+1}: after T\u2082', f.copy()))
    return frames

def l2_deviation(f):
    """||f - 1||_{L²}"""
    return np.sqrt(np.sum((f - 1.0) ** 2) / len(f))

# ─── Generate GIF ───────────────────────────────────────────────────

def make_gif(outpath, n_steps=12, N=2048):
    """Create the spectral contraction animated GIF."""
    print("Computing evolution (bumpy density)...")
    f0_bumpy = bumpy_density(N)
    frames_bumpy = compute_evolution(f0_bumpy, n_steps)

    print("Computing evolution (sharp spike)...")
    f0_spike = sharp_spike(N, center=0.0, width=0.008)
    frames_spike = compute_evolution(f0_spike, n_steps)

    x = np.linspace(0, 1, N, endpoint=False)

    # Collect L² norms at each FULL step (initial + after each T₂)
    l2_bumpy = [l2_deviation(frames_bumpy[0][1])]
    l2_spike = [l2_deviation(frames_spike[0][1])]
    for i in range(2, len(frames_bumpy), 2):
        l2_bumpy.append(l2_deviation(frames_bumpy[i][1]))
        l2_spike.append(l2_deviation(frames_spike[i][1]))

    fig = plt.figure(figsize=(14, 8), facecolor='#1a1a2e')
    gs = GridSpec(2, 3, width_ratios=[3, 3, 2], hspace=0.35, wspace=0.3,
                  left=0.06, right=0.96, top=0.92, bottom=0.08)

    ax_bumpy = fig.add_subplot(gs[0, 0:2])
    ax_spike = fig.add_subplot(gs[1, 0:2])
    ax_l2 = fig.add_subplot(gs[0, 2])
    ax_info = fig.add_subplot(gs[1, 2])

    c_fill_bumpy = '#e94560'
    c_fill_spike = '#53d8fb'
    c_uniform = '#f0c040'

    fig.suptitle('Furstenberg \u00d72,\u00d73 \u2014 Spectral Contraction',
                 fontsize=16, color='#e94560', fontweight='bold')

    total_frames = len(frames_bumpy)

    def setup_axes():
        for ax in [ax_bumpy, ax_spike, ax_l2]:
            ax.set_facecolor('#16213e')
            ax.tick_params(colors='#e0e0e0', labelsize=8)
            for spine in ax.spines.values():
                spine.set_color('#333366')
        ax_info.set_facecolor('#1a1a2e')
        ax_info.axis('off')

    def animate(frame_idx):
        ax_bumpy.clear(); ax_spike.clear(); ax_l2.clear(); ax_info.clear()
        setup_axes()

        label_b, fb = frames_bumpy[frame_idx]
        label_s, fs = frames_spike[frame_idx]

        step = max(1, N // 1024)
        xs = x[::step]
        fb_s = fb[::step]
        fs_s = fs[::step]

        # ── Top: bumpy density ──
        ax_bumpy.fill_between(xs, 0, fb_s, alpha=0.6, color=c_fill_bumpy)
        ax_bumpy.plot(xs, fb_s, color='white', linewidth=0.8, alpha=0.9)
        ax_bumpy.axhline(1.0, color=c_uniform, linewidth=1, linestyle='--', alpha=0.7)
        ax_bumpy.set_xlim(0, 1)
        ax_bumpy.set_ylim(0, max(np.max(fb_s) * 1.1, 2.0))
        ax_bumpy.set_ylabel('f(x)', color='#e0e0e0', fontsize=10)
        ax_bumpy.set_title(f'Bumpy density \u2014 {label_b}', color=c_fill_bumpy,
                          fontsize=11, fontweight='bold')

        # ── Bottom: sharp spike ──
        ax_spike.fill_between(xs, 0, fs_s, alpha=0.6, color=c_fill_spike)
        ax_spike.plot(xs, fs_s, color='white', linewidth=0.8, alpha=0.9)
        ax_spike.axhline(1.0, color=c_uniform, linewidth=1, linestyle='--', alpha=0.7)
        ax_spike.set_xlim(0, 1)
        ax_spike.set_ylim(0, max(np.max(fs_s) * 1.1, 2.0))
        ax_spike.set_xlabel('x \u2208 [0,1)', color='#e0e0e0', fontsize=10)
        ax_spike.set_ylabel('f(x)', color='#e0e0e0', fontsize=10)
        ax_spike.set_title(f'Sharp spike \u2014 {label_s}', color=c_fill_spike,
                          fontsize=11, fontweight='bold')

        # ── Right: L² convergence ──
        step_idx = frame_idx // 2
        steps_so_far = list(range(step_idx + 1))

        ax_l2.semilogy(steps_so_far, l2_bumpy[:step_idx+1], 'o-',
                       color=c_fill_bumpy, markersize=4, linewidth=1.5, label='Bumpy')
        ax_l2.semilogy(steps_so_far, l2_spike[:step_idx+1], 's-',
                       color=c_fill_spike, markersize=4, linewidth=1.5, label='Spike')

        nn = np.arange(0, n_steps + 1)
        ref = l2_bumpy[0] * (1.0/3.0) ** nn
        ax_l2.semilogy(nn, ref, '--', color=c_uniform, linewidth=1,
                       alpha=0.6, label='(1/3)\u207f ref')

        ax_l2.set_xlim(-0.5, n_steps + 0.5)
        ax_l2.set_ylim(1e-8, max(l2_bumpy[0], l2_spike[0]) * 3)
        ax_l2.set_xlabel('Step n', color='#e0e0e0', fontsize=9)
        ax_l2.set_ylabel('\u2016f \u2212 1\u2016\u2082', color='#e0e0e0', fontsize=9)
        ax_l2.set_title('L\u00b2 Deviation', color='#e0e0e0', fontsize=10)
        ax_l2.legend(fontsize=7, loc='upper right', facecolor='#16213e',
                    edgecolor='#333366', labelcolor='#e0e0e0')

        # ── Info panel ──
        is_T3 = (frame_idx > 0) and (frame_idx % 2 == 1)
        op = 'T\u2083 (\u00d73 transfer)' if is_T3 else ('T\u2082 (\u00d72 transfer)' if frame_idx > 0 else '\u2014')

        info = (
            f"Frame: {frame_idx}/{total_frames - 1}\n"
            f"Operator: {op}\n\n"
            f"Bumpy \u2016f\u22121\u2016\u2082: {l2_deviation(fb):.2e}\n"
            f"Spike \u2016f\u22121\u2016\u2082: {l2_deviation(fs):.2e}\n\n"
            f"\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\n"
            f"Spectral gap: 2/3\n"
            f"T\u2083 contracts by 1/3\n"
            f"T\u2082 rearranges only\n\n"
            f"Any density \u2192 Lebesgue\n"
            f"Only exception: \u03b4\u2080\n"
            f"(true point mass)"
        )
        ax_info.text(0.05, 0.95, info, transform=ax_info.transAxes,
                    fontsize=9, color='#e0e0e0', fontfamily='monospace',
                    verticalalignment='top')
        return []

    print(f"Generating {total_frames} frames...")
    frame_order = []
    for i in range(total_frames):
        frame_order.append(i)
        if i == 0 or (i > 0 and i % 2 == 1):
            frame_order.append(i)

    anim = animation.FuncAnimation(fig, animate, frames=frame_order,
                                   interval=400, blit=True, repeat=True)

    print(f"Saving GIF to {outpath}...")
    anim.save(outpath, writer='pillow', fps=2.5, dpi=100)
    print(f"  Saved: {outpath} ({os.path.getsize(outpath)/1e6:.1f} MB)")
    plt.close()

# ─── Generate HTML ──────────────────────────────────────────────────

def make_html(outpath, n_steps=12, N=2048):
    """Create interactive HTML with frame-by-frame playback."""
    import json

    print("Computing frames for HTML...")
    f0_bumpy = bumpy_density(N)
    frames_bumpy = compute_evolution(f0_bumpy, n_steps)

    f0_spike = sharp_spike(N, center=0.0, width=0.008)
    frames_spike = compute_evolution(f0_spike, n_steps)

    step = max(1, N // 512)
    x_arr = np.linspace(0, 1, N, endpoint=False)[::step].tolist()

    frames_json = []
    for i in range(len(frames_bumpy)):
        label, fb = frames_bumpy[i]
        _, fs = frames_spike[i]
        is_T3 = (i > 0) and (i % 2 == 1)
        frames_json.append({
            'label': label,
            'bumpy': fb[::step].tolist(),
            'spike': fs[::step].tolist(),
            'l2b': float(l2_deviation(fb)),
            'l2s': float(l2_deviation(fs)),
            'op': '\u2009T\u2083' if is_T3 else ('\u2009T\u2082' if i > 0 else '\u2014'),
        })

    frames_str = json.dumps(frames_json)
    x_str = json.dumps(x_arr)

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Furstenberg \u00d72,\u00d73 \u2014 Spectral Contraction</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ background: #1a1a2e; color: #e0e0e0; font-family: 'Courier New', monospace; }}
  h1 {{ text-align: center; padding: 15px; color: #e94560; font-size: 1.4em; }}
  .container {{ display: flex; flex-wrap: wrap; justify-content: center; gap: 15px; padding: 0 15px; }}
  canvas {{ border: 1px solid #333366; border-radius: 4px; background: #16213e; }}
  .panel {{ display: flex; flex-direction: column; align-items: center; }}
  .panel h3 {{ margin-bottom: 5px; font-size: 0.95em; }}
  .controls {{ text-align: center; padding: 15px; }}
  .controls button {{ background: #0f3460; color: #e0e0e0; border: 1px solid #333366;
    padding: 8px 18px; margin: 0 5px; cursor: pointer; border-radius: 4px; font-size: 0.9em; }}
  .controls button:hover {{ background: #e94560; }}
  .controls button.active {{ background: #e94560; }}
  .info {{ text-align: center; padding: 5px; font-size: 0.85em; color: #aaa; }}
  .info span {{ color: #e94560; font-weight: bold; }}
  #slider {{ width: 400px; margin: 10px; accent-color: #e94560; }}
  .note {{ text-align: center; padding: 12px 20px; font-size: 0.82em; color: #888;
    max-width: 900px; margin: 0 auto; line-height: 1.5; }}
  .note em {{ color: #f0c040; font-style: normal; }}
</style>
</head>
<body>
<h1>Furstenberg \u00d72,\u00d73 \u2014 Spectral Contraction</h1>

<div class="controls">
  <button onclick="prevFrame()">\u23ee Prev</button>
  <button id="btnPlay" onclick="togglePlay()">\u25b6 Play</button>
  <button onclick="nextFrame()">Next \u23ed</button>
  <button onclick="resetAnim()">\u21ba Reset</button>
  <br>
  <input type="range" id="slider" min="0" max="0" value="0" oninput="seekFrame(this.value)">
</div>

<div class="info">
  Frame <span id="frameNum">0</span>/<span id="frameTotal">0</span> \u2014
  <span id="opLabel">\u2014</span> \u2014
  <span id="stepLabel">Initial</span>
</div>

<div class="container">
  <div class="panel">
    <h3 style="color:#e94560">Bumpy Density \u2192 Lebesgue</h3>
    <canvas id="cvBumpy" width="520" height="280"></canvas>
  </div>
  <div class="panel">
    <h3 style="color:#53d8fb">Sharp Spike \u2192 Lebesgue</h3>
    <canvas id="cvSpike" width="520" height="280"></canvas>
  </div>
  <div class="panel">
    <h3 style="color:#f0c040">L\u00b2 Deviation (log scale)</h3>
    <canvas id="cvL2" width="320" height="280"></canvas>
  </div>
</div>

<div class="note">
  T\u2083 contracts all non-uniform Fourier modes by factor 1/3 (<em>spectral gap = 2/3</em>).<br>
  T\u2082 rearranges modes but cannot amplify. The contraction wins: <em>any density \u2192 Lebesgue</em>.<br>
  The only other jointly invariant measure is \u03b4\u2080 (a true point mass, not representable as a density).
</div>

<script>
const frames = {frames_str};
const xArr = {x_str};
const M = xArr.length;
const totalFrames = frames.length;

let currentFrame = 0, playing = false, timer = null;
document.getElementById('slider').max = totalFrames - 1;
document.getElementById('frameTotal').textContent = totalFrames - 1;

function drawDensity(canvasId, data, fillColor, maxY) {{
  const cv = document.getElementById(canvasId);
  const ctx = cv.getContext('2d');
  const W = cv.width, H = cv.height;
  const pad = {{l:45, r:10, t:10, b:25}};
  const pw = W - pad.l - pad.r, ph = H - pad.t - pad.b;
  ctx.clearRect(0, 0, W, H);

  ctx.strokeStyle = '#333366'; ctx.lineWidth = 0.5;
  for (let y = 0; y <= maxY; y += Math.max(1, Math.floor(maxY/5))) {{
    let py = pad.t + ph * (1 - y/maxY);
    ctx.beginPath(); ctx.moveTo(pad.l, py); ctx.lineTo(pad.l+pw, py); ctx.stroke();
    ctx.fillStyle = '#888'; ctx.font = '10px monospace';
    ctx.fillText(y.toFixed(0), 5, py+3);
  }}

  let uy = pad.t + ph * (1 - 1.0/maxY);
  ctx.strokeStyle = '#f0c040'; ctx.lineWidth = 1.5; ctx.setLineDash([5,3]);
  ctx.beginPath(); ctx.moveTo(pad.l, uy); ctx.lineTo(pad.l+pw, uy); ctx.stroke();
  ctx.setLineDash([]);

  ctx.beginPath(); ctx.moveTo(pad.l, pad.t + ph);
  for (let i = 0; i < M; i++) {{
    let px = pad.l + (i/(M-1)) * pw;
    let py = pad.t + ph * (1 - Math.min(data[i], maxY)/maxY);
    ctx.lineTo(px, py);
  }}
  ctx.lineTo(pad.l + pw, pad.t + ph); ctx.closePath();
  ctx.fillStyle = fillColor + '99'; ctx.fill();

  ctx.beginPath();
  for (let i = 0; i < M; i++) {{
    let px = pad.l + (i/(M-1)) * pw;
    let py = pad.t + ph * (1 - Math.min(data[i], maxY)/maxY);
    if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
  }}
  ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 1; ctx.stroke();

  ctx.fillStyle = '#888'; ctx.font = '10px monospace';
  ctx.fillText('0', pad.l-3, pad.t+ph+12);
  ctx.fillText('1', pad.l+pw-5, pad.t+ph+12);
}}

function drawL2(frameIdx) {{
  const cv = document.getElementById('cvL2');
  const ctx = cv.getContext('2d');
  const W = cv.width, H = cv.height;
  const pad = {{l:55, r:10, t:10, b:25}};
  const pw = W - pad.l - pad.r, ph = H - pad.t - pad.b;
  ctx.clearRect(0, 0, W, H);

  let l2b = [frames[0].l2b], l2s = [frames[0].l2s];
  let nSteps = (totalFrames - 1) / 2;
  for (let i = 2; i < totalFrames; i += 2) {{ l2b.push(frames[i].l2b); l2s.push(frames[i].l2s); }}

  let maxVal = Math.max(l2b[0], l2s[0]) * 2, minVal = 1e-8;
  let logMax = Math.log10(maxVal), logMin = Math.log10(minVal);
  function toY(v) {{ return pad.t + ph * (1 - (Math.log10(Math.max(v, minVal)) - logMin)/(logMax - logMin)); }}

  ctx.strokeStyle = '#333366'; ctx.lineWidth = 0.5;
  ctx.fillStyle = '#888'; ctx.font = '10px monospace';
  for (let e = Math.ceil(logMin); e <= Math.floor(logMax); e++) {{
    let y = toY(Math.pow(10, e));
    ctx.beginPath(); ctx.moveTo(pad.l, y); ctx.lineTo(pad.l+pw, y); ctx.stroke();
    ctx.fillText('10^' + e, 5, y+3);
  }}

  let stepNow = Math.floor(frameIdx / 2);

  ctx.strokeStyle = '#f0c040'; ctx.lineWidth = 1; ctx.setLineDash([4,3]);
  ctx.beginPath();
  for (let i = 0; i <= nSteps; i++) {{
    let px = pad.l + (i/nSteps) * pw, py = toY(l2b[0] * Math.pow(1/3, i));
    if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
  }}
  ctx.stroke(); ctx.setLineDash([]);

  function drawSeries(data, color, n) {{
    ctx.beginPath(); ctx.strokeStyle = color; ctx.lineWidth = 2;
    for (let i = 0; i <= Math.min(n, data.length-1); i++) {{
      let px = pad.l + (i/nSteps) * pw, py = toY(data[i]);
      if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    }}
    ctx.stroke();
    ctx.fillStyle = color;
    for (let i = 0; i <= Math.min(n, data.length-1); i++) {{
      let px = pad.l + (i/nSteps) * pw, py = toY(data[i]);
      ctx.beginPath(); ctx.arc(px, py, 3, 0, 2*Math.PI); ctx.fill();
    }}
  }}
  drawSeries(l2b, '#e94560', stepNow);
  drawSeries(l2s, '#53d8fb', stepNow);

  ctx.fillStyle = '#e94560'; ctx.fillRect(pad.l+5, pad.t+5, 12, 3);
  ctx.fillStyle = '#e0e0e0'; ctx.font = '9px monospace'; ctx.fillText('Bumpy', pad.l+20, pad.t+10);
  ctx.fillStyle = '#53d8fb'; ctx.fillRect(pad.l+5, pad.t+17, 12, 3);
  ctx.fillStyle = '#e0e0e0'; ctx.fillText('Spike', pad.l+20, pad.t+22);
  ctx.fillStyle = '#f0c040'; ctx.fillRect(pad.l+5, pad.t+29, 12, 3);
  ctx.fillStyle = '#e0e0e0'; ctx.fillText('(1/3)\u207f', pad.l+20, pad.t+34);
}}

function renderFrame(idx) {{
  const f = frames[idx];
  let maxB = Math.max(...f.bumpy) * 1.15, maxS = Math.max(...f.spike) * 1.15;
  drawDensity('cvBumpy', f.bumpy, '#e94560', Math.max(maxB, 2.0));
  drawDensity('cvSpike', f.spike, '#53d8fb', Math.max(maxS, 2.0));
  drawL2(idx);
  document.getElementById('frameNum').textContent = idx;
  document.getElementById('opLabel').textContent = f.op;
  document.getElementById('stepLabel').textContent = f.label;
  document.getElementById('slider').value = idx;
}}

function nextFrame() {{ currentFrame = Math.min(currentFrame + 1, totalFrames - 1); renderFrame(currentFrame); }}
function prevFrame() {{ currentFrame = Math.max(currentFrame - 1, 0); renderFrame(currentFrame); }}
function seekFrame(v) {{ currentFrame = parseInt(v); renderFrame(currentFrame); }}
function togglePlay() {{
  playing = !playing;
  document.getElementById('btnPlay').textContent = playing ? '\u23f8 Pause' : '\u25b6 Play';
  document.getElementById('btnPlay').classList.toggle('active', playing);
  if (playing) {{
    timer = setInterval(() => {{
      currentFrame = currentFrame >= totalFrames - 1 ? 0 : currentFrame + 1;
      renderFrame(currentFrame);
    }}, 500);
  }} else clearInterval(timer);
}}
function resetAnim() {{
  playing = false; clearInterval(timer);
  document.getElementById('btnPlay').textContent = '\u25b6 Play';
  document.getElementById('btnPlay').classList.remove('active');
  currentFrame = 0; renderFrame(0);
}}
renderFrame(0);
</script>
</body>
</html>"""

    with open(outpath, 'w') as fh:
        fh.write(html)
    print(f"  Saved: {outpath} ({os.path.getsize(outpath)/1e3:.0f} KB)")

# ─── Main ───────────────────────────────────────────────────────────

if __name__ == '__main__':
    outdir = os.path.dirname(os.path.abspath(__file__))

    # GIF only — the HTML is now a standalone interactive lab
    # (spectral_contraction.html, no Python generation needed)
    make_gif(os.path.join(outdir, 'spectral_contraction.gif'),
             n_steps=12, N=2048)

    print("\nDone!")
