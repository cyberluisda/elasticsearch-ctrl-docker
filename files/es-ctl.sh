#!/bin/sh
set -e

# Common configuration
ES_ENTRY_POINT="${ES_ENTRY_POINT:-http://elastic-search:9200}"

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
    echo "    options: [--safe-mode] NAME1 ... NAMEn"
    echo "      --safe-mode : Apply only if index does not exists"
    echo '      NAMEx : the name of the index to create. Schema path used will be /etc/es-ctl/${NAME}.es.schema.json'
    echo "  create-all : create all indexes infering name of index from Schmema file name."
    echo '    All flies which path follow /etc/es-ctl/${NAME}.es.schema.json pattern, will used to create index.'
    echo "    options: [--safe-mode]"
    echo "      --safe-mode : Apply only if index does not exists"
    echo "  delete-idxs : delte multiple index"
    echo "    options: [--force] NAME1 ... NAMEn"
    echo "      --force : Do not ask for confirmation"
    echo '      NAMEx : the name of the index to create. Schema path used will be /etc/es-ctl/${NAME}.es.schema.json'
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
    create_index "$1" "${safe_mode}"
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


case $1 in
  list-idxs)
    list_indexes
    ;;
  create-idx)
    shift
    create_index $@
    ;;
  create-idxs)
    shift
    create_indexes $@
    ;;
  create-all)
    shift
    create_all $@
    ;;
  delete-idx)
    shift
    delete_index $@
    ;;
  delete-idxs)
    shift
    delete_indexes $@
    ;;
  list-schms)
    list_schemas
    ;;
  *)
    use
    exit 1
    ;;
esac
