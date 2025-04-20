add_installation_to_path() {
    local name=$1
    local version=$2
    local install_root=$3
    local install_dir="${install_root}/${name}/${version}"
    if [ ! -d "${install_dir}" ]; then
        echo -e "\e[31mERROR IN PATH ADDITION: ${install_dir} DOES NOT EXIST !!!!\e[0m"; return
    else
        echo -e "\e[32mAdding ${name} installation at ${install_dir} to PATH\e[0m"
        [ -d "${install_dir}/bin"           ] && export            PATH="${install_dir}/bin:$PATH"
        [ -d "${install_dir}/include"       ] && export           CPATH="${install_dir}/include:$CPATH"
        [ -d "${install_dir}/include"       ] && export          CPPATH="${install_dir}/include:$CPPATH"
        [ -d "${install_dir}/lib"           ] && export          LDPATH="${install_dir}/lib:$LDPATH"
        [ -d "${install_dir}/lib64"         ] && export          LDPATH="${install_dir}/lib64:$LDPATH"
        [ -d "${install_dir}/lib"           ] && export    LIBRARY_PATH="${install_dir}/lib:$LIBRARY_PATH"
        [ -d "${install_dir}/lib64"         ] && export    LIBRARY_PATH="${install_dir}/lib64:$LIBRARY_PATH"
        [ -d "${install_dir}/lib"           ] && export LD_LIBRARY_PATH="${install_dir}/lib:$LD_LIBRARY_PATH"
        [ -d "${install_dir}/lib64"         ] && export LD_LIBRARY_PATH="${install_dir}/lib64:$LD_LIBRARY_PATH"
        [ -d "${install_dir}/lib/pkgconfig" ] && export PKG_CONFIG_PATH="${install_dir}/lib/pkgconfig:$PKG_CONFIG_PATH"
    fi 
}
