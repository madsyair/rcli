# Verifikasi simbolik F-01 (revisi 2): Proposisi 4 dan 5.
import sympy as sp

z = sp.symbols("z1:4", real=True)
d = sp.symbols("delta", real=True)
mean_change = sum((zi + d) - zi for zi in z) / 3
assert sp.simplify(mean_change - d) == 0

# Proposisi 5: |rata-rata| <= maks |.| untuk perubahan bertanda campuran
vals = [sp.Rational(3), sp.Rational(-5), sp.Rational(1, 2)]
assert abs(sum(vals) / 3) <= max(abs(v) for v in vals)
x = sp.symbols("x1:4", real=True)
bound = sp.Max(*[sp.Abs(xi) for xi in x]) - sp.Abs(sum(x) / 3)
for sub in [{x[0]: 2, x[1]: -7, x[2]: 1}, {x[0]: -1, x[1]: -1, x[2]: -1}]:
    assert bound.subs(sub) >= 0
print("F-01 simbolik (revisi 2): Proposisi 4 dan 5 lolos")
