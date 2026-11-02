# AmazeCC campus schedule fallback

Public JSON schedules copied from AmazeContinuityProjects/AmazeCC,
`public/data/laundry` and `public/data/mess`, as an offline fallback:
https://github.com/AmazeContinuityProjects/AmazeCC

AmazeCC is GPL-3.0; see the repository's LICENSE. Schedule data is provided by
unmessify: https://kanishka-developer.github.io/unmessify/

With explicit live-schedule opt-in, the helper first tries the same public unmessify URLs used by AmazeCC. It keeps
successful responses by resource, preserving their fetch time if refresh fails.
Bundled copies retain the original Published date and are labelled offline in
the UI. A laundry Date is a recurring day of the month, not an absolute date.
No room number, VTOP cookie or credential is sent to unmessify.
