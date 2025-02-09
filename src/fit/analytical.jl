# Solvers corresponding to solving a closed-form expression

"""
$SIGNATURES

Fit a least square regression either with no penalty (OLS) or with a L2 penalty
(Ridge).

## Complexity

Assuming `n` dominates `p`,

* non-iterative (full solve):     O(np²) - dominated by the construction of the
                                  Hessian X'X.
* iterative (conjugate gradient): O(κnp) - with κ the number of CG steps
                                  (κ ≤ p).
"""
function _fit(::Type{T}, glr::GLR{L2Loss,<:L2R}, solver::Analytical, X, y, scratch) where {T<:Real}
    # full solve
    if !solver.iterative
        λ  = get_penalty_scale(glr, length(y))
        if iszero(λ)
            # standard LS solution
            return augment_X(T, X, glr.fit_intercept) \ y
        else
            # Ridge case -- form the Hat Matrix then solve
            H = form_XtX(X, glr.fit_intercept, λ, glr.penalize_intercept)
            b = X'y
            glr.fit_intercept && (b = vcat(b, sum(y)))
            return cholesky!(H) \ b
        end
    end
    # Iterative case, note that there is no augmentation here
    # it is done implicitly in the application of the Hessian to
    # avoid copying X
    # The number of CG steps to convergence is at most `p`
    _,p,_ = npc(scratch)
    max_cg_steps = min(solver.max_inner, p)
    # Form the Hessian map, cost of application H*v is O(np)
    Hm = LinearMap(Hv!(glr, X, y, scratch), p;
                   ismutating=true, isposdef=true, issymmetric=true)
    b  = X'y
    glr.fit_intercept && (b = vcat(b, sum(y)))
    return cg(Hm, b; maxiter=max_cg_steps)
end

function _fit(glr::GLR{L2Loss,<:L2R}, solver::Analytical, X, y, scratch)
    return _fit(eltype(X), glr, solver, X, y, scratch)
end