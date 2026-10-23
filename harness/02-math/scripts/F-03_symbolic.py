"""F-03: symbolic check of the banded LDL^T recurrences of the HP system.

For n = 4..9 and symbolic lambda, A = I + lambda * D2' D2 is factored with the
recurrences of R/filters.R (hp_trend_core); the script checks
L D L^T == A exactly, that L keeps the lower bandwidth 2, and the
invariants 1'A = 1' and t'A = t' (so sum(trend) = sum(x) and
sum(t * trend) = sum(t * x)).
"""
import sympy as sp

lam = sp.symbols("lambda", positive=True)

for n in range(4, 10):
    D = sp.zeros(n - 2, n)
    for i in range(n - 2):
        D[i, i], D[i, i + 1], D[i, i + 2] = 1, -2, 1
    A = sp.eye(n) + lam * D.T * D
    # band entries as used in the package
    a0 = [1 + lam * c for c in [1, 5] + [6] * (n - 4) + [5, 1]]
    a1 = [lam * c for c in [-2] + [-4] * (n - 3) + [-2]]
    a2 = [lam] * (n - 2)
    assert all(sp.simplify(A[i, i] - a0[i]) == 0 for i in range(n))
    assert all(sp.simplify(A[i + 1, i] - a1[i]) == 0 for i in range(n - 1))
    assert all(sp.simplify(A[i + 2, i] - a2[i]) == 0 for i in range(n - 2))
    assert all(A[i + k, i] == 0 for k in range(3, n) for i in range(n - k))
    d = [0] * n
    l1 = [0] * (n + 1)  # l1[i] = L[i, i-1] (0-based i)
    l2 = [0] * (n + 2)  # l2[i] = L[i, i-2]
    for i in range(n):
        di = a0[i]
        if i > 0:
            di -= l1[i] ** 2 * d[i - 1]
        if i > 1:
            di -= l2[i] ** 2 * d[i - 2]
        d[i] = sp.simplify(di)
        if i < n - 1:
            num = a1[i] - (l2[i + 1] * l1[i] * d[i - 1] if i > 0 else 0)
            l1[i + 1] = sp.simplify(num / d[i])
        if i < n - 2:
            l2[i + 2] = sp.simplify(a2[i] / d[i])
    L = sp.eye(n)
    for i in range(1, n):
        L[i, i - 1] = l1[i]
    for i in range(2, n):
        L[i, i - 2] = l2[i]
    R = sp.simplify(L * sp.diag(*d) * L.T - A)
    assert R == sp.zeros(n, n), n
    # pivots are positive for lambda > 0 (checked at sample points)
    for v in [sp.Rational(1, 100), 1, 1600, 133108, 10**8]:
        assert all(sp.N(di.subs(lam, v)) > 0 for di in d)
    one = sp.ones(1, n)
    t = sp.Matrix([[i + 1 for i in range(n)]])
    assert sp.simplify(one * A - one) == sp.zeros(1, n)
    assert sp.simplify(t * A - t) == sp.zeros(1, n)
    print(f"n = {n}: L D L^T = A, bandwidth 2, invariants hold")
print("F-03 symbolic check: PASS")
