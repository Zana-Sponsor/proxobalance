# Measured geometry

Measurements are actual RenderBox bounds in logical dp at 393dp width, text scale 1, DPR3. The SVG box may be wider than the original artwork; `BoxFit.contain` preserves its aspect ratio.

| Element | Before (w × h) | After (w × h) |
|---|---|---|
| Auth logo | 132 × 38 | 84 × 24 |
| FIB logo envelope | 88 × 32 | 64 × 24 |
| Qi logo envelope | 88 × 32 | 64 × 24 |
| Logout SVG | 38 × 38 | 24 × 24 |
| Home navigation SVG | 48 × 32 | 24 × 24 |
| Receipt upload SVG | 52 × 52 | 24 × 24 |

## Provider row alignment

| Provider | Logo top (dp) | Logo box |
|---|---:|---|
| fib.svg | 123.9 | 64 × 24 |
| FastPay bitmap | 123.9 | 64 × 24 |
| qi.svg | 236.7 | 64 × 24 |
| zaincash.svg | 236.7 | 64 × 24 |
| asiacell.svg | 349.5 | 64 × 24 |
| korek.svg | 349.5 | 64 × 24 |

Every pair shares the same top position. Card labels also retain a common status-line slot, so a disabled-method message does not move its logo relative to its neighbour.

The [compressed raw register](raw-layout.json.gz) retains all 414 original JSON records: 117 frame/layout records and 90 lifecycle records per source, with zero captured exceptions. The matrix covers Sorani, Arabic and Badini at both viewport/text-scale configurations.
