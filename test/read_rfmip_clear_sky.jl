

function setup_rfmip_as(
    ds_lw_in,
    idx_gases,
    exp_no,
    lookup,
    ::Type{FT},
    ::Type{DA},
    ::Type{VMR},
    max_threads,
) where {FT<:AbstractFloat,DA,VMR}
    FTA1D = DA{FT,1}
    FTA2D = DA{FT,2}

    deg2rad = FT(π) / FT(180)
    nlay = Int(ds_lw_in.dim["layer"])
    ncol = Int(ds_lw_in.dim["site"])
    nlev = nlay + 1
    ngas = lookup.n_gases
    nbnd = lookup.n_bnd

    lon = DA{FT,1}(ds_lw_in["lon"][:])
    lat = DA{FT,1}(ds_lw_in["lat"][:])

    lon = nothing # This example skips latitude dependent gravity computation
    lat = nothing # to be consistent with the FORTRAN RRTMGP test case.

    sfc_emis = DA{FT,2}(repeat(
        reshape(Array{FT}(ds_lw_in["surface_emissivity"][:]), 1, :),
        nbnd,
        1,
    )) # all bands use same emissivity
    sfc_alb = DA{FT,2}(repeat(
        reshape(Array{FT}(ds_lw_in["surface_albedo"][:]), 1, :),
        nbnd,
        1,
    )) # all bands use same albedo
    #--------------------------------------------------------------
    zenith = Array{FT,1}(deg2rad .* ds_lw_in["solar_zenith_angle"][:])
    irrad = Array{FT,1}(ds_lw_in["total_solar_irradiance"][:])
    # block out coluumns with zenith > π/2
    usecol = BitArray(undef, ncol)
    usecol .= 1
    for i = 1:ncol
        if zenith[i] > FT(π) / 2 - 2 * eps(FT)
            irrad[i] = FT(0)
            usecol[i] = 0
        end
    end

    zenith = DA{FT,1}(zenith)
    irrad = DA{FT,1}(irrad)
    #--------------------------------------------------------------

    p_lev = ds_lw_in["pres_level"][:]

    lev_ind = p_lev[1, 1] > p_lev[end, 1] ? (1:nlev) : (nlev:-1:1)
    lay_ind = p_lev[1, 1] > p_lev[end, 1] ? (1:nlay) : (nlay:-1:1)

    p_lev[lev_ind[end], :] .= lookup.p_ref_min

    p_lev = DA{FT,2}(p_lev[lev_ind, :])
    p_lay = DA{FT,2}(ds_lw_in["pres_layer"][:][lay_ind, :])
    t_lev = DA{FT,2}(ds_lw_in["temp_level"][:][lev_ind, :, exp_no])
    t_lay = DA{FT,2}(ds_lw_in["temp_layer"][:][lay_ind, :, exp_no])

    t_sfc = DA{FT,1}(ds_lw_in["surface_temperature"][:, exp_no])
    col_dry = DA{FT,2}(undef, nlay, ncol)

    # Reading volume mixing ratios 

    vmr_h2o = FTA2D(ds_lw_in["water_vapor"][:][lay_ind, :, exp_no]) # vmr of H2O and O3
    vmr_o3 = FTA2D(ds_lw_in["ozone"][:][lay_ind, :, exp_no])       # vary with height

    vmrat = zeros(FT, ngas)

    vmrat[idx_gases["co2"]] =
        FT(ds_lw_in["carbon_dioxide_GM"][exp_no]) *
        parse(FT, ds_lw_in["carbon_dioxide_GM"].attrib["units"])

    vmrat[idx_gases["n2o"]] =
        FT(ds_lw_in["nitrous_oxide_GM"][exp_no]) *
        parse(FT, ds_lw_in["nitrous_oxide_GM"].attrib["units"])

    vmrat[idx_gases["co"]] =
        FT(ds_lw_in["carbon_monoxide_GM"][exp_no]) *
        parse(FT, ds_lw_in["carbon_monoxide_GM"].attrib["units"])

    vmrat[idx_gases["ch4"]] =
        FT(ds_lw_in["methane_GM"][exp_no]) *
        parse(FT, ds_lw_in["methane_GM"].attrib["units"])

    vmrat[idx_gases["o2"]] =
        FT(ds_lw_in["oxygen_GM"][exp_no]) *
        parse(FT, ds_lw_in["oxygen_GM"].attrib["units"])

    vmrat[idx_gases["n2"]] =
        FT(ds_lw_in["nitrogen_GM"][exp_no]) *
        parse(FT, ds_lw_in["nitrogen_GM"].attrib["units"])

    vmrat[idx_gases["ccl4"]] =
        FT(ds_lw_in["carbon_tetrachloride_GM"][exp_no]) *
        parse(FT, ds_lw_in["carbon_tetrachloride_GM"].attrib["units"])

    vmrat[idx_gases["cfc11"]] =
        FT(ds_lw_in["cfc11_GM"][exp_no]) *
        parse(FT, ds_lw_in["cfc11_GM"].attrib["units"])

    vmrat[idx_gases["cfc12"]] =
        FT(ds_lw_in["cfc12_GM"][exp_no]) *
        parse(FT, ds_lw_in["cfc12_GM"].attrib["units"])

    vmrat[idx_gases["cfc22"]] =
        FT(ds_lw_in["hcfc22_GM"][exp_no]) *
        parse(FT, ds_lw_in["hcfc22_GM"].attrib["units"])

    vmrat[idx_gases["hfc143a"]] =
        FT(ds_lw_in["hfc143a_GM"][exp_no]) *
        parse(FT, ds_lw_in["hfc143a_GM"].attrib["units"])

    vmrat[idx_gases["hfc125"]] =
        FT(ds_lw_in["hfc125_GM"][exp_no]) *
        parse(FT, ds_lw_in["hfc125_GM"].attrib["units"])

    vmrat[idx_gases["hfc23"]] =
        FT(ds_lw_in["hfc23_GM"][exp_no]) *
        parse(FT, ds_lw_in["hfc23_GM"].attrib["units"])

    vmrat[idx_gases["hfc32"]] =
        FT(ds_lw_in["hfc32_GM"][exp_no]) *
        parse(FT, ds_lw_in["hfc32_GM"].attrib["units"])

    vmrat[idx_gases["hfc134a"]] =
        FT(ds_lw_in["hfc134a_GM"][exp_no]) *
        parse(FT, ds_lw_in["hfc134a_GM"].attrib["units"])

    vmrat[idx_gases["cf4"]] =
        FT(ds_lw_in["cf4_GM"][exp_no]) *
        parse(FT, ds_lw_in["hfc23_GM"].attrib["units"])

    #    vmr[idx_gases["no2"]] = FT(ds_lw_in["no2_GM"][exp_no]) *                # missing from input file
    #                                         parse(FT, ds_lw_in["hfc32_GM"].attrib["units"])

    # This example skips latitude dependent gravity compution to be consistent with the
    # FORTRAN RRTMGP test case.
    compute_col_dry!(p_lev, col_dry, param_set, vmr_h2o, lat) # the example skips lat based gravity calculation

    vmr = VMR(vmr_h2o, vmr_o3, FTA1D(vmrat))
    cld_r_eff_liq = nothing
    cld_r_eff_ice = nothing
    cld_path_liq = nothing
    cld_path_ice = nothing
    cld_mask = nothing
    ice_rgh = 1
    #------------------
    return (
        AtmosphericState{
            FT,
            typeof(t_sfc),
            typeof(lat),
            typeof(p_lev),
            typeof(cld_r_eff_liq),
            typeof(cld_mask),
            typeof(vmr),
            Int,
        }(
            lon,
            lat,
            p_lay,
            p_lev,
            t_lay,
            t_lev,
            t_sfc,
            col_dry,
            vmr,
            cld_r_eff_liq,
            cld_r_eff_ice,
            cld_path_liq,
            cld_path_ice,
            cld_mask,
            ice_rgh,
            nlay,
            ncol,
            ngas,
        ),
        sfc_emis,
        sfc_alb,
        zenith,
        irrad,
        usecol,
    )

    #=
    return (
        ClearAtmosphericState{
            FT,
            DA{FT,1},
            typeof(lat),
            DA{FT,2},
            typeof(vmr),
            Int,
        }(
            lon,
            lat,
            p_lay,
            p_lev,
            t_lay,
            t_lev,
            t_sfc,
            col_dry,
            vmr,
            nlay,
            ncol,
            ngas,
        ),
        sfc_emis,
        sfc_alb,
        zenith,
        irrad,
    )
    =#

end