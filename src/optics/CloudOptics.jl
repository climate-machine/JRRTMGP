
"""
    add_cloud_optics_2stream(
        op::TwoStream,
        as::AtmosphericState,
        lkp::LookUpLW,
        lkp_cld,
        glay, gcol,
        ibnd,
        igpt,
    )

This function computes the longwave TwoStream clouds optics properties and adds them
to the TwoStream longwave gas optics properties.
"""
function add_cloud_optics_2stream(
    τ_gas,
    ssa_gas,
    g_gas,
    cld_mask,
    re_liq,
    re_ice,
    ice_rgh,
    cld_path_liq,
    cld_path_ice,
    lkp_cld,
    ibnd,
    igpt,
    delta_scaling = false,
)
    if cld_mask
        τ_cl, ssa_cl, g_cl = compute_cld_props(lkp_cld, re_liq, re_ice, ice_rgh, cld_path_liq, cld_path_ice, ibnd)
        if delta_scaling
            τ_cl, ssa_cl, g_cl = delta_scale(τ_cl, ssa_cl, g_cl)
        end
        return increment_2stream(τ_gas, ssa_gas, g_gas, τ_cl, ssa_cl, g_cl)
    end
    return (τ_gas, ssa_gas, g_gas)
end

"""
    add_cloud_optics_2stream(op::OneScalar, args...)

Cloud optics is currently only supported for the TwoStream solver.
"""
function add_cloud_optics_2stream(op::OneScalar, args...)
    return nothing
end
"""
    compute_cld_props(lkp_cld, as, glay, gcol, ibnd, igpt)

This function computed the TwoSteam cloud optics properties using either the 
lookup table method or pade method.
"""
function compute_cld_props(lkp_cld::LookUpCld, re_liq, re_ice, ice_rgh, cld_path_liq, cld_path_ice, ibnd)
    FT = eltype(re_liq)
    τl, τl_ssa, τl_ssag = FT(0), FT(0), FT(0)
    τi, τi_ssa, τi_ssag = FT(0), FT(0), FT(0)
    (;
        lut_extliq,
        lut_ssaliq,
        lut_asyliq,
        lut_extice,
        lut_ssaice,
        lut_asyice,
        radliq_lwr,
        radliq_upr,
        radice_lwr,
        radice_upr,
    ) = lkp_cld
    nsize_liq = LookUpTables.get_nsize_liq(lkp_cld)
    nsize_ice = LookUpTables.get_nsize_ice(lkp_cld)
    Δr_liq = (radliq_upr - radliq_lwr) / FT(nsize_liq - 1)
    Δr_ice = (radice_upr - radice_lwr) / FT(nsize_ice - 1)
    # cloud liquid particles
    if cld_path_liq > eps(FT)
        loc = Int(max(min(unsafe_trunc(Int, (re_liq - radliq_lwr) / Δr_liq) + 1, nsize_liq - 1), 1))
        fac = (re_liq - radliq_lwr - (loc - 1) * Δr_liq) / Δr_liq
        fc1 = FT(1) - fac
        @inbounds begin
            τl = (fc1 * lut_extliq[loc, ibnd] + fac * lut_extliq[loc + 1, ibnd]) * cld_path_liq
            τl_ssa = (fc1 * lut_ssaliq[loc, ibnd] + fac * lut_ssaliq[loc + 1, ibnd]) * τl
            τl_ssag = (fc1 * lut_asyliq[loc, ibnd] + fac * lut_asyliq[loc + 1, ibnd]) * τl_ssa
        end
    end
    # cloud ice particles
    if cld_path_ice > eps(FT)
        loc = Int(max(min(unsafe_trunc(Int, (re_ice - radice_lwr) / Δr_ice) + 1, nsize_ice - 1), 1))
        fac = (re_ice - radice_lwr - (loc - 1) * Δr_ice) / Δr_ice
        fc1 = FT(1) - fac
        @inbounds begin
            τi = (fc1 * lut_extice[loc, ibnd, ice_rgh] + fac * lut_extice[loc + 1, ibnd, ice_rgh]) * cld_path_ice
            τi_ssa = (fc1 * lut_ssaice[loc, ibnd, ice_rgh] + fac * lut_ssaice[loc + 1, ibnd, ice_rgh]) * τi
            τi_ssag = (fc1 * lut_asyice[loc, ibnd, ice_rgh] + fac * lut_asyice[loc + 1, ibnd, ice_rgh]) * τi_ssa
        end
    end

    τ = τl + τi
    τ_ssa = τl_ssa + τi_ssa
    τ_ssag = (τl_ssag + τi_ssag) / max(eps(FT), τ_ssa)
    τ_ssa /= max(eps(FT), τ)

    return (τ, τ_ssa, τ_ssag)
end

function compute_cld_props(lkp_cld::PadeCld, re_liq, re_ice, ice_rgh, cld_path_liq, cld_path_ice, ibnd)
    FT = eltype(re_liq)
    τl, τl_ssa, τl_ssag = FT(0), FT(0), FT(0)
    τi, τi_ssa, τi_ssag = FT(0), FT(0), FT(0)

    (;
        pade_extliq,
        pade_ssaliq,
        pade_asyliq,
        pade_extice,
        pade_ssaice,
        pade_asyice,
        pade_sizreg_extliq,
        pade_sizreg_ssaliq,
        pade_sizreg_asyliq,
        pade_sizreg_extice,
        pade_sizreg_ssaice,
        pade_sizreg_asyice,
    ) = lkp_cld
    m_ext, m_ssa_g = 3, 3
    n_ext, n_ssa_g = 3, 2
    # Finds index into size regime table
    # This works only if there are precisely three size regimes (four bounds) and it's
    # previously guaranteed that size_bounds(1) <= size <= size_bounds(4)
    if cld_path_liq > eps(FT)
        @inbounds begin
            irad = Int(min(floor((re_liq - pade_sizreg_extliq[2]) / pade_sizreg_extliq[3]) + 2, 3))
            τl = pade_eval(ibnd, re_liq, irad, m_ext, n_ext, pade_extliq) * cld_path_liq

            irad = Int(min(floor((re_liq - pade_sizreg_ssaliq[2]) / pade_sizreg_ssaliq[3]) + 2, 3))
            τl_ssa = (FT(1) - max(FT(0), pade_eval(ibnd, re_liq, irad, m_ssa_g, n_ssa_g, pade_ssaliq))) * τl

            irad = Int(min(floor((re_liq - pade_sizreg_asyliq[2]) / pade_sizreg_asyliq[3]) + 2, 3))
            τl_ssag = pade_eval(ibnd, re_liq, irad, m_ssa_g, n_ssa_g, pade_asyliq) * τl_ssa
        end
    end

    if cld_path_ice > eps(FT)
        @inbounds begin
            irad = Int(min(floor((re_ice - pade_sizreg_extice[2]) / pade_sizreg_extice[3]) + 2, 3))

            τi = pade_eval(ibnd, re_ice, irad, m_ext, n_ext, pade_extice, ice_rgh) * cld_path_ice

            irad = Int(min(floor((re_ice - pade_sizreg_ssaice[2]) / pade_sizreg_ssaice[3]) + 2, 3))
            τi_ssa = (FT(1) - max(FT(0), pade_eval(ibnd, re_ice, irad, m_ssa_g, n_ssa_g, pade_ssaice, ice_rgh))) * τi

            irad = Int(min(floor((re_ice - pade_sizreg_asyice[2]) / pade_sizreg_asyice[3]) + 2, 3))
            τi_ssag = pade_eval(ibnd, re_ice, irad, m_ssa_g, n_ssa_g, pade_asyice, ice_rgh) * τi_ssa
        end
    end

    τ = τl + τi
    τ_ssa = τl_ssa + τi_ssa
    τ_ssag = (τl_ssag + τi_ssag) / max(eps(FT), τ_ssa)
    τ_ssa /= max(eps(FT), τ)

    return (τ, τ_ssa, τ_ssag)
end


"""
    pade_eval(
        ibnd,
        re,
        irad,
        m,
        n,
        pade_coeffs,
        irgh::Union{Int,Nothing} = nothing,
    )

Evaluate Pade approximant of order [m/n]
"""
function pade_eval(ibnd, re, irad, m, n, pade_coeffs, irgh::Union{Int, Nothing} = nothing)
    FT = eltype(re)
    if irgh isa Int
        coeffs = view(pade_coeffs, :, :, :, irgh)

    else
        coeffs = pade_coeffs
    end

    denom = coeffs[ibnd, irad, n + m]
    @inbounds for i in (n + m - 1):-1:(1 + m)
        denom = coeffs[ibnd, irad, i] + re * denom
    end
    denom = FT(1) + re * denom

    numer = coeffs[ibnd, irad, m]
    @inbounds for i in (m - 1):-1:2
        numer = coeffs[ibnd, irad, i] + re * numer
    end
    numer = coeffs[ibnd, irad, 1] + re * numer

    return (numer / denom)
end

"""
    build_cloud_mask!(cld_mask, cld_frac, ::MaxRandomOverlap)

Builds McICA-sampled cloud mask from cloud fraction data for maximum-random overlap

Reference: https://github.com/AER-RC/RRTMG_SW/
"""
function build_cloud_mask!(
    cld_mask::AbstractArray{Bool, 1},
    cld_frac::AbstractArray{FT, 1},
    ::MaxRandomOverlap,
) where {FT}
    nlay = size(cld_frac, 1)
    start = _get_start(cld_frac) # first cloudy layer

    if start > 0
        finish = _get_finish(cld_frac) # last cloudy layer
        # set cloud mask for non-cloudy layers
        _mask_outer_non_cloudy_layers!(cld_mask, start, finish)
        # RRTMG uses random_arr[finish] > (FT(1) - cld_frac[finish]), 
        # we change > to >= to address edge cases
        @inbounds cld_frac_ilayplus1 = cld_frac[finish]
        random_ilayplus1 = Random.rand()
        @inbounds cld_mask[finish] = cld_mask_ilayplus1 = random_ilayplus1 >= (FT(1) - cld_frac_ilayplus1)
        for ilay in (finish - 1):-1:start
            @inbounds cld_frac_ilay = cld_frac[ilay]
            if cld_frac_ilay > FT(0)
                # use same random number from the layer above if layer above is cloudy
                # update random numbers if layer above is not cloudy
                random_ilay = cld_mask_ilayplus1 ? random_ilayplus1 : Random.rand() * (FT(1) - cld_frac_ilayplus1)
                # RRTMG uses random_arr[ilay] > (FT(1) - cld_frac[ilay]), we change > to >= to address edge cases
                cld_mask_ilay = random_ilay >= (FT(1) - cld_frac_ilay)
                random_ilayplus1 = random_ilay
            else
                cld_mask_ilay = false
            end
            @inbounds cld_mask[ilay] = cld_mask_ilay
            cld_frac_ilayplus1 = cld_frac_ilay
            cld_mask_ilayplus1 = cld_mask_ilay
        end
    end
    return nothing
end

function _get_finish(cld_frac)
    @inbounds for ilay in reverse(eachindex(cld_frac))
        cld_frac[ilay] > 0 && return ilay
    end
    return 0
end

function _get_start(cld_frac)
    @inbounds for ilay in eachindex(cld_frac)
        cld_frac[ilay] > 0 && return ilay
    end
    return 0
end

function _mask_outer_non_cloudy_layers!(cld_mask, start, finish)
    if start > 0
        for ilay in 1:(start - 1)
            @inbounds cld_mask[ilay] = false
        end
        nlay = length(cld_mask)
        for ilay in (finish + 1):nlay
            @inbounds cld_mask[ilay] = false
        end
    end
    return nothing
end
