

source $SAMBITMISHRA98/terminal-helper/lib/common/add_installation.sh

export OMP_PROC_BIND=TRUE
export OMP_PLACES=cores
export OMP_NUM_THREADS=1

case "$(hostname -s)" in
  spitfire-ng0[1-9]|spitfire-ng1[0-9]|spitfire-ng20)
    add_installation_to_path cuda-12.6                ""         /usr/local/
    add_installation_to_path rocm-userspace/7.0.0/opt rocm-7.0.0 $INSTALLS
    export UCX_TLS=self,sm,dc_mlx5,rc_mlx5,cuda,cuda_copy,cuda_ipc
    ;;
  spitfire-ng2[2-9])
    add_installation_to_path cuda/12.6.0 "toolkit" $INSTALLS
    add_installation_to_path rocm-7.0.0/ ""        /opt/
    export UCX_TLS=self,sm,dc_mlx5,rc_mlx5,rocm_copy,rocm_ipc
    ;;

  *)
    add_installation_to_path cuda-12.6   "" /usr/local/
    add_installation_to_path rocm-7.0.0/ "" /opt/
    export UCX_TLS=self,sm,dc_mlx5,rc_mlx5
esac

add_installation_to_path gcc         12.3.0 $SCRATCH/.local-spitfire/pkg/

add_installation_to_path ucx/1.20.0  ng24/  $INSTALLS
add_installation_to_path mpich/4.3.2 ng24/  $INSTALLS
add_installation_to_path libffi  3.4.8   $INSTALLS
add_installation_to_path openssl 1.1.1w  $INSTALLS
add_installation_to_path python  3.13.3  $INSTALLS

source $INSTALLS/mpich/4.3.2/ng24/venv/pyfr/bin/activate

export UCX_NET_DEVICES=mlx5_0:1

export ASCENT_INSTALLATION_LOCATION=$INSTALLS/ascent/ng24/develop/scripts/build_ascent/install
add_installation_to_path "conduit-v0.9.5" "" "$ASCENT_INSTALLATION_LOCATION"
export PYFR_ASCENT_MPI_LIBRARY_PATH="${ASCENT_INSTALLATION_LOCATION}/ascent-checkout/lib/libascent_mpi.so"

export   PYFR_XSMM_LIBRARY_PATH=$SCRATCH/.local-spitfire/git/libxsmm/libxsmm/lib/libxsmm.so
export  PYFR_METIS_LIBRARY_PATH=$SCRATCH/.local-spitfire/git/metis/lib/libmetis.so
export PYFR_SCOTCH_LIBRARY_PATH=$INSTALLS/scotch/7.0.10/lib64/libscotch.so
export  PYFR_KAHIP_LIBRARY_PATH=$DOWNLOADS/kahip/deploy/libkahip.so
export LD_PRELOAD="$INSTALLS/scotch/7.0.10/lib64/libscotcherr.so${LD_PRELOAD:+:$LD_PRELOAD}"

# ------------------------------------------------------------------------------    
