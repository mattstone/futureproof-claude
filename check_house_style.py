#!/usr/bin/env python3
"""
FutureProof EPM document checker — the distribution guardrail.

Scans every EPM PDF for the recurring error classes that keep needing manual fixes:
stale (buggy-engine) numbers, retracted cross-subsidy claims, impossible portfolio-PoC
figures, forbidden terminology, house-style (brand/spelling), and known typos.

Run before distributing ANY doc:   python3 check_house_style.py
It needs `pdftotext` on PATH (poppler). Exit code is non-zero if any HIGH issue is found,
so it can gate a build. Add new rules to CHECKS as new recurring mistakes appear.
"""
import os, re, subprocess, sys, glob

ROOT = os.path.dirname(os.path.abspath(__file__))
SCAN_DIRS = ['docs/pdfs', 'docs/pdfs/Final versions']   # live sets only; deprecated/ is ignored

# Source-of-truth (Pavel's xlsm, v14d Optimised base case) — for reference in messages
TRUTH = "xlsm: PoD/LMI-PoC 8.37%, reins PoC 1.67%, LMI $10,168/$15,253, tail $1,827, severity $143,274"

# (category, severity, kind, pattern, message)
#   kind: 'rx' regex (case-insensitive), 'rxcs' regex (case-sensitive), 'word' whole-word (ci)
CHECKS = [
 ("Stale number",   "HIGH", "rx",   r"5\.55\s*%",                 "buggy-engine PoD 5.55% — correct is 8.37%"),
 ("Stale number",   "HIGH", "word", r"300,485",                   "buggy-engine severity $300,485 — correct is $143,274"),
 ("Stale number",   "HIGH", "word", r"7,251",                     "buggy-engine LMI premium $7,251 — correct is $10,168"),
 ("Stale number",   "HIGH", "word", r"10,877",                    "buggy-engine loaded premium $10,877 — correct is $15,253"),
 ("Stale severity", "HIGH", "rx",   r"20\s*[–-]\s*25\s*%",   "stale loss severity 20-25% — correct is ~10-12%"),
 ("Retracted claim","HIGH", "rx",   r"\b109\s*:\s*1\b",           "retracted cross-subsidy ratio 109:1"),
 ("Retracted claim","HIGH", "rx",   r"near[\s-]complete",         "retracted 'near-complete cross-subsidisation'"),
 ("Retracted claim","HIGH", "rx",   r"<\s*0\.01\s*%",             "retracted portfolio PoC '<0.01%'"),
 ("Impossible PoC", "HIGH", "rx",   r"portfolio[^.\n]{0,70}?reinsurance[^.\n]{0,30}?(PoC|claim)[^.\n]{0,18}?\b[2-9](\.\d+)?\s*%",
                                     "portfolio reinsurance PoC stated ABOVE the 1.67% per-mortgage ceiling (impossible)"),
 ("Terminology",    "HIGH", "rx",   r"mortgage[\s-]based loan",   "product called a 'loan' — use 'mortgage'/'EPM'"),
 ("Terminology",    "HIGH", "word", r"robo\w*",                   "forbidden 'robo' terminology"),
 ("Terminology",    "MED",  "word", r"arrears",                   "'arrears' is meaningless for EPM (no borrower payments)"),
 ("Brand",          "MED",  "rxcs", r"Futureproof",              "brand casing 'Futureproof' — house style is 'FutureProof'"),
 ("Spelling",       "MED",  "rxcs", r"Optimized",                "US spelling 'Optimized' — house style is 'Optimised'"),
 ("Typo",           "MED",  "word", r"imitations",               "typo 'imitations' -> 'Limitations'"),
 ("Typo",           "MED",  "word", r"Bronwian",                 "typo 'Bronwian' -> 'Brownian'"),
 ("Typo",           "MED",  "word", r"Sotchastic",               "typo 'Sotchastic' -> 'Stochastic'"),
 ("Typo",           "MED",  "word", r"Pre-mortgage",             "typo 'Pre-mortgage' -> 'Per-mortgage'"),
 # INFO: legitimate sometimes — surfaced for a human eyeball, never fails the build
 ("Check context",  "INFO", "rx",   r"1\.11\s*%",                "1.11% — was the stale reins PoC; OK if it's a surplus $ or other metric"),
 ("Check context",  "INFO", "rx",   r"100\s*[x×]",          "'100x' — OK if a valuation multiple; NOT a cross-subsidy reduction"),
]

def text_of(pdf):
    try:
        return subprocess.run(["pdftotext", "-layout", pdf, "-"], capture_output=True, text=True, timeout=60).stdout
    except Exception as e:
        return ""

def find(kind, pat, text):
    if kind == "word": rx = re.compile(r"(?<!\w)(" + pat + r")(?!\w)", re.I)
    elif kind == "rxcs": rx = re.compile(pat)
    else: rx = re.compile(pat, re.I)
    out = []
    for m in rx.finditer(text):
        s = max(0, m.start()-45); e = min(len(text), m.end()+45)
        out.append(re.sub(r"\s+", " ", text[s:e]).strip())
    return out

def main():
    pdfs = []
    for d in SCAN_DIRS:
        pdfs += sorted(glob.glob(os.path.join(ROOT, d, "*.pdf")))
    high = 0
    print(f"FutureProof EPM document check — {len(pdfs)} live PDFs\nTruth = {TRUTH}\n" + "="*78)
    for pdf in pdfs:
        name = os.path.basename(pdf)
        text = text_of(pdf)
        issues = []
        for cat, sev, kind, pat, msg in CHECKS:
            hits = find(kind, pat, text)
            if hits:
                issues.append((sev, cat, msg, len(hits), hits[0]))
        order = {"HIGH":0, "MED":1, "INFO":2}
        issues.sort(key=lambda x: order[x[0]])
        if not issues:
            print(f"\n✅ {name}\n     clean")
            continue
        print(f"\n{'🔴' if any(i[0]=='HIGH' for i in issues) else '🟡'} {name}")
        for sev, cat, msg, n, eg in issues:
            if sev == "HIGH": high += 1
            tag = {"HIGH":"🔴 MUST FIX","MED":"🟡 polish  ","INFO":"⚪ check   "}[sev]
            print(f"     {tag} [{cat}] {msg}  (x{n})")
            print(f"                 e.g. “…{eg[:90]}…”")
    print("\n" + "="*78)
    print(f"{'🔴 ' if high else '✅ '}{high} must-fix issue type(s) across the set.")
    sys.exit(1 if high else 0)

if __name__ == "__main__":
    main()
