add_installation_to_path() {
    local name=$1
    local version=$2
    local install_root=$3

    # Check if we have --quiet option in the end of the command
    # If yes, set QUIET=1 and remove it from the arguments
    # If  no, set QUIET=0

    if [ "$#" -eq 4 ]; then
        if [ "$4" == "--quiet" ]; then
            QUIET=1
        else
            echo -e "\e[31mERROR: Invalid argument $4. Use --quiet to suppress output.\e[0m"
            return 1
        fi
    else
        QUIET=0
    fi

    local install_dir="${install_root}/${name}/${version}"
    if [ ! -d "${install_dir}" ]; then
        echo -e "\e[31mERROR IN PATH ADDITION: ${install_dir} DOES NOT EXIST !!!!\e[0m"; return
    else
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

        # If not quiet, print the installation directory
        if [ $QUIET -eq 0 ]; then
            # Front-fill with spaces so all names are aligned
            local name_length=${#name}
            local spaces=$(( 15 - name_length ))
            local spaces_string=$(printf "%${spaces}s" " ")
            spaces_string=${spaces_string// / }

            # echo -e "\e[32mAdded path to ${spaces_string} ${version} \e[0m"
            # Fix bug above
            echo -e "\e[32mAdded path to ${name} ${spaces_string} ${version} \e[0m"
        fi
    fi 
}

remove_all_installation_paths(){
    PATH=/home/sambit/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin
    unset CPATH
    unset CPPATH
    unset LDPATH
    unset LIBRARY_PATH
    unset LD_LIBRARY_PATH
    unset PKG_CONFIG_PATH
}
