#!/usr/bin/env python3
"""Turn electrical quantities into man-hours, crew-days and headcount.

Usage:
  python3 estimate.py quantities.csv --days 120 [--hours 8] [--efficiency 0.85]
                      [--rates ../references/productivity-rates.md] [--crew-size 2]

quantities.csv columns: code,description,qty,phase,factor
  - code   : a code from productivity-rates.md (e.g. CBL-LV-185)
  - factor : correction multiplier (height, heat, Ramadan...), default 1.0
Output: per-item man-hours, per-phase totals, and the workers needed to finish
in --days working days. Rates come from the markdown tables in productivity-rates.md.
"""
import argparse
import csv
import math
import re
import sys
from collections import OrderedDict
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_RATES = HERE.parent / "references" / "productivity-rates.md"
ROW = re.compile(r"^\|\s*([A-Z][A-Z0-9.\-]+)\s*\|(.+)\|\s*$")


def load_rates(path):
    rates = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        m = ROW.match(line.strip())
        if not m:
            continue
        cells = [c.strip() for c in m.group(2).split("|")]
        num = re.match(r"[0-9.]+", cells[-1])
        if num:
            rates[m.group(1)] = (cells[0], float(num.group()))
    return rates


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("quantities")
    ap.add_argument("--days", type=float, required=True, help="working days available")
    ap.add_argument("--hours", type=float, default=8.0, help="hours per day (6 in Ramadan)")
    ap.add_argument("--efficiency", type=float, default=0.85)
    ap.add_argument("--crew-size", type=int, default=2, help="workers per crew (technician + helper = 2)")
    ap.add_argument("--rates", default=str(DEFAULT_RATES))
    a = ap.parse_args()

    rates = load_rates(a.rates)
    phases = OrderedDict()
    missing = []
    total = 0.0
    print(f"{'code':<12}{'qty':>10}{'mh/unit':>9}{'factor':>8}{'man-hours':>12}  phase")
    with open(a.quantities, newline="", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            code = r["code"].strip()
            qty = float(r["qty"] or 0)
            factor = float(r.get("factor") or 1.0)
            phase = (r.get("phase") or "General").strip()
            if code not in rates:
                missing.append(code)
                continue
            mh = qty * rates[code][1] * factor
            total += mh
            phases[phase] = phases.get(phase, 0.0) + mh
            print(f"{code:<12}{qty:>10,.0f}{rates[code][1]:>9.3f}{factor:>8.2f}{mh:>12,.1f}  {phase}")

    eff_hours = a.hours * a.efficiency
    print("\nPer phase:")
    for p, mh in phases.items():
        print(f"  {p:<16}{mh:>10,.0f} mh  = {mh / eff_hours:>7,.1f} worker-days")

    worker_days = total / eff_hours
    workers = math.ceil(worker_days / a.days)
    crews = math.ceil(workers / a.crew_size)
    print(f"\nTotal man-hours          : {total:,.0f}")
    print(f"Worker-days (@{eff_hours:.1f} h net): {worker_days:,.0f}")
    print(f"Average workers for {a.days:.0f} days: {workers}  (~{crews} crews of {a.crew_size})")
    print(f"Peak workers (x1.4 avg)  : {math.ceil(workers * 1.4)}")
    print(f"Foremen (1/12 workers)   : {max(1, math.ceil(workers * 1.4 / 12))}")
    print(f"Site engineers (1/30)    : {max(1, math.ceil(workers * 1.4 / 30))}")
    print("\nNote: rates are indicative starting values; replace with your own site data.")
    if missing:
        print(f"WARNING: no rate for codes: {', '.join(sorted(set(missing)))}", file=sys.stderr)


if __name__ == "__main__":
    main()
