module RRTMGPCUDAExt

import ClimaComms
import RRTMGP.Parameters as RP
import RRTMGP.Fluxes: FluxLW, FluxSW
import RRTMGP.Fluxes: add_to_flux!
import RRTMGP.Fluxes: set_flux_to_zero!
import RRTMGP.Sources: SourceLWNoScat
import RRTMGP.Sources: SourceLW2Str
import RRTMGP.Sources: SourceSW2Str
import RRTMGP.BCs: LwBCs, SwBCs
import RRTMGP.Optics: OneScalar, TwoStream
import RRTMGP.Optics
import RRTMGP.Optics: compute_optical_props!
import RRTMGP.Optics: compute_col_gas!
import RRTMGP.Optics: compute_col_gas_kernel!
import RRTMGP.AtmosphericStates: setup_gray_as_pr_grid!
import RRTMGP.AtmosphericStates: setup_gray_as_pr_grid_kernel!
import RRTMGP.AtmosphericStates: GrayAtmosphericState
import RRTMGP.AtmosphericStates: AtmosphericState
import RRTMGP.AtmosphericStates: CloudState
import RRTMGP.AtmosphericStates
import RRTMGP.GrayUtils: update_profile_lw!
import RRTMGP.GrayUtils: compute_gray_heating_rate!
import RRTMGP.GrayUtils: compute_gray_heating_rate_kernel!
import RRTMGP.GrayUtils: update_profile_lw_kernel!
import RRTMGP.LookUpTables: LookUpLW, LookUpCld, PadeCld, LookUpSW
import RRTMGP.RTESolver: rte_lw_noscat_solve!
import RRTMGP.RTESolver: rte_lw_noscat!
import RRTMGP.RTESolver: rte_lw_2stream_solve!
import RRTMGP.RTESolver: rte_lw_2stream!
import RRTMGP.RTESolver: rte_sw_2stream_solve!
import RRTMGP.RTESolver: rte_sw_2stream!
import RRTMGP.RTESolver: rte_sw_noscat!
import RRTMGP.RTESolver: rte_sw_noscat_solve!
import CUDA: threadIdx, blockIdx, blockDim, @cuda

include(joinpath("cuda", "gray_atmospheric_states.jl"))
include(joinpath("cuda", "rte_longwave_2stream.jl"))
include(joinpath("cuda", "optics.jl"))
include(joinpath("cuda", "rte_shortwave_1scalar.jl"))
include(joinpath("cuda", "optics_gray_utils.jl"))
include(joinpath("cuda", "rte_shortwave_2stream.jl"))
include(joinpath("cuda", "rte_longwave_1scalar.jl"))

end
