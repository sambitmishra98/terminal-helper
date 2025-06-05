# Helper: locate cubic mesh files by parameters
# Usage: source cube-mesh-linker.sh then call setup_cube_mesh <etype> <order> <dofs> <parts>
# Requires: PYFRM_MESHES_CUBIC variable


setup_cube_mesh(){

local testetype=$1
local testorder=$2
local testdofs=$3
local testparts=$4
  
# Check if PYFRM_MESHES_CUBIC is set
if [ -z "$PYFRM_MESHES_CUBIC" ]; then
  echo "Error: PYFRM_MESHES_CUBIC is not set. Please set it to the path of your mesh files."
  exit 1
fi

if [ -z "$testetype" ] || [ -z "$testorder" ] || [ -z "$testdofs" ] || [ -z "$testparts" ]; then
  echo "Error: Missing parameters. Usage: $0 <etype> <order> <dofs> <parts>"
  exit 1
fi

# Return the mesh file path
# return "${$PYFRM_MESHES_CUBIC}/etype-${testetype}_order-${testorder}_dof-${testdofs}.pyfrm"
# Above gave bad substitution error
# Use the following instead
echo "${PYFRM_MESHES_CUBIC}/etype-${testetype}_order-${testorder}_dof-${testdofs}.pyfrm"


}