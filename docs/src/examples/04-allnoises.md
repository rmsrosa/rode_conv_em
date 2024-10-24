```@meta
EditURL = "../../literate/examples/04-allnoises.jl"
```

# Linear system with all implemented noises

This time we consider a linear *system* of equations with a vector-valued noise composed of all the implemented noises.

## The equation

More precisely, we consider the RODE
```math
  \begin{cases}
    \displaystyle \frac{\mathrm{d}\mathbf{X}_t}{\mathrm{d} t} = - \|\mathbf{Y}_t\|^2 \mathbf{X}_t + \mathbf{Y}_t, \qquad 0 \leq t \leq T, \\
  \left. \mathbf{X}_t \right|_{t = 0} = \mathbf{X}_0,
  \end{cases}
```
where $\{\mathbf{Y}_t\}_{t\geq 0}$ is a vector-valued noise with each component being each of the implemented noises.

Again, the *target* solution is construced by solving the system via Euler method at a much higher resolution.

## Numerical approximation

### Setting up the problem

First we load the necessary packages

````@example 04-allnoises
using Plots
using LinearAlgebra
using Random
using Distributions
using RODEConvergence
````

Then we set up some variables, as in the first example. First, the RNG:

````@example 04-allnoises
rng = Xoshiro(123)
````

Next the right hand side of the system of equations, in the *in-place* version, for the sake of performance. Here, the vector variable `dx` is updated with the right hand side of the system of equations. The norm squared of the noise `y` at a given time `t` is computed via `sum(abs2, y)`.

````@example 04-allnoises
f!(dx, t, x, y) = (dx .= .- sum(abs2, y) .* x .+ y)
````

The time interval is given by the end points

````@example 04-allnoises
t0, tf = 0.0, 1.0
````

and the mesh parameters are set to

````@example 04-allnoises
ntgt = 2^18
ns = 2 .^ (6:9)
nsample = ns[[1, 2, 3]]
````

The number of simulations for the Monte Carlo estimate is set to

````@example 04-allnoises
m = 80
````

Now we define all the noise parameters

````@example 04-allnoises
y0 = 0.2

ν = 0.3
σ = 0.5

μ = 0.3

μ1 = 0.5
μ2 = 0.3
ω = 3π
primitive_a = t -> μ1 * t - μ2 * cos(ω * t) / ω
primitive_b2 = t -> σ^2 * ( t/2 - sin(ω * t) * cos(ω * t) / 2ω )

λ = 5.0
dylaw = Exponential(0.5)

steplaw = Uniform(0.0, 1.0)

λ₀ = 3.0
a = 2.0
δ = 3.0

nr = 6
transport(t, r) = mapreduce(ri -> cbrt(sin(ri * t)), +, r) / length(r)
ylaw = Gamma(7.5, 2.0)

hurst = 0.6
````

The noise is, then, defined as a (vectorial) [`ProductProcess`](@ref), where each coordinate is one of the implemented noise types:

````@example 04-allnoises
noise = ProductProcess(
    WienerProcess(t0, tf, 0.0),
    OrnsteinUhlenbeckProcess(t0, tf, y0, ν, σ),
    GeometricBrownianMotionProcess(t0, tf, y0, μ, σ),
    HomogeneousLinearItoProcess(t0, tf, y0, primitive_a, primitive_b2),
    CompoundPoissonProcess(t0, tf, λ, dylaw),
    PoissonStepProcess(t0, tf, λ, steplaw),
    ExponentialHawkesProcess(t0, tf, λ₀, a, δ, dylaw),
    TransportProcess(t0, tf, ylaw, transport, nr),
    FractionalBrownianMotionProcess(t0, tf, y0, hurst, ntgt)
)
````

Both the Wiener and the Orsntein-Uhlenbeck processes are additive noises so the strong order 1 convergence for them is not a surprise based on previous work.

All the other noises, however, would be thought to have a lower order of convergence but our results prove they are still of order 1. Hence, their combination is also expected to be of order 1, as illustrated here.

Notice we chose the hurst parameter of the fractional Brownian motion process to be between 1/2 and 1, so that the strong convergence is also of order 1, just like for the other types of noises in `noise`. Previous knowledge would expect a strong convergence of order $H$, with $1/2 < H < 1,$ instead.

The geometric Brownian motion process, say $\{G_t\}_t,$ is a multiplicative noise, but since its solution is given explicitly in the form $G_t = g(t, W_t)$ for a Wiener process $\{W_t\}_{t}$, then the Euler method for the associated RODE coincides with the Euler method for an associated RODE with additive noise $\{W_t\}_t.$ However, the corresponding nonlinear term does not have global Lipschitz bound, so the strong order 1 does not follow from that. Our results, however, apply without further assumptions.

Finally, the homogeneous linear Itô process is a multiplicative noise whose state at time $t$ cannot be written explicitly as a function of $t$ and $W_t.$ It requires the previous history $W_s$ of the associated Wiener process, for $0\leq s \leq t,$ hence it would genuinely be expected to be of strong order less than 1/2, which is not the case as we show here, proving it to also be of order 1.

Now we set up the initial condition, taking into account the number of equations in the system, which is determined by the dimension of the vector-valued noise.

````@example 04-allnoises
x0law = MvNormal(zeros(length(noise)), I)
````

We finally add some information about the simulation:

````@example 04-allnoises
info = (
    equation = "\$\\mathrm{d}\\mathbf{X}_t/\\mathrm{d}t = - \\| \\mathbf{Y}_t\\|^2 \\mathbf{X}_t + \\mathbf{Y}_t\$",
    noise = "vector-valued noise \$\\{\\mathbf{Y}_t\\}_t\$ with all the implemented noises",
    ic = "\$\\mathbf{X}_0 \\sim \\mathcal{N}(\\mathbf{0}, \\mathrm{I})\$"
)
````

The method for which want to estimate the rate of convergence is, naturally, the Euler method, which is also used to compute the *target* solution, at the finest mesh:

````@example 04-allnoises
target = RandomEuler(length(noise))
method = RandomEuler(length(noise))
````

### Order of convergence

With all the parameters set up, we build the [`ConvergenceSuite`](@ref):

````@example 04-allnoises
suite = ConvergenceSuite(t0, tf, x0law, f!, noise, target, method, ntgt, ns, m)
````

Then we are ready to compute the errors via [`solve`](@ref):

````@example 04-allnoises
@time result = solve(rng, suite)
nothing # hide
````

The computed strong error for each resolution in `ns` is stored in `result.errors`, and a raw LaTeX table can be displayed for inclusion in the article:

````@example 04-allnoises
table = generate_error_table(result, info)

println(table) # hide
nothing # hide
````

The calculated order of convergence is given by `result.p`:

````@example 04-allnoises
println("Order of convergence `C Δtᵖ` with p = $(round(result.p, sigdigits=2)) and 95% confidence interval ($(round(result.pmin, sigdigits=3)), $(round(result.pmax, sigdigits=3)))")
nothing # hide
````

### Plots

We illustrate the rate of convergence with the help of a plot recipe for `ConvergenceResult`:

````@example 04-allnoises
plt_result = plot(result)
````

````@example 04-allnoises
savefig(plt_result, joinpath(@__DIR__() * "../../../../latex/img/", "order_allnoises.pdf")) # hide
nothing # hide
````

For the sake of illustration, we plot a sample of the norms of a sequence of approximations of a target solution, along with the norm of the target:

````@example 04-allnoises
plts = [plot(suite, ns=nsample, xshow=i, resolution=2^4, title="Coordinate $i", titlefont=8) for i in axes(suite.xt, 2)]

plot(plts..., legend=false)
````

We can also visualize the noises associated with this sample solution, both individually, as they enter the non-homogenous term,

````@example 04-allnoises
plt_noises = plot(suite, xshow=false, yshow=true, linecolor=:auto, label=["W" "OU" "gBm" "hlp" "cP" "sP" "Hawkes" "Transport" "fBm"])
````

````@example 04-allnoises
savefig(plt_noises, joinpath(@__DIR__() * "../../../../latex/img/", "noisepath_allnoises.pdf")) # hide
nothing # hide
````

and combined, with their sum squared, as it enters the homogenous term,

````@example 04-allnoises
plot(suite, xshow=false, yshow= y -> sum(abs2, y), label="\$\\left\\|\\left\\|\\mathbf{Y}_t\\right\\|\\right\\|^2\$")
````

We finally combine all the convergence plot and the noises into a single plot, for the article:

````@example 04-allnoises
plt_combined = plot(plt_result, plt_noises, size=(720, 240), title=["(a)" "(b)"], titlefont=10)
````

````@example 04-allnoises
savefig(plt_combined, joinpath(@__DIR__() * "../../../../latex/img/", "allnoises_combined.pdf")) # hide
nothing # hide
````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

