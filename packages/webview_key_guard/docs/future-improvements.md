# Future improvements from the isolated package audit

No confirmed important production defect is assigned to this list.

1. **Verification extension:** repeat the physical keyboard matrix on the
   reviewed revision, including actual held keys, focus changes, text editing,
   multiple windows, and native system dialogs. Synthetic native events and
   policy tests must remain distinct from physical input evidence.
2. **P3, host-specific compatibility:** custom `performKeyEquivalent` handlers
   in ancestors of the source WebView are outside the generic traversal
   guarantee. Add a consuming host's regression when such a handler is needed;
   avoid weakening source exclusion without a concrete case.
3. **P3, diagnostic precision:** DOM timestamps/chords are a diagnostic
   approximation for duplicate detection, whereas the package uses native
   object identity. Do not interpret timestamp collisions alone as proof of a
   package defect. Consider recording a native-to-DOM correlation only if a
   reproducible ambiguous case requires it.

The audit does not migrate the example's SDK, redesign historical strategies,
change consumers, or expand into a general application review.
