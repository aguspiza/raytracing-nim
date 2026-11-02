# no runtime checks, and defects abort instead of raising: without
# --panics:on every call is followed by a check of the error flag
switch("define", "danger")
switch("panics", "on")
switch("passC", "-march=native")
