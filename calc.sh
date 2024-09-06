#!/bin/bash

export POD_ENV="PROD"
#export POD_ENV="UAT"
export my_debug="0"
#export my_debug="1"

echo " - calculator for kubetnetes's resources quota by david. "

read_resources_lab()
{
export APID="XXXOOOAA02"
export PROJECT="xxx-svc-auth-external"
export MY_ARGUMENT="UAT-default.sh"

#eval $(echo "$(cat ${MY_ARGUMENT})")
#source ${MY_ARGUMENT}
eval $(echo "$(cat ${MY_ARGUMENT}|grep -E 'LIMIT_CPU|LIMIT_MEM|REQUEST_CPU|REQUEST_MEM|REPLICAS|ENABLE_HPA|REPLICA_MIN|REPLICA_MAX')")

calc_resources
output_rsuquota
}

calc_resources()
{

###if [ "${ENABLE_HPA}" == 'true' ]
if [ "$(echo ${ENABLE_HPA}|grep -c 'true')" == "1" ]
  then
    [ "${my_debug}" == "1" ] && echo "  ENABLE HPA:${ENABLE_HPA} (true)"
    export REPLICAS=${REPLICA_MIN}
    export RSQUOTA_LIMIT_CPU=$( echo "${LIMIT_CPU} * ${REPLICA_MAX}"|bc )
    export RSQUOTA_LIMIT_MEM=$(echo "${LIMIT_MEM} * ${REPLICA_MAX}"|bc)
    export RSQUOTA_REQUEST_CPU=$(echo "${REQUEST_CPU} * ${REPLICAS}"|bc)
    export RSQUOTA_REQUEST_MEM=$(echo "${REQUEST_MEM} * ${REPLICAS}"|bc)
  else
    [ "${my_debug}" == "1" ] && echo "  ENABLE HPA:${ENABLE_HPA} (false)"
    export RSQUOTA_LIMIT_CPU=$(echo "${LIMIT_CPU} * ${REPLICAS}"|bc)
    export RSQUOTA_LIMIT_MEM=$(echo "${LIMIT_MEM} * ${REPLICAS}"|bc)
    export RSQUOTA_REQUEST_CPU=$(echo "${REQUEST_CPU} * ${REPLICAS}"|bc)
    export RSQUOTA_REQUEST_MEM=$(echo "${REQUEST_MEM} * ${REPLICAS}"|bc)
fi
}

output_rsuquota()
{
#echo -e " - APID:${APID} PROJECT:${PROJECT} MY_ARGUMENT:${MY_ARGUMENT} Resources Quota - LIMIT CPU:${RSQUOTA_LIMIT_CPU} LIMIT MEM:${RSQUOTA_LIMIT_MEM} REQUEST CPU:${RSQUOTA_REQUEST_CPU} REQUEST MEM:${RSQUOTA_REQUEST_MEM}"
##echo -e " APID,PROJECT,LIMIT CPU,LIMIT MEM,REQUEST CPU,REQUEST MEM"

echo -e "\"${APID}\",\"${PROJECT}\",\"${RSQUOTA_LIMIT_CPU}\",\"${RSQUOTA_LIMIT_MEM}\",\"${RSQUOTA_REQUEST_CPU}\",\"${RSQUOTA_REQUEST_MEM}\""
}

main()
{
echo -e "\"APID\",\"PROJECT\",\"LIMIT CPU\",\"LIMIT MEM\",\"REQUEST CPU\",\"REQUEST MEM\""

for APID in $(find . -type d -depth 1|grep -v '.git'|grep -Eo '[A-Z|0-9]*')
do
  #[ "${my_debug}" == "1" ] && echo " - APID:${APID}"

  for PROJECT in $(find ${APID} -type d -depth 1|grep -v '.git'|awk -F'/' '{print $NF}')
  do

  #[ "${my_debug}" == "1" ] && echo -e "\tAPID:${APID}\tPROJECT:${PROJECT}"
  #[ "${my_debug}" == "1" ] && ls -l ${APID}/${PROJECT}/${POD_ENV}/argument.sh

    if [ -f "${APID}/${PROJECT}/${POD_ENV}/argument.sh" ]
      then
        export MY_ARGUMENT="${APID}/${PROJECT}/${POD_ENV}/argument.sh"
      else
        export MY_ARGUMENT="${POD_ENV}-default.sh"
    fi

    [ "${my_debug}" == "1" ] && echo -e " - APID:${APID}\tPROJECT:${PROJECT}\tMY_ARGUMENT:${MY_ARGUMENT}"
    #source ${MY_ARGUMENT}
    eval $(echo "$(cat ${MY_ARGUMENT}|grep -E 'LIMIT_CPU|LIMIT_MEM|REQUEST_CPU|REQUEST_MEM|REPLICAS|ENABLE_HPA|REPLICA_MIN|REPLICA_MAX')")

    calc_resources
    output_rsuquota
  done
done
}

calc_by_APID()
{
export DATA_CSV="k8s-rs-quota.csv"

for APID in $(cat ${DATA_CSV} | awk -F ',' '{print $1}' | sed 's|"||g'|sort -n|uniq|grep -v APID)
do
  export TOTAL_LIMIT_CPU="$(cat ${DATA_CSV}|grep ${APID}|awk -F',' '{print $3}'|sed 's|"||g'|awk 1 ORS='+'|sed 's|+$||g'|bc)"
  export TOTAL_LIMIT_MEM="$(cat ${DATA_CSV}|grep ${APID}|awk -F',' '{print $4}'|sed 's|"||g'|awk 1 ORS='+'|sed 's|+$||g'|bc)"
  export TOTAL_REQUEST_CPU="$(cat ${DATA_CSV}|grep ${APID}|awk -F',' '{print $5}'|sed 's|"||g'|awk 1 ORS='+'|sed 's|+$||g'|bc)"
  export TOTAL_REQUEST_MEM="$(cat ${DATA_CSV}|grep ${APID}|awk -F',' '{print $6}'|sed 's|"||g'|awk 1 ORS='+'|sed 's|+$||g'|bc)"

  echo "APID:${APID}"
  echo "Total LIMIT CPU:${TOTAL_LIMIT_CPU}"
  echo "Total LIMIT MEM:${TOTAL_LIMIT_MEM}"
  echo "Total REQUEST CPU:${TOTAL_REQUEST_CPU}"
  echo "Total REQUEST MEM:${TOTAL_REQUEST_MEM}"

  make_rs_quota_yamls
done
}

make_rs_quota_yamls()
{
export output_yaml="${APID}-quota-cpu-mem.yaml"

echo "apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${APID}-quota-cpu-mem
spec:
  hard:
    requests.cpu: ${TOTAL_REQUEST_CPU} 
    requests.memory: ${TOTAL_REQUEST_MEM}
    limits.cpu: ${TOTAL_LIMIT_CPU}
    limits.memory: ${TOTAL_LIMIT_MEM}" > ./"${output_yaml}"

ls -l "${output_yaml}"
}


#read_resources_lab
#main
main > k8s-rs-quota.csv
calc_by_APID
exit

# --- END --- #
