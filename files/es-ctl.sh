#!/bin/sh
set -e

# Common configuration
ES_ENTRY_POINT="${ES_ENTRY_POINT:-http://elastic-search:9200}"
# Only for get listed here.
WAIT_FOR_SERVICE_UP="${WAIT_FOR_SERVICE_UP}"
WAIT_FOR_SERVICE_UP_TIMEOUT="${WAIT_FOR_SERVICE_UP_TIMEOUT:-10s}"

use() {
    echo "es-ctl list-schms|list-idxs|remove-idx|create-idx {options}|create-idxs {options}"
    echo "  list-schms : list allowed schema configuration files"
    echo "  list-idxs : list all idexes"
    echo "  delete-idx : delete a index"
    echo "    options: NAME"
    echo "      NAME : the name of index to remove"
    echo "  create-idx : create a index"
    echo "    options: NAME [--safe-mode] [SCHEMA_PATH]"
    echo "      NAME : the name of the index to create"
    echo "      --safe-mode : Apply only if index does not exists"
    echo "      SCHEMA_PATH : json file wiht schema definition. If not defined"
    echo '        /etc/es-ctl/${NAME}.es.schema.json will be used'
    echo "  create-idxs : create multiple index"
    echo "    options: [--safe-mode] NAME1 [-p PATH1] ... NAMEn [-p PATHn]"
    echo "      --safe-mode : Apply only if index does not exists"
    echo '      NAMEx : the name of the index to create. Schema path used will be /etc/es-ctl/${NAMEx}.es.schema.json by default'
    echo '      PATHx : Use this path fot this index instead of /etc/es-ctl/${NAMEx}.es.schema.json'
    echo "  create-all : create all indexes infering name of index from Schmema file name."
    echo '    All flies which path follow /etc/es-ctl/${NAME}.es.schema.json pattern, will used to create index.'
    echo "    options: [--safe-mode]"
    echo "      --safe-mode : Apply only if index does not exists"
    echo "  delete-idxs : delte multiple index"
    echo "    options: [--force] NAME1 ... NAMEn"
    echo "      --force : Do not ask for confirmation"
    echo '      NAMEx : the name of the index to create. Schema path used will be /etc/es-ctl/${NAME}.es.schema.json'
    echo "  list-aliases : list all aliases"
    echo "  create-alias : create one alias"
    echo "    options: [--safe-mode] NAME INDICE_NAME"
    echo "      --safe-mode : Apply only if alias does not exists."
    echo '      NAME : the name of the alias to create.'
    echo '      INDICE_NAME : the name of the indice to be pointed by alias.'
    echo "  create-aliases : create multiple aliases"
    echo "    options: [--safe-mode] NAME1 INDICE_NAME1 ... NAMEn INDICE_NAMEn"
    echo "      --safe-mode : Apply only if alias does not exists."
    echo '      NAMEx : the name of the alias to create.'
    echo '      INDICE_NAMEx : the name of the indice to be pointed by alias.'
}

list_indexes() {
  curl "${ES_ENTRY_POINT}/_cat/indices?v" 2>/tmp/output_error || cat /tmp/output_error
}

delete_index() {
  curl -XDELETE "${ES_ENTRY_POINT}/$1" 2>/tmp/output_error || cat /tmp/output_error
}

create_index() {
  local index_name=$1
  shift
  local schema_path="/etc/es-ctl/${index_name}.es.schema.json"
  local safe_mode="no"

  while [ -n "$1" ]
  do
    case $1 in
      --safe-mode)
        safe_mode="yes"
        ;;
      *)
        schema_path="$1"
        ;;
    esac
    shift
  done

  if [ "yes" == "${safe_mode}" ]
  then
    if list_indexes | awk '{print $3}' | fgrep ${index_name} > /dev/null
    then
      echo "Index ${index_name} exists, ignoring"
    else
      curl -XPUT "${ES_ENTRY_POINT}/${index_name}" -d "@${schema_path}" 2>/tmp/output_error  || cat /tmp/output_error
    fi
  else
    curl -XPUT "${ES_ENTRY_POINT}/${index_name}" -d "@${schema_path}" 2>/tmp/output_error  || cat /tmp/output_error
  fi
}

create_indexes(){
  local safe_mode=""
  if [ "$1" == "--safe-mode" ]
  then
    safe_mode=$1
    shift
  fi

  while [ -n "$1" ]
  do
    if [ "$2" == "-p" ]
    then
      if [ -z "$3" ]
      then
        echo "Error. -p expecified without path value when create_indexes"
        use
        exit 1
      fi
      create_index "$1" "${safe_mode}" "$3"
      shift 2
    else
      create_index "$1" "${safe_mode}"
    fi
    echo ""
    shift
  done
}

create_all(){
  local index_names=$(list_schemas | egrep -ve "~|Assumed" | awk '{print $1}' | xargs echo)
  local safe_mode=""
  if [ "$1" == "--safe-mode" ]
  then
    safe_mode=$1
    shift
  fi

  for name in $index_names
  do
    create_index "$name" "${safe_mode}"
    echo ""
    shift
  done
}

delete_indexes(){
  local force="no"
  if [ "$1" == "--force" ]
  then
    force="yes"
    shift
  fi

  if [ "$force" != "yes" ]
  then
    echo "Next index will be deleted. are you sure (yes/no)"
    read confirmation
    if [ "$confirmation" != "yes" ]
    then
      exit
    fi
  fi

  while [ -n "$1" ]
  do
    delete_index "$1"
    echo ""
    shift
  done
}

list_schemas() {
  printf "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
  printf " %-30s | %s\n" "Assumed Index Name" "File"
  printf "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
  ls -1 /etc/es-ctl | while read l; do
    local indexName=$(echo $l | sed 's/\.es\.schema\.json//')
    printf " %-30s | %s\n" "$indexName" "/etc/es-ctl/$l"
  done
}

list_aliases() {
  curl "${ES_ENTRY_POINT}/_cat/aliases?v" 2>/tmp/output_error || cat /tmp/output_error
}

create_alias(){
  local safe_mode="no"
  if [ "$1" == "--safe-mode" ]; then
    safe_mode="yes"
    shift
  fi
  local name=$1
  shift
  local indice=$1

  if [ -z "$name" -a -z "$indice" ]; then
    echo "Error. Create alias withount name or indice"
    use
    exit 1
  fi

  if [ "yes" == "${safe_mode}" ]; then
    if list_aliases | awk '{print $1}' | fgrep ${name} > /dev/null
    then
      echo "Alias ${name} exists, ignoring"
    else
      curl -XPOST "${ES_ENTRY_POINT}/_aliases" -H 'Content-Type: application/json' -d \
        "{ \"actions\" : [ { \"add\" : { \"index\" : \"${indice}\", \"alias\" : \"${name}\" } } ] }" 2>/tmp/output_error  || cat /tmp/output_error
    fi
  else
    curl -XPOST "${ES_ENTRY_POINT}/_aliases" -H 'Content-Type: application/json' -d \
      "{ \"actions\" : [ { \"add\" : { \"index\" : \"${indice}\", \"alias\" : \"${name}\" } } ] }" 2>/tmp/output_error  || cat /tmp/output_error
  fi
}

create_aliases(){
  local safe_mode=""
  if [ "$1" == "--safe-mode" ]
  then
    safe_mode=$1
    shift
  fi

  while [ -n "$1" ]
  do
    if [ -z "$2" ]; then
      echo "Error. alias without indices names in cerate_aliases"
      use
      exit 1
    else
      create_alias ${safe_mode} $1 $2
    fi
    echo ""
    shift 2
  done
}

wait_for_service_up(){
    if [ -n "$WAIT_FOR_SERVICE_UP" ]; then
      local services=""
      #Set -wait option to use with docerize
      for service in $WAIT_FOR_SERVICE_UP; do
        services="$services -wait $service"
      done
      echo "Waiting till services $WAIT_FOR_SERVICE_UP are accessible (or timeout: $WAIT_FOR_SERVICE_UP_TIMEOUT)"
      dockerize $services -timeout "$WAIT_FOR_SERVICE_UP_TIMEOUT"
    fi
}

case $1 in
  list-idxs)
    wait_for_service_up
    list_indexes
    ;;
  create-idx)
    shift
    wait_for_service_up
    create_index $@
    ;;
  create-idxs)
    shift
    wait_for_service_up
    create_indexes $@
    ;;
  create-all)
    shift
    wait_for_service_up
    create_all $@
    ;;
  delete-idx)
    shift
    wait_for_service_up
    delete_index $@
    ;;
  delete-idxs)
    shift
    wait_for_service_up
    delete_indexes $@
    ;;
  list-schms)
    wait_for_service_up
    list_schemas
    ;;
  list-aliases)
    wait_for_service_up
    list_aliases
    ;;
  create-alias)
    shift
    wait_for_service_up
    create_alias $@
    ;;
  create-aliases)
    shift
    wait_for_service_up
    create_aliases $@
    ;;
  *)
    use
    exit 1
    ;;
esac
