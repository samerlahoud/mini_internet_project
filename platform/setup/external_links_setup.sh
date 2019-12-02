#!/bin/bash
#
# create links between groups
# links defined in ./config/external_links_config.txt
# ip subnets defined in ./config/subnet_config.sh

set -o errexit
set -o pipefail
set -o nounset

DIRECTORY="$1"
source "${DIRECTORY}"/config/subnet_config.sh

# read configs
readarray groups < "${DIRECTORY}"/config/AS_config.txt
readarray extern_links < "${DIRECTORY}"/config/external_links_config.txt

group_numbers=${#groups[@]}
n_extern_links=${#extern_links[@]}

for ((i=0;i<n_extern_links;i++)); do
    row_i=(${extern_links[$i]})
    grp_1="${row_i[0]}"
    router_grp_1="${row_i[1]}"
    relation_grp_1="${row_i[2]}"
    grp_2="${row_i[3]}"
    router_grp_2="${row_i[4]}"
    relation_grp_2="${row_i[5]}"
    throughput="${row_i[6]}"
    delay="${row_i[7]}"

    for ((k=0;k<group_numbers;k++)); do
        group_k=(${groups[$k]})
        group_number="${group_k[0]}"
        group_as="${group_k[1]}"
        if [ "${grp_1}" = "${group_number}" ];then
            group_as_1="${group_as}"
        elif [ "${grp_2}" = "${group_number}" ];then
            group_as_2="${group_as}"
        fi
    done

    if [ "${group_as_1}" = "IXP" ] || [ "${group_as_2}" = "IXP" ];then

        # make sure grp_2 is the IXP
        if [ "${group_as_1}" = "IXP" ];then
            grp_1="${row_i[2]}"
            router_grp_1="${row_i[3]}"
            grp_2="${row_i[0]}"
            router_grp_2="${row_i[1]}"
        fi

        br_name="ixp-""${grp_2}""-""${grp_1}"
        subnet_bridge="$(subnet_router_IXP "${grp_1}" "${grp_2}" "bridge")"
        subnet_1="$(subnet_router_IXP "${grp_1}" "${grp_2}" "group")"
        subnet_2="$(subnet_router_IXP "${grp_1}" "${grp_2}" "IXP")"

        echo -n "-- add-br "${br_name}" " >> "${DIRECTORY}"/groups/add_bridges.sh
        echo "ifconfig "${br_name}" 0.0.0.0 up" >> "${DIRECTORY}"/groups/ip_setup.sh

        ./setup/ovs-docker.sh add-port  "${br_name}" ixp_"${grp_2}" \
          "${grp_1}"_"${router_grp_1}"router
        ./setup/ovs-docker.sh add-port "${br_name}" grp_"${grp_1}" \
          "${grp_2}""_IXP"
    else
        br_name="ext-""${i}"
        subnet_bridge="$(subnet_router_router_extern ${i} "bridge")"
        subnet_router1="$(subnet_router_router_extern ${i} 1)"
        subnet_router2="$(subnet_router_router_extern ${i} 2)"

        echo -n "-- add-br "${br_name}" " >> "${DIRECTORY}"/groups/add_bridges.sh
        echo "ifconfig "${br_name}" 0.0.0.0 up" >> "${DIRECTORY}"/groups/ip_setup.sh

        ./setup/ovs-docker.sh add-port  "${br_name}" ext_"${grp_2}"_"${router_grp_2}" \
        "${grp_1}"_"${router_grp_1}"router --ipaddress="${subnet_router1}" \
        --delay="${delay}" --throughput="${throughput}"

        ./setup/ovs-docker.sh add-port "${br_name}" ext_"${grp_1}"_"${router_grp_1}" \
        "${grp_2}"_"${router_grp_2}"router --ipaddress="${subnet_router2}" \
        --delay="${delay}" --throughput="${throughput}"
    fi
done
