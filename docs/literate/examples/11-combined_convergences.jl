# # Combined plot
#

# ```@meta
#     Draft = false
# ```

# Here we just read the results of some examples to build a combined plot for the companion article.

using JLD2
using Plots
using Measures
using Distributions
using RODEConvergence

# Read previously saved convergence data.

results_popdyn = load(joinpath(@__DIR__(), "results/06-popdyn_result.jld2"), "result")
results_risk = load(joinpath(@__DIR__(), "results/10-risk_result.jld2"), "result")
nothing

# Draw combined plot

plt_popdyn = plot(results_popdyn)
plt_risk = plot(results_risk)

plt_combined = plot(plt_popdyn, plt_risk, legendfont=6, size=(800, 240), title=["(a)" "(b)"], titlefont=10, bottom_margin=5mm, left_margin=5mm)

# Save it

savefig(plt_combined, joinpath(@__DIR__() * "../../../../latex/img/", "combined_popdyn_risk.pdf"))
nothing # hide