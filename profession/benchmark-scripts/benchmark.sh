
# ------------------------------------------------------------------------------
# PREPROCESS
# ------------------------------------------------------------------------------

# Define function preprocess

preprocess() {

    # test with 100 steps, actual test with 10,000 steps

    python3 $SAMBITMISHRA98/terminal-helper/profession/benchmark-scripts/preprocess_templater.py \
            --output benchmark_tgv.csv \
            --mesh:etype hex,tet --mesh:order 2,3,4,5,6 \
            --config:backend_precision single,double \
            --mesh:dof 625000,1250000,2500000,5000000,10000000,20000000,40000000,80000000,160000000,320000000,640000000,1280000000
    cd cfgs/;
    pyfr benchmark preprocess-configs --options ../benchmark_tgv.csv --config $SAMBITMISHRA98/terminal-helper/profession/benchmark-scripts/cpu.ini

    # cd meshes/;
    # pyfr meshmaker generate-mesh      --options ../benchmark_tgv.csv

    cd ../;
}

# ------------------------------------------------------------------------------
# RUN BENCHMARKS AS SBATCH JOBS
# ------------------------------------------------------------------------------

arrayrun(){

    # Input cpu or gpu as arguement
    if [[ -z "$1" ]]; then
        echo "Usage: $0 <cpu|gpu>"
        return 1
    fi

    if [[ "$1" != "cpu" && "$1" != "gpu" ]]; then
        echo "Invalid argument: $1. Use 'cpu' or 'gpu'."
        return 1
    fi

    if [[ "$1" == "cpu" ]]; then
        backend=openmp
    else
        backend=cuda
    fi

    etypes=(tet hex)
    dofs=(625000 1250000 2500000 5000000 10000000 20000000 40000000 80000000 160000000 320000000 640000000 1280000000)
    orders=(2 3 4 5 6)
    precisions=(single double)

    for precision in "${precisions[@]}"; do
        for etype in "${etypes[@]}"; do
            for dof in "${dofs[@]}"; do
                for order in "${orders[@]}"; do
                    meshfile="../meshes/etype-${etype}_order-${order}_dof-${dof}.pyfrm"
                    cfgfile="../cfgs/cpubackend_precision-${precision}_solver_order-${order}_soln-plugin-writer_basename-m_e-${etype}__m_o-${order}__c_b-${precision}__m_d-${dof}__c_s-${order}.ini"
                    if [[ -e "$meshfile" && -e "$cfgfile" ]]; then
                        echo "Submit $(basename "$cfgfile")"

                        if [[ "$1" == "cpu" ]]; then
                            sbatch "$SAMBITMISHRA98/terminal-helper/profession/benchmark-scripts/sbatches/template.Launchcpu" "$backend" "$meshfile" "$cfgfile"
                        else
                            sbatch "$SAMBITMISHRA98/terminal-helper/profession/benchmark-scripts/sbatches/template.Launchgpu" "$backend" "$meshfile" "$cfgfile"
                        fi

                    else
                        echo "Skip  $(basename "$cfgfile") (missing mesh or cfg)"
                    fi
                done
            done
        done
    done
}


loadbalance(){

    # etypes=(tet hex)
    # dofs=(1250000 2500000 5000000 10000000 20000000 40000000 80000000 160000000 320000000 640000000 1280000000)
    # orders=(2 3 4 5 6)
    # precisions=(single double)

    etypes=(hex )
    dofs=(160000000  )
    orders=(6 )
    precisions=(single )

    for precision in "${precisions[@]}"; do
        for etype in "${etypes[@]}"; do
            for dof in "${dofs[@]}"; do
                for order in "${orders[@]}"; do
                    meshfile="../meshes/etype-${etype}_order-${order}_dof-${dof}.pyfrm"
                    cfgfile="../cfgs/cpubackend_precision-${precision}_solver_order-${order}_soln-plugin-writer_basename-m_e-${etype}__m_o-${order}__c_b-${precision}__m_d-${dof}__c_s-${order}.ini"
                    if [[ -e "$meshfile" && -e "$cfgfile" ]]; then
                        echo "Submit $(basename "$cfgfile")"
                        sbatch "$SAMBITMISHRA98/terminal-helper/profession/benchmark-scripts/sbatches/template.LaunchMixed" "$meshfile" "$cfgfile"
                    else
                        echo "Skip  $(basename "$cfgfile") (missing mesh or cfg)"
                    fi
                done
            done
        done
    done
}

# ------------------------------------------------------------------------------
# AFTER ALL ABOVE SBATCH JOBS ARE DONE, POSTPROCESS THE RESULTS
# ------------------------------------------------------------------------------

postprocess() {
   pyfr benchmark postprocess --files m*.pyfrs --output results.csv --options \
                               'config:solver_order' 'config:backend_precision' 'config:solver-time-integrator_scheme' \
                               'stats:mesh_nelems-.*' 'stats:mesh_gndofs' 'stats:observer-onerankcomputetime_mean' 'stats:observer-onerankcomputetime_sem'
    python3 /scratch/user/u.sm121949/.github/sambitmishra98/terminal-helper/profession/benchmark-scripts/plot-performance.py results.csv 
}
