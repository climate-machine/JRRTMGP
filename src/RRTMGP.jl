module RRTMGP

include("Misc.jl")
include("FortranIntrinsics.jl")
include("Utilities.jl")

include(joinpath("rte","ArrayUtilities.jl"))
include(joinpath("rte","SolarZenithAngle.jl"))
include(joinpath("rte","OpticalProps.jl"))
include(joinpath("rte","Fluxes.jl"))
include(joinpath("rte","SourceFunctions.jl"))
include(joinpath("extensions","CloudOptics.jl"))
include(joinpath("rte","RTESolver.jl"))

include(joinpath("rrtmgp","PhysicalConstants.jl"))
include(joinpath("rrtmgp","Gases.jl"))
include(joinpath("rrtmgp","ReferenceStates.jl"))
include(joinpath("rrtmgp","GasConcentrations.jl"))
include(joinpath("rrtmgp","AtmosphericStates.jl"))
include(joinpath("rrtmgp","GasOptics.jl"))

end # module
