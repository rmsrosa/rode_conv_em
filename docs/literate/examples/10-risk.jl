# # An actuarial risk model
#
# ```@meta
# Draft = false
# ```
#
# A classical model for the surplus $U_t$ at time $t$ of an insurance company is the Cramér–Lundberg model (see [Delbaen & Haezendonck](https://doi.org/10.1016/0167-6687(87)90019-9)) given by
# ```math
#   U_t = U_0 + \gamma t - \sum_{i=1}^{N_t} C_i
# ```
# where $U_0$ is the initial capital, $\gamma$ is a constant premium rate received from the insurees, $C_i$ is a random variable representing the value of the $i$-th claim paid to a given insuree, and $N_t$ is the number of claims up to time $t$. The process $\{N_t\}_t$ is modeled as a Poisson counter, so that the accumulated claims form a compound Poisson process. It is also common to use inhomogeneous Poisson processes and Hawkes self-exciting process, or combinations of such processes, but the classical model uses a compound Poisson process.
#
# The model above, however, does not take into account the variability of the premium rate received by the company, nor the investiment of the accumulated reserves, among other things. Several diffusion type models have been proposed to account for these and other factors. We will consider a simple model, with a randomly perturbed premium and with variable rentability.
#
# More precisely, we start by rewriting the above expression as the following jump differential equation
# ```math
#   \mathrm{d}U_t = \gamma\;\mathrm{d}t - \mathrm{d}C_t,
# ```
# where
# ```math
#   C_t = \sum_{i=1}^{N_t} C_i.
# ```
#
# The addition of an interest rate leads to
# ```math
#   \mathrm{d}U_t = \mu U_t \mathrm{d}t + \gamma\;\mathrm{d}t - \mathrm{d}C_t,
# ```
#
# Assuming a premium rate perturbed by a white noise and assuming the interest rate as a process $\{M_t\}_t$, we find
# ```math
#   \mathrm{d}U_t = M_t U_t\;\mathrm{d}t + \gamma\;\mathrm{d}t + \varepsilon\;\mathrm{d}W_t - \mathrm{d}C_t,
# ```
# so the equation becomes
# ```math
#   \mathrm{d}U_t = (\gamma + M_t U_t)\;\mathrm{d}t + \varepsilon\;\mathrm{d}W_t - \mathrm{d}C_t.
# ```
#
# Since we can compute exactly the accumulated claims $C_t$, we subtract it from $U_t$ to get rid of the jump term. We also subtract an Ornstein-Uhlenbeck process, in the classical way to transform an SDE into a RODE. So, defining
# ```math
#   X_t = U_t - C_t - O_t
# ```
# where $\{O_t\}_t$ is defined by
# ```math
#   \mathrm{d}O_t = \gamma\;\mathrm{d}t + \varepsilon\;\mathrm{d}W_t,
# ```
# we find
# ```math
#   \mathrm{d}X_t = M_t U_t\;\mathrm{d}t = M_t (X_t + C_t + O_t)\;\mathrm{d}t.
# ```
#
# This leads us to the linear random ordinary differential equation
# ```math
#   \frac{\mathrm{d}X_t}{\mathrm{d}t} = M_t X_t + M_t (C_t + O_t).
# ```
#
# This equation has the explicit solution
# ```math
#   X_t = X_0 e^{\int_0^t M_s\;\mathrm{d}s} + \int_0^t e^{\int_s^t M_\tau\;\mathrm{d}\tau}M_s (C_s + O_s)\;\mathrm{d}s.
# ```
#
# ## Numerical simulations
# 
# ### Setting up the problem
# 
# First we load the necessary packages

using Plots
using Random
using LinearAlgebra
using Distributions
using RODEConvergence

# Then we define the random seed

rng = Xoshiro(123)

# The evolution law

function f(t, x, y)
    o = y[1]
    m = y[2]
    c = y[3]
    dx = m * (x + c + o)
    return dx
end

# The time interval

t0, tf = 0.0, 3.0

# The law for the initial condition

x0 = 4.0
x0law = Dirac(x0)

# The Ornstein-Uhlenbeck, geometric Brownian motion, and compound Poisson processes for the noise term

OU0 = 0.1
OUγ = 1.0
Ouε = 0.8
M0 = 0.2
Mμ = 0.05
Mσ = 0.4
CM = 0.1
Cλ = 4.0
Claw = Uniform(0.0, CM)
noise = ProductProcess(
    OrnsteinUhlenbeckProcess(t0, tf, OU0, OUγ, Ouε),
    GeometricBrownianMotionProcess(t0, tf, M0, Mμ, Mσ),
    CompoundPoissonProcess(t0, tf, Cλ, Claw)
)

# The resolutions for the target and approximating solutions, as well as the number of simulations for the Monte-Carlo estimate of the strong error

ntgt = 2^18
ns = 2 .^ (6:9)
nsample = ns[[1, 2, 3, 4]]
m = 600

# And add some information about the simulation:

info = (
    equation = "a risk model",
    noise = "coupled Ornstein-Uhlenbeck, geometric Brownian motion, and compound Poisson processes",
    ic = "\$X_0 = $x0\$"
)

# We define the *target* solution as the Euler approximation, which is to be computed with the target number `ntgt` of mesh points, and which is also the one we want to estimate the rate of convergence, in the coarser meshes defined by `ns`.

target = RandomEuler()
method = RandomEuler()

# ### Order of convergence

# With all the parameters set up, we build the [`ConvergenceSuite`](@ref):       

suite = ConvergenceSuite(t0, tf, x0law, f, noise, target, method, ntgt, ns, m)

# Then we are ready to compute the errors via [`solve`](@ref):

@time result = solve(rng, suite)
nothing # hide

# The computed strong error for each resolution in `ns` is stored in `result.errors`, and a raw LaTeX table can be displayed for inclusion in the article:
# 

table = generate_error_table(result, info)

println(table) # hide
nothing # hide

# 
# The calculated order of convergence is given by `result.p`:

println("Order of convergence `C Δtᵖ` with p = $(round(result.p, sigdigits=2))")
nothing # hide

# 
# ### Plots
# 
# We plot the rate of convergence with the help of a plot recipe for `ConvergenceResult`:

plt_result = plot(result)

# And we save the convergence plot for inclusion in the article.

savefig(plt_result, joinpath(@__DIR__() * "../../../../latex/img/", "risk.png"))
nothing # hide

# For the sake of illustration of the behavior of the system, we visualize a sample solution

plt_sols = plot(suite, ns=nothing, label="X_t", linecolor=1)

#

savefig(plt_sols, joinpath(@__DIR__() * "../../../../latex/img/", "evolution_risk.png")) # hide
nothing # hide

# We also illustrate the convergence to a sample solution

plt_suite = plot(suite)

#

savefig(plt_suite, joinpath(@__DIR__() * "../../../../latex/img/", "approximation_risk.png")) # hide
nothing # hide

# We can also visualize the noises associated with this sample solution:

plt_noises = plot(suite, xshow=false, yshow=true, label=["\$O_t\$" "\$M_t\$" "\$C_t\$"], linecolor=[1 2])

#

savefig(plt_noises, joinpath(@__DIR__() * "../../../../latex/img/", "noises_risk.png")) # hide
nothing # hide

# The actual surplus is $U_t = X_t - O_t - C_t$, so we may visualize a sample solution of the surplus by subtracting these two noises from the solution of the above RODE.

plt_surplus = plot(range(t0, tf, length=ntgt), suite.xt .- suite.yt[:, 1] .- suite.yt[:, 3], ns=nothing, label="surplus", linecolor=1)

