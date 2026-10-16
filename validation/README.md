# Auxiliary validation branch

This directory and its workflow are outside the proposed three-file PR. The code
to review is on `codex/filtered-svg-cache`, based on upstream commit
`50dcf832fa4e216521d75927ba51dda6e39b93d5`.

The harness compares cached and uncached exports from the same Krilla revision.
It covers repeated/mixed sizes, filters, compositing, a subpixel detail, three
existing #5509 fixtures, and upstream Matplotlib/draw.io integration assets.
All ten PDF pairs must be byte-identical. On macOS, a separate Swift program
compares Apple PDFKit page rendering at 144 dpi and saves PNGs and pixel hashes.

These checks establish equivalence on the tested inputs and OS versions. They do
not establish correctness against an independent SVG oracle, test the Preview
application UI, or reproduce the unavailable #7657 thesis source. The real-world
SVG assets are controls, not a supplied real user's complete Typst document.

Historical Typst timings are in `prior-typst-evidence`. They used the pinned old
Typst/Krilla revisions listed there, not this current-main build. The measured
twelve-page repeated-filter case was 1.070 s to 0.132 s, about 8.08x, with embedded
fonts, warm filesystem caches, and ten alternating runs per binary. This does not
mean all Typst compilation is faster.

The implementation and this validation preparation were AI-authored. No upstream
PR has been submitted. Typst's separate contribution rules must be respected for
any later Typst integration.
