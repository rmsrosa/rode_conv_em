# # Harvest model with compound Poisson process

using Plots
using Random
using Distributions

include("utils/tools.jl")

rng = Xoshiro(123)
t0 = 0.0
tf = 1.0
X0 = TruncatedNormal(1.0, 0.04, 0.2, 1.8)
f(x, y) = x - x^2 - y
λ = 10.0
R = Uniform(0.0, 0.1)
noise! = CompoundPoisson_noise(t0, tf, λ, R)
target! = solve_euler!

Ntgt = 2^16
Ns = 2 .^ (4:8)
M = 1_000

# plot(yy, linetype=:steppre)

@time deltas, errors, trajerrors, lc, p = calculate_errors(rng, t0, tf, X0, f, noise!, target!, Ntgt, Ns, M)

table = generate_error_table(Ns, deltas, errors)

println(table)

#include("utils.jl")
info = (
    equation = "\$\\mathrm{d}X_t/\\mathrm{d}t = X_t - X_t^2 - Y_t\$",
    noise = "a compound Poisson process noise \$\\{Y_t\\}_t\$",
    ic = "\$X_0 \\sim \\mathcal{N}(1.0, 0.01)\$",
    tspan="\$[0, T] = [$t0, $tf]\$"
)
filename = @__DIR__() * "/img/order_harvest.png"

plot_dt_vs_error(deltas, errors, lc, p, M; info, filename)

plot_t_vs_errors(deltas, trajerrors, t0, tf)

filename = @__DIR__() * "/img/harvest_sample.png"
plot_sample_approximations(rng, t0, tf, X0, f, noise!, target!, Ntgt, Ns; info, filename)

using BenchmarkTools

nsteps, deltas, trajerrors, Yt, Xt, XNt = prepare_variables(Ntgt, Ns)

@btime calculate_errors!($rng, $Yt, $Xt, $XNt, $X0, $f, $noise!, $target!, $trajerrors, $M, $t0, $tf, $Ns, $nsteps, $deltas)
