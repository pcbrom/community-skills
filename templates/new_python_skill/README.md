# Python skill template (placeholder)

The Python bridge (`bridges/python.py`) is not yet implemented. The design
will mirror `bridges/r.py`: spawn a Python interpreter, optionally inside a
per-skill virtualenv, and exchange JSON via stdin/stdout.

If you want to implement it, open an issue tagged `bridge:python` to align
on the API. Once the bridge lands, this template will receive a
`SKILL.md.template` and an `invoke.py.template` mirroring the R ones.
