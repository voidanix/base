#!/bin/sh
if [ "$_" != "$0" ]; then REDECLIPSE_EXITU="return"; else REDECLIPSE_EXITU="exit"; fi

function redeclipse_update_path {
    if [ -z "${REDECLIPSE_PATH+isset}" ]; then REDECLIPSE_PATH="$(cd "$(dirname "$0")" && pwd)"; fi
}

function redeclipse_update_init {
    if [ -z "${REDECLIPSE_CACHE+isset}" ]; then
        REDECLIPSE_CACHE="${HOME}/.redeclipse/cache"
    fi
}

function redeclipse_update_start {
    if [ -z "${REDECLIPSE_SOURCE+isset}" ]; then REDECLIPSE_SOURCE="http://redeclipse.net/files"; fi
    if [ -z "${REDECLIPSE_GITHUB+isset}" ]; then REDECLIPSE_GITHUB="https://github.com/red-eclipse"; fi
    if [ -z "${REDECLIPSE_BRANCH+isset}" ]; then
       REDECLIPSE_BRANCH="stable"
        if [ -d ".git" ]; then REDECLIPSE_BRANCH="devel"; fi
        if [ -a "${REDECLIPSE_PATH}/bin/branch.txt" ]; then REDECLIPSE_BRANCH=`cat "${REDECLIPSE_PATH}/bin/branch.txt"`; fi
    fi
    if [ "${REDECLIPSE_BRANCH}" != "stable" ] && [ "${REDECLIPSE_BRANCH}" != "devel" ]; then
        echo "Unsupported update branch: \"${REDECLIPSE_BRANCH}\""
        return 1
    fi
    if [ "${REDECLIPSE_BRANCH}" != "stable" ]; then
        REDECLIPSE_UPDATE="${REDECLIPSE_BRANCH}"
        REDECLIPSE_TEMP="${REDECLIPSE_CACHE}/${REDECLIPSE_BRANCH}"
    else
        if [ ! -a "${REDECLIPSE_PATH}/bin/version.txt" ]; then
            echo "Unable to find ${REDECLIPSE_PATH}/bin/version.txt"
            return 1
        fi
        REDECLIPSE_BINVER=`cat "${REDECLIPSE_PATH}/bin/version.txt"`
        if [ -z "${REDECLIPSE_BINVER}" ]; then
            echo "Cannot determine current stable bins version."
            return 1
        fi
        REDECLIPSE_UPDATE="${REDECLIPSE_BRANCH}/${REDECLIPSE_BINVER}"
        REDECLIPSE_TEMP="${REDECLIPSE_CACHE}/${REDECLIPSE_BRANCH}/${REDECLIPSE_BINVER}"
    fi
    case "${REDECLIPSE_TARGET}" in
        windows)
            REDECLIPSE_BLOB="zipball"
            REDECLIPSE_ARCHIVE="windows.zip"
            ;;
        *)
            REDECLIPSE_BLOB="tarball"
            REDECLIPSE_ARCHIVE="linux.tar.bz2"
            ;;
    esac
    redeclipse_update_branch
    return $?
}

function redeclipse_update_branch {
    echo "Branch: ${REDECLIPSE_UPDATE}"
    echo "Folder: ${REDECLIPSE_PATH}"
    echo "Cached: ${REDECLIPSE_TEMP}"
    if [ -z `which wget` ]; then
        echo "Unable to find wget, are you sure you have it installed?"
        return 1
    fi
    REDECLIPSE_WGET="wget --continue --no-check-certificate --user-agent=\"redeclipse-${REDECLIPSE_UPDATE}\""
    if [ "${REDECLIPSE_TARGET}" = "windows" ]; then
        if [ -z `which unzip` ]; then
            echo "Unable to find unzip, are you sure you have it installed?"
            return 1
        fi
        REDECLIPSE_UNZIP="unzip -o"
    fi
    if [ -z `which tar` ]; then
        echo "Unable to find tar, are you sure you have it installed?"
        return 1
    fi
    REDECLIPSE_TAR="tar --bzip2 --extract --verbose --overwrite"
    if [ -z `which git` ]; then
        echo "Unable to find git, are you sure you have it installed?"
        return 1
    fi
    REDECLIPSE_GITAPPLY="git apply --ignore-space-change --ignore-whitespace --verbose --stat --apply"
    if [ ! -d "${REDECLIPSE_TEMP}" ]; then mkdir -p "${REDECLIPSE_TEMP}"; fi
    echo "#"'!'"/bin/sh" > "${REDECLIPSE_TEMP}/install.sh"
    echo "REDECLIPSE_ERROR=\"false\"" >> "${REDECLIPSE_TEMP}/install.sh"
    if [ "${REDECLIPSE_BRANCH}" != "stable" ]; then
        redeclipse_update_bins
        return $?
    fi
    redeclipse_update_base
    return $?
}

function redeclipse_update_base {
    echo ""
    if [ -a "${REDECLIPSE_PATH}/bin/base.txt" ]; then REDECLIPSE_BASE=`cat "${REDECLIPSE_PATH}/bin/base.txt"`; fi
    if [ -z "${REDECLIPSE_BASE}" ]; then REDECLIPSE_BASE="none"; fi
    echo "[I] base: ${REDECLIPSE_BASE}"
    REDECLIPSE_BASE_CACHED="none"
    if [ ! -a "${REDECLIPSE_TEMP}/base.txt" ]; then
        redeclipse_update_baseget
        return $?
    fi
    REDECLIPSE_BASE_CACHED=`cat "${REDECLIPSE_TEMP}/base.txt"`
    if [ -z "${REDECLIPSE_BASE_CACHED}" ]; then REDECLIPSE_BASE_CACHED="none"; fi
    echo "[C] base: ${REDECLIPSE_BASE_CACHED}"
    rm -f "${REDECLIPSE_TEMP}/base.txt"
    redeclipse_update_baseget
    return $?
}

function redeclipse_update_baseget {
    ${REDECLIPSE_WGET} --output-document="${REDECLIPSE_TEMP}/base.txt" "${REDECLIPSE_SOURCE}/${REDECLIPSE_UPDATE}/base.txt" > /dev/null 2>&1
    if [ ! -a "${REDECLIPSE_TEMP}/base.txt" ]; then
        echo "Failed to retrieve base update information."
        redeclipse_update_data
        return $?
    fi
    REDECLIPSE_BASE_REMOTE=`cat "${REDECLIPSE_TEMP}/base.txt"`
    if [ -z "${REDECLIPSE_BASE_REMOTE}" ]; then
        echo "Failed to retrieve base update information."
        redeclipse_update_data
        return $?
    fi
    echo "[R] base: ${REDECLIPSE_BASE_REMOTE}"
    if [ "${REDECLIPSE_BASE_REMOTE}" = "${REDECLIPSE_BASE}" ]; then
        redeclipse_update_data
        return $?
    fi
    if [ "${REDECLIPSE_BASE}" = "none" ]; then
        redeclipse_update_baseblob
        return $?
    fi
    redeclipse_update_basepatch
    return $?
}

function redeclipse_update_basepatch {
    if [ -a "${REDECLIPSE_TEMP}/base.patch" ]; then rm -f "${REDECLIPSE_TEMP}/base.patch"; fi
    if [ -a "${REDECLIPSE_TEMP}/base.zip" ]; then rm -f "${REDECLIPSE_TEMP}/base.zip"; fi
    echo "[D] base: ${REDECLIPSE_GITHUB}/base/compare/${REDECLIPSE_BASE}...${REDECLIPSE_BASE_REMOTE}.patch"
    echo ""
    ${REDECLIPSE_WGET} --output-document="${REDECLIPSE_TEMP}/base.patch" "${REDECLIPSE_GITHUB}/base/compare/${REDECLIPSE_BASE}...${REDECLIPSE_BASE_REMOTE}.patch"
    if [ ! -a "${REDECLIPSE_TEMP}/base.patch" ]; then
        echo "Failed to retrieve base update package. Downloading full zip instead."
        redeclipse_update_baseblob
        return $?
    fi
    redeclipse_update_basepatchdeploy
    return $?
}

function redeclipse_update_basepatchdeploy {
    return 0
    echo "${REDECLIPSE_GITAPPLY} --directory=\"${REDECLIPSE_PATH}\" \"${REDECLIPSE_TEMP}/base.patch\" && (" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    echo \"${REDECLIPSE_BASE_REMOTE}\" > \"${REDECLIPSE_PATH}/bin/base.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo ") || (" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    echo \"none\" > \"${REDECLIPSE_PATH}/bin/base.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    rm -f \"${REDECLIPSE_TEMP}/base.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    REDECLIPSE_ERROR=\"true\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo ")"
    REDECLIPSE_DEPLOY="true"
    redeclipse_update_data
    return $?
}

function redeclipse_update_baseblob {
    if [ -a "${REDECLIPSE_TEMP}/base.zip" ]; then
        if [ "${REDECLIPSE_BASE_CACHED}" = "${REDECLIPSE_BASE_REMOTE}" ]; then
            echo "[F] base: Using cached file \"${REDECLIPSE_TEMP}/base.zip\""
            redeclipse_update_baseblobdeploy
            return $?
        else
            rm -f "${REDECLIPSE_TEMP}/base.zip"
        fi
    fi
    echo "[D] base: ${REDECLIPSE_GITHUB}/base/${REDECLIPSE_BLOB}/${REDECLIPSE_BASE_REMOTE}"
    echo ""
    ${REDECLIPSE_WGET} --output-document="${REDECLIPSE_TEMP}/base.zip" "${REDECLIPSE_GITHUB}/base/${REDECLIPSE_BLOB}/${REDECLIPSE_BASE_REMOTE}"
    if [ ! -a "${REDECLIPSE_TEMP}/base.zip" ]; then
        echo "Failed to retrieve base update package."
        redeclipse_update_data
        return $?
    fi
    redeclipse_update_baseblobdeploy
    return $?
}

function redeclipse_update_baseblobdeploy {
    return 0
    if [ "${REDECLIPSE_BLOB}" = "zipball" ]; then
        echo "${REDECLIPSE_UNZIP} -o \"${REDECLIPSE_TEMP}/base.zip\" -d \"${REDECLIPSE_TEMP}\" && (" >> "${REDECLIPSE_TEMP}/install.sh"
    else
        echo "${REDECLIPSE_TAR} --file=\"${REDECLIPSE_TEMP}/base.zip\" --directory=\"${REDECLIPSE_TEMP}\" && (" >> "${REDECLIPSE_TEMP}/install.sh"
    fi
    echo "   copy --recursive --force --verbose \"${REDECLIPSE_TEMP}/red-eclipse-base-${REDECLIPSE_BASE_REMOTE:0:7}/*\" \"${REDECLIPSE_PATH}\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "   rm -rf \"${REDECLIPSE_TEMP}/red-eclipse-base-${REDECLIPSE_BASE_REMOTE:0:7}\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "   echo \"${REDECLIPSE_BASE_REMOTE}\" > \"${REDECLIPSE_PATH}/bin/base.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo ") || (" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    rm -f \"${REDECLIPSE_TEMP}/base.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    REDECLIPSE_ERROR=\"true\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo ")"
    REDECLIPSE_DEPLOY="true"
    redeclipse_update_data
    return $?
}

function redeclipse_update_data {
    echo ""
    if  [ -a "${REDECLIPSE_PATH}/data/readme.txt" ]; then 
        redeclipse_update_dataver
        return $?
    fi
    echo "Unable to find \"data/readme.txt\". Will start from scratch."
    REDECLIPSE_DATA="none"
    echo "mkdir -p \"${REDECLIPSE_PATH}/data\"" >> "${REDECLIPSE_TEMP}/install.sh"
    redeclipse_update_dataget
    return $?
}

function redeclipse_update_dataver {
    echo ""
    if [ -a "${REDECLIPSE_PATH}/bin/data.txt" ]; then REDECLIPSE_DATA=`cat "${REDECLIPSE_PATH}/bin/data.txt"`; fi
    if [ -z "${REDECLIPSE_DATA}" ]; then REDECLIPSE_DATA="none"; fi
    echo "[I] data: ${REDECLIPSE_DATA}"
    REDECLIPSE_DATA_CACHED="none"
    if [ ! -a "${REDECLIPSE_TEMP}/data.txt" ]; then
        redeclipse_update_dataget
        return $?
    fi
    REDECLIPSE_DATA_CACHED=`cat "${REDECLIPSE_TEMP}/data.txt"`
    if [ -z "${REDECLIPSE_DATA_CACHED}" ]; then REDECLIPSE_DATA_CACHED="none"; fi
    echo "[C] data: ${REDECLIPSE_DATA_CACHED}"
    rm -f "${REDECLIPSE_TEMP}/data.txt"
    redeclipse_update_dataget
    return $?
}

function redeclipse_update_dataget {
    ${REDECLIPSE_WGET} --output-document="${REDECLIPSE_TEMP}/data.txt" "${REDECLIPSE_SOURCE}/${REDECLIPSE_UPDATE}/data.txt" > /dev/null 2>&1
    if [ ! -a "${REDECLIPSE_TEMP}/data.txt" ]; then
        echo "Failed to retrieve data update information."
        redeclipse_update_bins
        return $?
    fi
    REDECLIPSE_DATA_REMOTE=`cat "${REDECLIPSE_TEMP}/data.txt"`
    if [ -z "${REDECLIPSE_DATA_REMOTE}" ]; then
        echo "Failed to retrieve data update information."
        redeclipse_update_bins
        return $?
    fi
    echo "[R] data: ${REDECLIPSE_DATA_REMOTE}"
    if [ "${REDECLIPSE_DATA_REMOTE}" = "${REDECLIPSE_DATA}" ]; then
        redeclipse_update_bins
        return $?
    fi
    if [ "${REDECLIPSE_DATA}" = "none" ]; then
        redeclipse_update_datablob
        return $?
    fi
    redeclipse_update_datapatch
    return $?
}

function redeclipse_update_datapatch {
    if [ -a "${REDECLIPSE_TEMP}/data.patch" ]; then rm -f "${REDECLIPSE_TEMP}/data.patch"; fi
    if [ -a "${REDECLIPSE_TEMP}/data.zip" ]; then rm -f "${REDECLIPSE_TEMP}/data.zip"; fi
    echo "[D] data: ${REDECLIPSE_GITHUB}/data/compare/${REDECLIPSE_DATA}...${REDECLIPSE_DATA_REMOTE}.patch"
    echo ""
    ${REDECLIPSE_WGET} --output-document="${REDECLIPSE_TEMP}/data.patch" "${REDECLIPSE_GITHUB}/data/compare/${REDECLIPSE_DATA}...${REDECLIPSE_DATA_REMOTE}.patch"
    if [ ! -a "${REDECLIPSE_TEMP}/data.patch" ]; then
        echo "Failed to retrieve data update package. Downloading full zip instead."
        redeclipse_update_datablob
        return $?
    fi
    redeclipse_update_datapatchdeploy
    return $?
}

function redeclipse_update_datapatchdeploy {
    return 0
    echo "${REDECLIPSE_GITAPPLY} --directory=\"${REDECLIPSE_PATH}/data\" \"${REDECLIPSE_TEMP}/data.patch\" && (" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    echo \"${REDECLIPSE_DATA_REMOTE}\" > \"${REDECLIPSE_PATH}/bin/data.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo ") || (" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    echo \"none\" > \"${REDECLIPSE_PATH}/bin/data.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    rm -f \"${REDECLIPSE_TEMP}/data.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    REDECLIPSE_ERROR=\"true\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo ")"
    REDECLIPSE_DEPLOY="true"
    redeclipse_update_bins
    return $?
}

function redeclipse_update_datablob {
    if [ -a "${REDECLIPSE_TEMP}/data.zip" ]; then
        if [ "${REDECLIPSE_DATA_CACHED}" = "${REDECLIPSE_DATA_REMOTE}" ]; then
            echo "[F] data: Using cached file \"${REDECLIPSE_TEMP}/data.zip\""
            redeclipse_update_datablobdeploy
            return $?
        else
            rm -f "${REDECLIPSE_TEMP}/data.zip"
        fi
    fi
    echo "[D] data: ${REDECLIPSE_GITHUB}/data/${REDECLIPSE_BLOB}/${REDECLIPSE_DATA_REMOTE}"
    echo ""
    ${REDECLIPSE_WGET} --output-document="${REDECLIPSE_TEMP}/data.zip" "${REDECLIPSE_GITHUB}/data/${REDECLIPSE_BLOB}/${REDECLIPSE_DATA_REMOTE}"
    if [ ! -a "${REDECLIPSE_TEMP}/data.zip" ]; then
        echo "Failed to retrieve data update package."
        redeclipse_update_bins
        return $?
    fi
    redeclipse_update_datablobdeploy
    return $?
}

function redeclipse_update_datablobdeploy {
    return 0
    if [ "${REDECLIPSE_BLOB}" = "zipball" ]; then
        echo "${REDECLIPSE_UNZIP} -o \"${REDECLIPSE_TEMP}/data.zip\" -d \"${REDECLIPSE_TEMP}\" && (" >> "${REDECLIPSE_TEMP}/install.sh"
    else
        echo "${REDECLIPSE_TAR} --file=\"${REDECLIPSE_TEMP}/data.zip\" --directory=\"${REDECLIPSE_TEMP}\" && (" >> "${REDECLIPSE_TEMP}/install.sh"
    fi
    echo "   copy --recursive --force --verbose \"${REDECLIPSE_TEMP}/red-eclipse-data-${REDECLIPSE_DATA_REMOTE:0:7}/*\" \"${REDECLIPSE_PATH}/data\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "   rm -rf \"${REDECLIPSE_TEMP}/red-eclipse-data-${REDECLIPSE_DATA_REMOTE:0:7}\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "   echo \"${REDECLIPSE_DATA_REMOTE}\" > \"${REDECLIPSE_PATH}/bin/data.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo ") || (" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    rm -f \"${REDECLIPSE_TEMP}/data.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    REDECLIPSE_ERROR=\"true\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo ")"
    REDECLIPSE_DEPLOY="true"
    redeclipse_update_bins
    return $?
}

function redeclipse_update_bins {
    echo ""
    if [ -a "${REDECLIPSE_PATH}/bin/bins.txt" ]; then REDECLIPSE_BINS=`cat "${REDECLIPSE_PATH}/bin/bins.txt"`; fi
    if [ -z "${REDECLIPSE_BINS}" ]; then REDECLIPSE_BINS="none"; fi
    echo "[I] bins: ${REDECLIPSE_BINS}"
    REDECLIPSE_BINS_CACHED="none"
    if [ ! -a "${REDECLIPSE_TEMP}/bins.txt" ]; then
        redeclipse_update_binsget
        return $?
    fi
    REDECLIPSE_BINS_CACHED=`cat "${REDECLIPSE_TEMP}/bins.txt"`
    if [ -z "${REDECLIPSE_BINS_CACHED}" ]; then REDECLIPSE_BINS_CACHED="none"; fi
    echo "[C] bins: ${REDECLIPSE_BINS_CACHED}"
}

function redeclipse_update_binsget {
    ${REDECLIPSE_WGET} --output-document="${REDECLIPSE_TEMP}/bins.txt" "${REDECLIPSE_SOURCE}/${REDECLIPSE_UPDATE}/bins.txt" > /dev/null 2>&1
    if [ ! -a "${REDECLIPSE_TEMP}/bins.txt" ]; then
        echo "Failed to retrieve bins update information."
        redeclipse_update_deploy
        return $?
    fi
    REDECLIPSE_BINS_REMOTE=`cat "${REDECLIPSE_TEMP}/bins.txt"`
    if [ -z "${REDECLIPSE_BINS_REMOTE}" ]; then
        echo "Failed to retrieve bins update information."
        redeclipse_update_deploy
        return $?
    fi
    echo "[R] bins: ${REDECLIPSE_BINS_REMOTE}"
    if [ "${REDECLIPSE_TRYUPDATE}" != "true" ] && [ "${REDECLIPSE_BINS_REMOTE}" = "${REDECLIPSE_BINS}" ]; then
        redeclipse_update_deploy
        return $?
    fi
}

function redeclipse_update_binsblob {
    if [ -a "${REDECLIPSE_TEMP}/${REDECLIPSE_ARCHIVE}" ]; then
        if [ "${REDECLIPSE_BINS_CACHED}" = "${REDECLIPSE_BINS_REMOTE}" ]; then
            echo "[F] bins: Using cached file \"${REDECLIPSE_TEMP}/${REDECLIPSE_ARCHIVE}\""
            redeclipse_update_binsdeploy
            return $?
        else
            rm -f "${REDECLIPSE_TEMP}/${REDECLIPSE_ARCHIVE}"
        fi
    fi
    echo "[D] bins: ${REDECLIPSE_SOURCE}/${REDECLIPSE_UPDATE}/${REDECLIPSE_ARCHIVE}"
    echo ""
    ${REDECLIPSE_WGET} --output-document="${REDECLIPSE_TEMP}/${REDECLIPSE_ARCHIVE}" "${REDECLIPSE_SOURCE}/${REDECLIPSE_UPDATE}/${REDECLIPSE_ARCHIVE}"
    if [ ! -a "${REDECLIPSE_TEMP}/${REDECLIPSE_ARCHIVE}" ]; then
        echo "Failed to retrieve bins update package."
        redeclipse_update_deploy
        return $?
    fi
}

function redeclipse_update_binsdeploy {
    if [ "${REDECLIPSE_BLOB}" = "zipball" ]; then
        echo "${REDECLIPSE_UNZIP} -o \"${REDECLIPSE_TEMP}/${REDECLIPSE_ARCHIVE}\" -d \"${REDECLIPSE_PATH}\" && (" >> "${REDECLIPSE_TEMP}/install.sh"
    else
        echo "${REDECLIPSE_TAR} --file=\"${REDECLIPSE_TEMP}/${REDECLIPSE_ARCHIVE}\" --directory=\"${REDECLIPSE_PATH}\" && (" >> "${REDECLIPSE_TEMP}/install.sh"
    fi
    echo "    echo \"${REDECLIPSE_BINS_REMOTE}\" > \"${REDECLIPSE_PATH}/bin/bins.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo ") || (" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    rm -f \"${REDECLIPSE_TEMP}/bins.txt\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "    REDECLIPSE_ERROR=\"true\"" >> "${REDECLIPSE_TEMP}/install.sh"
    echo ")"
    REDECLIPSE_DEPLOY="true"
}

function redeclipse_update_deploy {
    echo ""
    if [ "${REDECLIPSE_DEPLOY}" != "true" ]; then
        echo "Everything is already up to date."
        return 0
    fi
    echo "if [ \"\${REDECLIPSE_ERROR}\" = \"true\" ]; then return 1; else return 0; fi" >> "${REDECLIPSE_TEMP}/install.sh"
    echo "Deploying: \"${REDECLIPSE_TEMP}/install.sh\""
    REDECLIPSE_INSTALL="exec"
    touch test.tmp && (
        rm -f test.tmp
        redeclipse_update_unpack
        return $?
    )
    echo "Administrator permissions are required to deploy the files."
    if [ -z `which sudo` ]; then
        echo "Unable to find sudo, are you sure it is installed?"
        redeclipse_update_unpack
        return $?
    fi
    REDECLIPSE_INSTALL="sudo"
}

function redeclipse_update_unpack {
    ${REDECLIPSE_INSTALL} "${REDECLIPSE_TEMP}/install.sh" && (
        echo ""
        echo "Updated successfully."
        echo "${REDECLIPSE_BRANCH}" > "${REDECLIPSE_PATH}/bin/branch.txt"
        ${REDECLIPSE_EXITU} 0
    ) || (
        echo ""
        echo "There was an error deploying the files."
        ${REDECLIPSE_EXITU} 1
    )
}

redeclipse_update_path
redeclipse_update_init
if [ $? -ne 0 ]; then
    ${REDECLIPSE_EXITR} 1
else
    ${REDECLIPSE_EXITR} 0
fi