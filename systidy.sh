#!/bin/bash

#    SysTidy - safe system cache, temp-file & log-rotation script
#    Copyright (c) 2026 Raman Singh Kushwaha (Hemant)
#    Licensed under the MIT License. See the LICENSE file for details.
#
#    SysTidy is a housekeeping tool, not an anti-forensics tool.
#    It intentionally never touches security/audit logs
#    (auth.log, secure, wtmp, btmp, lastlog, syslog, journal, ...)
#    or shell history files. Those records exist to show who did
#    what and when on a system; wiping them is a different job
#    entirely, and not one this script does. See README.md for why.

export status="true" version="1.0.0" banner="yes" DO="shell" DRYRUN="no" CLEAN=()
export reset="\033[0m" red="\033[0;31m" green="\033[0;32m" blue="\033[0;34m" purple="\033[0;35m" Bcyan="\033[1;36m" Bwhite="\033[1;37m"
export TEMP_AGE_DAYS="7"

# Temp locations that are always safe to sweep of old files.
export TEMP_DIRS=(
    "/tmp"
    "/var/tmp"
    "${HOME}/.cache"
)

# Only YOUR OWN application log patterns belong here, and only
# ones you're comfortable losing. Do NOT add auth.log, secure,
# wtmp, btmp, lastlog, syslog, kern.log, messages, journal, or
# anything else that records logins, sessions, or commands - that
# turns a cleaner into a cover-your-tracks tool.
export APP_LOGS=(
    "${HOME}/.local/share/*/logs/*.log.gz"
    "${HOME}/.local/share/*/logs/*.log.1"
)

export req=(
    "rm"
    "find"
    "cut"
)

# Check requirements:

for chk in "${req[@]}" ; do
    if ! command -v "${chk}" &> /dev/null ; then
        echo -e "\t${Bwhite}${0##*/}${reset}: command: '${chk}' ${red}not${reset} found.."
        export status="false"
    fi
done

if [[ "${status}" = "false" ]] ; then
    exit 1
fi

# Define functions:

systidy:banner() {
    echo -e "${green}
   _____           _______ _     _
  / ____|         |__   __(_)   | |
 | (___  _   _ ___   | |   _  __| |_   _
  \\___ \\| | | / __|  | |  | |/ _\` | | | |
  ____) | |_| \\__ \\  | |  | | (_| | |_| |
 |_____/ \\__, |___/  |_|  |_|\\__,_|\\__, |
          __/ |                    __/ |
         |___/                    |___/${reset}
        ${Bcyan}safe system, cache & temp-file housekeeping${reset}
"
}

systidy:clean:cache() {
    if [[ "${UID}" != 0 ]] ; then
        echo -e "Authorization ${red}failure${reset}, please run it as ${purple}root${reset} to clean package caches."
        return 1
    fi
    if [[ "${banner}" = "yes" ]] ; then
        systidy:banner
    fi
    if command -v apt-get &> /dev/null ; then
        if [[ "${DRYRUN}" = "yes" ]] ; then
            echo -e "${blue}[dry-run]${reset} would run: ${Bcyan}apt-get clean${reset}"
        else
            apt-get clean && echo -e "${green}apt${reset} package cache ${purple}cleaned${reset}."
        fi
    elif command -v yum &> /dev/null ; then
        if [[ "${DRYRUN}" = "yes" ]] ; then
            echo -e "${blue}[dry-run]${reset} would run: ${Bcyan}yum clean all${reset}"
        else
            yum clean all && echo -e "${green}yum${reset} package cache ${purple}cleaned${reset}."
        fi
    elif command -v pacman &> /dev/null ; then
        if [[ "${DRYRUN}" = "yes" ]] ; then
            echo -e "${blue}[dry-run]${reset} would run: ${Bcyan}pacman -Sc --noconfirm${reset}"
        else
            pacman -Sc --noconfirm && echo -e "${green}pacman${reset} package cache ${purple}cleaned${reset}."
        fi
    else
        echo -e "No supported package manager (${Bcyan}apt/yum/pacman${reset}) found."
    fi
}

systidy:clean:temp() {
    local d=""
    if [[ "${banner}" = "yes" ]] ; then
        systidy:banner
    fi
    read -p "Remove files older than ${TEMP_AGE_DAYS} days from temp dirs? [y/N]:> " quest
    case "${quest}" in
        [yY][eE][sS]|[yY])
            for d in "${TEMP_DIRS[@]}" ; do
                if [[ -d "${d}" ]] ; then
                    if [[ "${DRYRUN}" = "yes" ]] ; then
                        echo -e "${blue}[dry-run]${reset} would remove files older than ${TEMP_AGE_DAYS}d under ${Bcyan}${d}${reset}:"
                        find "${d}" -mindepth 1 -mtime "+${TEMP_AGE_DAYS}" 2>/dev/null
                    else
                        find "${d}" -mindepth 1 -mtime "+${TEMP_AGE_DAYS}" -exec rm -rf {} + 2>/dev/null && {
                            echo -e "${Bcyan}${d}${reset}: old files ${purple}removed${reset}."
                        } || {
                            echo -e "${Bcyan}${d}${reset}: nothing to remove or partial ${red}failure${reset}."
                        }
                    fi
                fi
            done
        ;;
    esac
}

systidy:clean:applogs() {
    local pattern="" f=""
    if [[ "${#APP_LOGS[@]}" -eq 0 ]] ; then
        echo -e "No entries in ${Bcyan}APP_LOGS${reset} - nothing opted in, nothing done."
        return 0
    fi
    if [[ "${banner}" = "yes" ]] ; then
        systidy:banner
    fi
    read -p "Remove the rotated app-log patterns listed in APP_LOGS? [y/N]:> " quest
    case "${quest}" in
        [yY][eE][sS]|[yY])
            for pattern in "${APP_LOGS[@]}" ; do
                for f in ${pattern} ; do
                    if [[ -f "${f}" ]] ; then
                        if [[ "${DRYRUN}" = "yes" ]] ; then
                            echo -e "${blue}[dry-run]${reset} would remove ${Bcyan}${f}${reset}"
                        else
                            rm -f "${f}" && echo -e "${Bcyan}${f}${reset} ${purple}removed${reset}."
                        fi
                    fi
                done
            done
        ;;
    esac
}

systidy:fetch:info() {
    if [[ -f "/etc/os-release" ]] ; then
        source "/etc/os-release"
        local cpu="$(grep "model name" "/proc/cpuinfo" | cut -f 2 -d ":" | head -n 1)"
        local a b c idle1 total1 idle2 total2 dtotal didle
        read -r _ a b c idle1 _ <<< "$(grep "^cpu " /proc/stat)"
        total1=$(( a + b + c + idle1 ))
        sleep 1
        read -r _ a b c idle2 _ <<< "$(grep "^cpu " /proc/stat)"
        total2=$(( a + b + c + idle2 ))
        dtotal=$(( total2 - total1 ))
        didle=$(( idle2 - idle1 ))
        local ucpu=0
        [[ "${dtotal}" -gt 0 ]] && ucpu=$(( (100 * (dtotal - didle)) / dtotal ))
        local tmemory="$(( ($(grep "MemTotal" /proc/meminfo | tr -dc "0-9") / 1024) / 1024 ))"
        local fmemory="$(( ($(grep "MemFree" "/proc/meminfo" | tr -dc "0-9") / 1024) / 1024 ))"
        local umemory="$(( tmemory - fmemory ))"
        local time="$(cut -d " " /proc/uptime -f 1)"
        local hour="$(( (${time%.*} / 60) / 60 ))"
        local minute="$(( ${time%.*} / 60 ))"
        if [[ "${ucpu}" -le 40 ]] ; then
            local ucpu="${green}${ucpu}${reset}"
        elif [[ "${ucpu}" -le 70 ]] ; then
            local ucpu="${blue}${ucpu}${reset}"
        else
            local ucpu="${red}${ucpu}${reset}"
        fi
        if [[ "${banner}" = "yes" ]] ; then
            systidy:banner
        fi
        echo -e "
${Bwhite}Operating System${reset}\t: ${Bcyan}${NAME}${reset} ${green}${VERSION}${reset}
${Bwhite}Up Time${reset}\t\t: ${blue}${hour}${Bwhite}h${reset} -> ${blue}${minute}${Bwhite}mn${reset}
${Bwhite}Host Name${reset}\t\t: ${Bwhite}${HOSTNAME}${reset}
${Bwhite}CPU (Processor)${reset}\t\t:${blue}${cpu}${reset}
${Bwhite}CPU Usage${reset}\t\t: ${ucpu}${Bwhite}%${reset}
${Bwhite}Memory Usage (Ram)${reset}\t: ${green}${tmemory}GB${reset} ${Bwhite}/${reset} ${purple}${umemory}GB${reset}
${Bwhite}Free Memory (Ram)${reset}\t: ${blue}${fmemory}GB${reset}
"
    fi
}

# Parsing parameters:

while [[ "${#}" -gt 0 ]] ; do
    case "${1}" in
        --clean-cache|-cc)
            shift
            export CLEAN+=("cache") DO="non-interactive"
        ;;
        --clean-temp|-ct)
            shift
            export CLEAN+=("temp") DO="non-interactive"
        ;;
        --clean-applogs|-ca)
            shift
            export CLEAN+=("applogs") DO="non-interactive"
        ;;
        --fetch-info|-fi)
            shift
            export DO="fetch-info"
        ;;
        --dry-run|-d)
            shift
            export DRYRUN="yes"
        ;;
        --shell|-sh)
            shift
            export DO="shell"
        ;;
        --banner|-bn)
            shift
            export DO="print-banner"
        ;;
        --no-banner|-nb)
            shift
            export banner="no"
        ;;
        --help|-h)
            shift
            export DO="help"
        ;;
        --version|-v)
            shift
            export DO="version"
        ;;
        *)
            shift
        ;;
    esac
done

# Execute the selected option:

case "${DO}" in
    non-interactive)
        for i in "${CLEAN[@]}" ; do
            case "${i}" in
                cache)
                    systidy:clean:cache || export status="false"
                ;;
                temp)
                    systidy:clean:temp || export status="false"
                ;;
                applogs)
                    systidy:clean:applogs || export status="false"
                ;;
            esac
        done
    ;;
    fetch-info)
        systidy:fetch:info
    ;;
    shell)
        export input=""
        if [[ "${banner}" = "yes" ]] ; then
            systidy:banner
        fi
        echo -e "Welcome ${green}${USER}${reset}, this is the interactive ${Bwhite}shell${reset} of ${Bwhite}${0##*/}${reset}. Type '${Bcyan}help${reset}' to see commands.\n"
        while true ; do
            read -p "[${0##*/}-${version}]:> " input
            case "${input}" in
                banner)
                    systidy:banner
                ;;
                cache)
                    systidy:clean:cache
                ;;
                temp)
                    systidy:clean:temp
                ;;
                applogs)
                    systidy:clean:applogs
                ;;
                info)
                    systidy:fetch:info
                ;;
                dryrun)
                    if [[ "${DRYRUN}" = "yes" ]] ; then
                        export DRYRUN="no"
                        echo -e "Dry-run mode ${red}off${reset}."
                    else
                        export DRYRUN="yes"
                        echo -e "Dry-run mode ${green}on${reset}."
                    fi
                ;;
                help)
                    echo -e "${Bwhite}banner${reset}\tprints the banner.
${Bwhite}cache${reset}\tcleans the system package manager cache (needs root).
${Bwhite}temp${reset}\tremoves files older than ${TEMP_AGE_DAYS} days from temp dirs.
${Bwhite}applogs${reset}\tremoves rotated logs listed in the APP_LOGS array (opt-in only).
${Bwhite}info${reset}\tshows system information.
${Bwhite}dryrun${reset}\ttoggles dry-run mode (preview only, nothing removed).
${Bwhite}help${reset}\tshows this help text.
${Bwhite}version${reset}\tshows the current version.
${Bwhite}exit${reset}\tleaves the interactive shell."
                ;;
                version)
                    echo -e "Developed by ${green}Raman Singh Kushwaha (Hemant)${reset}, ${Bwhite}${0##*/}${reset} version ${Bcyan}${version}${reset}."
                ;;
                exit|quit)
                    exit 0
                ;;
                *)
                    echo -e "${Bwhite}${0##*/}${reset}: ${red}unknown${reset} command '${Bcyan}${input}${reset}'. Type '${Bcyan}help${reset}'."
                ;;
            esac
        done
    ;;
    print-banner)
        systidy:banner
    ;;
    help)
        echo -e "${green}${0##*/}${reset} - ${blue}${version}${reset}

${Bwhite}--clean-cache${reset}   | ${Bwhite}-cc${reset}   clean the system package manager cache (needs root)
${Bwhite}--clean-temp${reset}    | ${Bwhite}-ct${reset}   remove files older than ${TEMP_AGE_DAYS} days from temp dirs
${Bwhite}--clean-applogs${reset} | ${Bwhite}-ca${reset}   remove rotated logs listed in APP_LOGS (opt-in only)
${Bwhite}--fetch-info${reset}    | ${Bwhite}-fi${reset}   print OS/CPU/RAM/uptime info
${Bwhite}--dry-run${reset}       | ${Bwhite}-d${reset}    preview actions without deleting anything
${Bwhite}--shell${reset}         | ${Bwhite}-sh${reset}   start the interactive shell
${Bwhite}--banner${reset}        | ${Bwhite}-bn${reset}   print the banner and exit
${Bwhite}--no-banner${reset}     | ${Bwhite}-nb${reset}   suppress the banner for this run
${Bwhite}--help${reset}          | ${Bwhite}-h${reset}    show this help text
${Bwhite}--version${reset}       | ${Bwhite}-v${reset}    show the current version

SysTidy never touches auth logs, login records, or shell history.
See README.md for why."
    ;;
    version)
        echo "${version}"
    ;;
    *)
        echo -e "${Bwhite}${0##*/}${reset}: no job named '${Bcyan}${DO}${reset}'."
        export status="false"
    ;;
esac

if [[ "${status}" = "false" ]] ; then
    exit 1
fi
