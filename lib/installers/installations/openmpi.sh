#!/usr/bin/env bash



get_openmpi_pkg(){
    setup_base
    export_all_versions
    mkdir -p $PKG_DOWNLOAD/openmpi/$BUILD_OPENMPI_VER
    cd $PKG_DOWNLOAD/openmpi/$BUILD_OPENMPI_VER
    echo "Downloading OpenMPI in $PKG_DOWNLOAD/openmpi/$BUILD_OPENMPI_VER"
    wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-$BUILD_OPENMPI_VER.tar.gz -P $PKG_DOWNLOAD/openmpi/$BUILD_OPENMPI_VER
    tar -xf openmpi-$BUILD_OPENMPI_VER.tar.gz
    rm openmpi-$BUILD_OPENMPI_VER.tar.gz
}

setup_openmpi_pkg(){
    setup_base
    export_all_versions
    cd $PKG_DOWNLOAD/openmpi/$BUILD_OPENMPI_VER/openmpi-$BUILD_OPENMPI_VER

    # Login node node
    CMD="./configure --prefix=/mnt/share/sambit98/.local/installs/ompi4-mixed \
                     --enable-shared \
                     --with-cuda=/usr/local/cuda/ --with-rocm=/opt/rocm/ \
                     --with-ucx=/mnt/share/sambit98/.local/installs/ucx-mixed/master/ \
                     --with-pmi --with-slurm" ; echo $CMD

# 
# *** Final output
# checking for libraries that use libnl v1... (none)
# checking for libraries that use libnl v3... ibverbs
# checking that generated files are newer than configure... done
# configure: creating ./config.status
# config.status: creating ompi/include/ompi/version.h
# config.status: creating orte/include/orte/version.h
# config.status: creating oshmem/include/oshmem/version.h
# config.status: creating opal/include/opal/version.h
# config.status: creating ompi/mpi/java/Makefile
# config.status: creating ompi/mpi/java/java/Makefile
# config.status: creating ompi/mpi/java/c/Makefile
# config.status: creating ompi/mpi/fortran/configure-fortran-output.h
# config.status: creating opal/mca/hwloc/Makefile
# config.status: creating opal/mca/hwloc/external/Makefile
# config.status: creating opal/mca/hwloc/hwloc201/Makefile
# config.status: creating opal/mca/hwloc/hwloc201/hwloc/Makefile
# config.status: creating opal/mca/hwloc/hwloc201/hwloc/include/Makefile
# config.status: creating opal/mca/hwloc/hwloc201/hwloc/hwloc/Makefile
# config.status: creating opal/mca/common/Makefile
# config.status: creating opal/mca/common/cuda/Makefile
# config.status: creating opal/mca/common/ofi/Makefile
# config.status: creating opal/mca/common/sm/Makefile
# config.status: creating opal/mca/common/ucx/Makefile
# config.status: creating opal/mca/common/verbs/Makefile
# config.status: creating opal/mca/common/verbs_usnic/Makefile
# config.status: creating opal/mca/allocator/Makefile
# config.status: creating opal/mca/allocator/basic/Makefile
# config.status: creating opal/mca/allocator/bucket/Makefile
# config.status: creating opal/mca/backtrace/Makefile
# config.status: creating opal/mca/backtrace/execinfo/Makefile
# config.status: creating opal/mca/backtrace/printstack/Makefile
# config.status: creating opal/mca/backtrace/none/Makefile
# config.status: creating opal/mca/btl/Makefile
# config.status: creating opal/mca/btl/self/Makefile
# config.status: creating opal/mca/btl/ofi/Makefile
# config.status: creating opal/mca/btl/openib/Makefile
# config.status: creating opal/mca/btl/portals4/Makefile
# config.status: creating opal/mca/btl/sm/Makefile
# config.status: creating opal/mca/btl/smcuda/Makefile
# config.status: creating opal/mca/btl/tcp/Makefile
# config.status: creating opal/mca/btl/uct/Makefile
# config.status: creating opal/mca/btl/ugni/Makefile
# config.status: creating opal/mca/btl/usnic/Makefile
# config.status: creating opal/mca/btl/vader/Makefile
# config.status: creating opal/mca/compress/Makefile
# config.status: creating opal/mca/compress/bzip/Makefile
# config.status: creating opal/mca/compress/gzip/Makefile
# config.status: creating opal/mca/crs/Makefile
# config.status: creating opal/mca/crs/none/Makefile
# config.status: creating opal/mca/crs/self/Makefile
# config.status: creating opal/mca/dl/Makefile
# config.status: creating opal/mca/dl/dlopen/Makefile
# config.status: creating opal/mca/dl/libltdl/Makefile
# config.status: creating opal/mca/event/Makefile
# config.status: creating opal/mca/event/external/Makefile
# config.status: creating opal/mca/event/libevent2022/Makefile
# config.status: creating opal/mca/if/Makefile
# config.status: creating opal/mca/if/bsdx_ipv4/Makefile
# config.status: creating opal/mca/if/bsdx_ipv6/Makefile
# config.status: creating opal/mca/if/linux_ipv6/Makefile
# config.status: creating opal/mca/if/posix_ipv4/Makefile
# config.status: creating opal/mca/if/solaris_ipv6/Makefile
# config.status: creating opal/mca/installdirs/Makefile
# config.status: creating opal/mca/installdirs/env/Makefile
# config.status: creating opal/mca/installdirs/config/Makefile
# config.status: creating opal/mca/installdirs/config/install_dirs.h
# config.status: creating opal/mca/memchecker/Makefile
# config.status: creating opal/mca/memchecker/valgrind/Makefile
# config.status: creating opal/mca/memcpy/Makefile
# config.status: creating opal/mca/memory/Makefile
# config.status: creating opal/mca/memory/patcher/Makefile
# config.status: creating opal/mca/memory/malloc_solaris/Makefile
# config.status: creating opal/mca/mpool/Makefile
# config.status: creating opal/mca/mpool/hugepage/Makefile
# config.status: creating opal/mca/mpool/memkind/Makefile
# config.status: creating opal/mca/patcher/Makefile
# config.status: creating opal/mca/patcher/linux/Makefile
# config.status: creating opal/mca/patcher/overwrite/Makefile
# config.status: creating opal/mca/pmix/Makefile
# config.status: creating opal/mca/pmix/isolated/Makefile
# config.status: creating opal/mca/pmix/cray/Makefile
# config.status: creating opal/mca/pmix/ext1x/Makefile
# config.status: creating opal/mca/pmix/ext2x/Makefile
# config.status: creating opal/mca/pmix/ext3x/Makefile
# config.status: creating opal/mca/pmix/flux/Makefile
# config.status: creating opal/mca/pmix/pmix3x/Makefile
# config.status: creating opal/mca/pmix/s1/Makefile
# config.status: creating opal/mca/pmix/s2/Makefile
# config.status: creating opal/mca/pstat/Makefile
# config.status: creating opal/mca/pstat/linux/Makefile
# config.status: creating opal/mca/pstat/test/Makefile
# config.status: creating opal/mca/rcache/Makefile
# config.status: creating opal/mca/rcache/grdma/Makefile
# config.status: creating opal/mca/rcache/gpusm/Makefile
# config.status: creating opal/mca/rcache/rgpusm/Makefile
# config.status: creating opal/mca/rcache/udreg/Makefile
# config.status: creating opal/mca/reachable/Makefile
# config.status: creating opal/mca/reachable/weighted/Makefile
# config.status: creating opal/mca/reachable/netlink/Makefile
# config.status: creating opal/mca/shmem/Makefile
# config.status: creating opal/mca/shmem/mmap/Makefile
# config.status: creating opal/mca/shmem/posix/Makefile
# config.status: creating opal/mca/shmem/sysv/Makefile
# config.status: creating opal/mca/timer/Makefile
# config.status: creating opal/mca/timer/altix/Makefile
# config.status: creating opal/mca/timer/darwin/Makefile
# config.status: creating opal/mca/timer/linux/Makefile
# config.status: creating opal/mca/timer/solaris/Makefile
# config.status: creating orte/mca/common/Makefile
# config.status: creating orte/mca/common/alps/Makefile
# config.status: creating orte/mca/errmgr/Makefile
# config.status: creating orte/mca/errmgr/default_app/Makefile
# config.status: creating orte/mca/errmgr/default_hnp/Makefile
# config.status: creating orte/mca/errmgr/default_orted/Makefile
# config.status: creating orte/mca/errmgr/default_tool/Makefile
# config.status: creating orte/mca/ess/Makefile
# config.status: creating orte/mca/ess/env/Makefile
# config.status: creating orte/mca/ess/hnp/Makefile
# config.status: creating orte/mca/ess/pmi/Makefile
# config.status: creating orte/mca/ess/singleton/Makefile
# config.status: creating orte/mca/ess/tool/Makefile
# config.status: creating orte/mca/ess/alps/Makefile
# config.status: creating orte/mca/ess/lsf/Makefile
# config.status: creating orte/mca/ess/slurm/Makefile
# config.status: creating orte/mca/ess/tm/Makefile
# config.status: creating orte/mca/filem/Makefile
# config.status: creating orte/mca/filem/raw/Makefile
# config.status: creating orte/mca/grpcomm/Makefile
# config.status: creating orte/mca/grpcomm/direct/Makefile
# config.status: creating orte/mca/iof/Makefile
# config.status: creating orte/mca/iof/hnp/Makefile
# config.status: creating orte/mca/iof/orted/Makefile
# config.status: creating orte/mca/iof/tool/Makefile
# config.status: creating orte/mca/odls/Makefile
# config.status: creating orte/mca/odls/alps/Makefile
# config.status: creating orte/mca/odls/default/Makefile
# config.status: creating orte/mca/odls/pspawn/Makefile
# config.status: creating orte/mca/oob/Makefile
# config.status: creating orte/mca/oob/alps/Makefile
# config.status: creating orte/mca/oob/tcp/Makefile
# config.status: creating orte/mca/plm/Makefile
# config.status: creating orte/mca/plm/alps/Makefile
# config.status: creating orte/mca/plm/isolated/Makefile
# config.status: creating orte/mca/plm/lsf/Makefile
# config.status: creating orte/mca/plm/rsh/Makefile
# config.status: creating orte/mca/plm/slurm/Makefile
# config.status: creating orte/mca/plm/tm/Makefile
# config.status: creating orte/mca/ras/Makefile
# config.status: creating orte/mca/ras/simulator/Makefile
# config.status: creating orte/mca/ras/alps/Makefile
# config.status: creating orte/mca/ras/gridengine/Makefile
# config.status: creating orte/mca/ras/lsf/Makefile
# config.status: creating orte/mca/ras/slurm/Makefile
# config.status: creating orte/mca/ras/tm/Makefile
# config.status: creating orte/mca/regx/Makefile
# config.status: creating orte/mca/regx/fwd/Makefile
# config.status: creating orte/mca/regx/naive/Makefile
# config.status: creating orte/mca/regx/reverse/Makefile
# config.status: creating orte/mca/rmaps/Makefile
# config.status: creating orte/mca/rmaps/mindist/Makefile
# config.status: creating orte/mca/rmaps/ppr/Makefile
# config.status: creating orte/mca/rmaps/rank_file/Makefile
# config.status: creating orte/mca/rmaps/resilient/Makefile
# config.status: creating orte/mca/rmaps/round_robin/Makefile
# config.status: creating orte/mca/rmaps/seq/Makefile
# config.status: creating orte/mca/rml/Makefile
# config.status: creating orte/mca/rml/oob/Makefile
# config.status: creating orte/mca/routed/Makefile
# config.status: creating orte/mca/routed/binomial/Makefile
# config.status: creating orte/mca/routed/direct/Makefile
# config.status: creating orte/mca/routed/radix/Makefile
# config.status: creating orte/mca/rtc/Makefile
# config.status: creating orte/mca/rtc/hwloc/Makefile
# config.status: creating orte/mca/schizo/Makefile
# config.status: creating orte/mca/schizo/flux/Makefile
# config.status: creating orte/mca/schizo/ompi/Makefile
# config.status: creating orte/mca/schizo/orte/Makefile
# config.status: creating orte/mca/schizo/alps/Makefile
# config.status: creating orte/mca/schizo/jsm/Makefile
# config.status: creating orte/mca/schizo/moab/Makefile
# config.status: creating orte/mca/schizo/singularity/Makefile
# config.status: creating orte/mca/schizo/slurm/Makefile
# config.status: creating orte/mca/snapc/Makefile
# config.status: creating orte/mca/snapc/full/Makefile
# config.status: creating orte/mca/sstore/Makefile
# config.status: creating orte/mca/sstore/central/Makefile
# config.status: creating orte/mca/sstore/stage/Makefile
# config.status: creating orte/mca/state/Makefile
# config.status: creating orte/mca/state/app/Makefile
# config.status: creating orte/mca/state/hnp/Makefile
# config.status: creating orte/mca/state/novm/Makefile
# config.status: creating orte/mca/state/orted/Makefile
# config.status: creating orte/mca/state/tool/Makefile
# config.status: creating ompi/mca/common/Makefile
# config.status: creating ompi/mca/common/monitoring/Makefile
# config.status: creating ompi/mca/common/ompio/Makefile
# config.status: creating ompi/mca/bml/Makefile
# config.status: creating ompi/mca/bml/r2/Makefile
# config.status: creating ompi/mca/coll/Makefile
# config.status: creating ompi/mca/coll/adapt/Makefile
# config.status: creating ompi/mca/coll/basic/Makefile
# config.status: creating ompi/mca/coll/han/Makefile
# config.status: creating ompi/mca/coll/inter/Makefile
# config.status: creating ompi/mca/coll/libnbc/Makefile
# config.status: creating ompi/mca/coll/self/Makefile
# config.status: creating ompi/mca/coll/sm/Makefile
# config.status: creating ompi/mca/coll/sync/Makefile
# config.status: creating ompi/mca/coll/tuned/Makefile
# config.status: creating ompi/mca/coll/cuda/Makefile
# config.status: creating ompi/mca/coll/fca/Makefile
# config.status: creating ompi/mca/coll/hcoll/Makefile
# config.status: creating ompi/mca/coll/monitoring/Makefile
# config.status: creating ompi/mca/coll/portals4/Makefile
# config.status: creating ompi/mca/coll/ucc/Makefile
# config.status: creating ompi/mca/crcp/Makefile
# config.status: creating ompi/mca/crcp/bkmrk/Makefile
# config.status: creating ompi/mca/fbtl/Makefile
# config.status: creating ompi/mca/fbtl/ime/Makefile
# config.status: creating ompi/mca/fbtl/posix/Makefile
# config.status: creating ompi/mca/fbtl/pvfs2/Makefile
# config.status: creating ompi/mca/fcoll/Makefile
# config.status: creating ompi/mca/fcoll/dynamic/Makefile
# config.status: creating ompi/mca/fcoll/dynamic_gen2/Makefile
# config.status: creating ompi/mca/fcoll/individual/Makefile
# config.status: creating ompi/mca/fcoll/two_phase/Makefile
# config.status: creating ompi/mca/fcoll/vulcan/Makefile
# config.status: creating ompi/mca/fs/Makefile
# config.status: creating ompi/mca/fs/gpfs/Makefile
# config.status: creating ompi/mca/fs/ime/Makefile
# config.status: creating ompi/mca/fs/lustre/Makefile
# config.status: creating ompi/mca/fs/pvfs2/Makefile
# config.status: creating ompi/mca/fs/ufs/Makefile
# config.status: creating ompi/mca/hook/Makefile
# config.status: creating ompi/mca/io/Makefile
# config.status: creating ompi/mca/io/ompio/Makefile
# config.status: creating ompi/mca/io/romio321/Makefile
# config.status: creating ompi/mca/mtl/Makefile
# config.status: creating ompi/mca/mtl/ofi/Makefile
# config.status: creating ompi/mca/mtl/portals4/Makefile
# config.status: creating ompi/mca/mtl/psm/Makefile
# config.status: creating ompi/mca/mtl/psm2/Makefile
# config.status: creating ompi/mca/op/Makefile
# config.status: creating ompi/mca/op/avx/Makefile
# config.status: creating ompi/mca/osc/Makefile
# config.status: creating ompi/mca/osc/sm/Makefile
# config.status: creating ompi/mca/osc/monitoring/Makefile
# config.status: creating ompi/mca/osc/portals4/Makefile
# config.status: creating ompi/mca/osc/pt2pt/Makefile
# config.status: creating ompi/mca/osc/rdma/Makefile
# config.status: creating ompi/mca/osc/ucx/Makefile
# config.status: creating ompi/mca/pml/Makefile
# config.status: creating ompi/mca/pml/cm/Makefile
# config.status: creating ompi/mca/pml/crcpw/Makefile
# config.status: creating ompi/mca/pml/monitoring/Makefile
# config.status: creating ompi/mca/pml/ob1/Makefile
# config.status: creating ompi/mca/pml/ucx/Makefile
# config.status: creating ompi/mca/pml/v/Makefile
# config.status: creating ompi/mca/pml/yalla/Makefile
# config.status: creating ompi/mca/rte/Makefile
# config.status: creating ompi/mca/rte/pmix/Makefile
# config.status: creating ompi/mca/rte/orte/Makefile
# config.status: creating ompi/mca/sharedfp/Makefile
# config.status: creating ompi/mca/sharedfp/individual/Makefile
# config.status: creating ompi/mca/sharedfp/lockedfile/Makefile
# config.status: creating ompi/mca/sharedfp/sm/Makefile
# config.status: creating ompi/mca/topo/Makefile
# config.status: creating ompi/mca/topo/basic/Makefile
# config.status: creating ompi/mca/topo/treematch/Makefile
# config.status: creating ompi/mca/vprotocol/Makefile
# config.status: creating ompi/mca/vprotocol/pessimist/Makefile
# config.status: creating oshmem/mca/atomic/Makefile
# config.status: creating oshmem/mca/atomic/basic/Makefile
# config.status: creating oshmem/mca/atomic/mxm/Makefile
# config.status: creating oshmem/mca/atomic/ucx/Makefile
# config.status: creating oshmem/mca/memheap/Makefile
# config.status: creating oshmem/mca/memheap/buddy/Makefile
# config.status: creating oshmem/mca/memheap/ptmalloc/Makefile
# config.status: creating oshmem/mca/scoll/Makefile
# config.status: creating oshmem/mca/scoll/basic/Makefile
# config.status: creating oshmem/mca/scoll/mpi/Makefile
# config.status: creating oshmem/mca/scoll/fca/Makefile
# config.status: creating oshmem/mca/scoll/ucc/Makefile
# config.status: creating oshmem/mca/spml/Makefile
# config.status: creating oshmem/mca/spml/ikrit/Makefile
# config.status: creating oshmem/mca/spml/ucx/Makefile
# config.status: creating oshmem/mca/sshmem/Makefile
# config.status: creating oshmem/mca/sshmem/mmap/Makefile
# config.status: creating oshmem/mca/sshmem/sysv/Makefile
# config.status: creating oshmem/mca/sshmem/ucx/Makefile
# config.status: creating oshmem/mca/sshmem/verbs/Makefile
# config.status: creating ompi/mpiext/affinity/Makefile
# config.status: creating ompi/mpiext/affinity/c/Makefile
# config.status: creating ompi/mpiext/cr/Makefile
# config.status: creating ompi/mpiext/cr/c/Makefile
# config.status: creating ompi/mpiext/cuda/Makefile
# config.status: creating ompi/mpiext/cuda/c/Makefile
# config.status: creating ompi/mpiext/pcollreq/Makefile
# config.status: creating ompi/mpiext/pcollreq/c/Makefile
# config.status: creating ompi/mpiext/pcollreq/c/profile/Makefile
# config.status: creating ompi/mpiext/pcollreq/mpif-h/Makefile
# config.status: creating ompi/mpiext/pcollreq/mpif-h/profile/Makefile
# config.status: creating ompi/mpiext/pcollreq/use-mpi/Makefile
# config.status: creating ompi/mpiext/pcollreq/use-mpi-f08/Makefile
# config.status: creating ompi/contrib/libompitrace/Makefile
# config.status: creating Makefile
# config.status: creating config/Makefile
# config.status: creating contrib/Makefile
# config.status: creating contrib/dist/mofed/debian/changelog
# config.status: creating contrib/dist/mofed/debian/control
# config.status: creating contrib/dist/mofed/debian/copyright
# config.status: creating test/Makefile
# config.status: creating test/event/Makefile
# config.status: creating test/asm/Makefile
# config.status: creating test/datatype/Makefile
# config.status: creating test/dss/Makefile
# config.status: creating test/class/Makefile
# config.status: creating test/mpool/Makefile
# config.status: creating test/support/Makefile
# config.status: creating test/threads/Makefile
# config.status: creating test/util/Makefile
# config.status: creating test/monitoring/Makefile
# config.status: creating test/spc/Makefile
# config.status: creating contrib/dist/mofed/debian/rules
# config.status: creating contrib/dist/mofed/compile_debian_mlnx_example
# config.status: creating opal/Makefile
# config.status: creating opal/etc/Makefile
# config.status: creating opal/include/Makefile
# config.status: creating opal/datatype/Makefile
# config.status: creating opal/util/Makefile
# config.status: creating opal/util/keyval/Makefile
# config.status: creating opal/mca/base/Makefile
# config.status: creating opal/tools/wrappers/Makefile
# config.status: creating opal/tools/wrappers/opalcc-wrapper-data.txt
# config.status: creating opal/tools/wrappers/opalc++-wrapper-data.txt
# config.status: creating opal/tools/wrappers/opal.pc
# config.status: creating opal/tools/opal-checkpoint/Makefile
# config.status: creating opal/tools/opal-restart/Makefile
# config.status: creating orte/Makefile
# config.status: creating orte/include/Makefile
# config.status: creating orte/etc/Makefile
# config.status: creating orte/orted/orted-mpir/Makefile
# config.status: creating orte/tools/orted/Makefile
# config.status: creating orte/tools/orterun/Makefile
# config.status: creating orte/tools/wrappers/Makefile
# config.status: creating orte/tools/wrappers/ortecc-wrapper-data.txt
# config.status: creating orte/tools/wrappers/orte.pc
# config.status: creating orte/tools/orte-clean/Makefile
# config.status: creating orte/tools/orte-info/Makefile
# config.status: creating orte/tools/orte-server/Makefile
# config.status: creating ompi/Makefile
# config.status: creating ompi/etc/Makefile
# config.status: creating ompi/include/Makefile
# config.status: creating ompi/include/mpif.h
# config.status: creating ompi/include/mpif-config.h
# config.status: creating ompi/datatype/Makefile
# config.status: creating ompi/debuggers/Makefile
# config.status: creating ompi/mpi/c/Makefile
# config.status: creating ompi/mpi/c/profile/Makefile
# config.status: creating ompi/mpi/cxx/Makefile
# config.status: creating ompi/mpi/fortran/base/Makefile
# config.status: creating ompi/mpi/fortran/mpif-h/Makefile
# config.status: creating ompi/mpi/fortran/mpif-h/profile/Makefile
# config.status: creating ompi/mpi/fortran/use-mpi-tkr/Makefile
# config.status: creating ompi/mpi/fortran/use-mpi-tkr/fortran_sizes.h
# config.status: creating ompi/mpi/fortran/use-mpi-tkr/fortran_kinds.sh
# config.status: creating ompi/mpi/fortran/use-mpi-ignore-tkr/Makefile
# config.status: creating ompi/mpi/fortran/use-mpi-ignore-tkr/mpi-ignore-tkr-interfaces.h
# config.status: creating ompi/mpi/fortran/use-mpi-ignore-tkr/mpi-ignore-tkr-file-interfaces.h
# config.status: creating ompi/mpi/fortran/use-mpi-ignore-tkr/mpi-ignore-tkr-removed-interfaces.h
# config.status: creating ompi/mpi/fortran/use-mpi-f08/Makefile
# config.status: creating ompi/mpi/fortran/use-mpi-f08/base/Makefile
# config.status: creating ompi/mpi/fortran/use-mpi-f08/bindings/Makefile
# config.status: creating ompi/mpi/fortran/use-mpi-f08/mod/Makefile
# config.status: creating ompi/mpi/fortran/mpiext-use-mpi/Makefile
# config.status: creating ompi/mpi/fortran/mpiext-use-mpi-f08/Makefile
# config.status: creating ompi/mpi/tool/Makefile
# config.status: creating ompi/mpi/tool/profile/Makefile
# config.status: creating ompi/tools/ompi_info/Makefile
# config.status: creating ompi/tools/wrappers/Makefile
# config.status: creating ompi/tools/wrappers/mpicc-wrapper-data.txt
# config.status: creating ompi/tools/wrappers/mpic++-wrapper-data.txt
# config.status: creating ompi/tools/wrappers/mpifort-wrapper-data.txt
# config.status: creating ompi/tools/wrappers/ompi.pc
# config.status: creating ompi/tools/wrappers/ompi-c.pc
# config.status: creating ompi/tools/wrappers/ompi-cxx.pc
# config.status: creating ompi/tools/wrappers/ompi-fort.pc
# config.status: creating ompi/tools/wrappers/mpijavac.pl
# config.status: creating ompi/tools/mpisync/Makefile
# config.status: creating oshmem/Makefile
# config.status: creating oshmem/include/Makefile
# config.status: creating oshmem/shmem/c/Makefile
# config.status: creating oshmem/shmem/c/profile/Makefile
# config.status: creating oshmem/shmem/fortran/Makefile
# config.status: creating oshmem/shmem/fortran/profile/Makefile
# config.status: creating oshmem/tools/oshmem_info/Makefile
# config.status: creating oshmem/tools/wrappers/Makefile
# config.status: creating oshmem/tools/wrappers/shmemcc-wrapper-data.txt
# config.status: creating oshmem/tools/wrappers/shmemc++-wrapper-data.txt
# config.status: creating oshmem/tools/wrappers/shmemfort-wrapper-data.txt
# config.status: creating opal/include/opal_config.h
# config.status: creating ompi/include/mpi.h
# config.status: creating oshmem/include/shmem.h
# config.status: creating opal/mca/hwloc/hwloc201/hwloc/include/private/autogen/config.h
# config.status: creating opal/mca/hwloc/hwloc201/hwloc/include/hwloc/autogen/config.h
# config.status: creating ompi/mpiext/cuda/c/mpiext_cuda_c.h
# config.status: executing depfiles commands
# config.status: executing opal/mca/event/libevent2022/libevent/include/event2/event-config.h commands
# config.status: executing ompi/mca/osc/monitoring/osc_monitoring_template_gen.h commands
# config.status: executing libtool commands
# configure: WARNING: unrecognized options: --with-rocm
# 
# Open MPI configuration:
# -----------------------
# Version: 4.1.8
# Build MPI C bindings: yes
# Build MPI C++ bindings (deprecated): no
# Build MPI Fortran bindings: mpif.h, use mpi, use mpi_f08
# MPI Build Java bindings (experimental): no
# Build Open SHMEM support: yes
# Debug build: no
# Platform file: (none)
# 
# Miscellaneous
# -----------------------
# CUDA support: yes
# HWLOC support: internal
# Libevent support: internal
# Open UCC: no
# PMIx support: Internal
#  
# Transports
# -----------------------
# Cisco usNIC: no
# Cray uGNI (Gemini/Aries): no
# Intel Omnipath (PSM2): no
# Intel TrueScale (PSM): no
# Mellanox MXM: no
# Open UCX: yes
# OpenFabrics OFI Libfabric: no
# OpenFabrics Verbs: yes
# Portals4: no
# Shared memory/copy in+copy out: yes
# Shared memory/Linux CMA: yes
# Shared memory/Linux KNEM: no
# Shared memory/XPMEM: no
# TCP: yes
#  
# Resource Managers
# -----------------------
# Cray Alps: no
# Grid Engine: no
# LSF: no
# Moab: no
# Slurm: yes
# ssh/rsh: yes
# Torque: no
#  
# OMPIO File Systems
# -----------------------
# DDN Infinite Memory Engine: no
# Generic Unix FS: yes
# IBM Spectrum Scale/GPFS: no
# Lustre: no
# PVFS2/OrangeFS: no

    eval $CMD
    make clean ; make -j 32
    make install
}

