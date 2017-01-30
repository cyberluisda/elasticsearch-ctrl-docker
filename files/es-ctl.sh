#!/bin/sh
set -e

# Common configuration
ES_ENTRY_POINT="${ES_ENTRY_POINT:-http://elastic-search:9200}"

use() {
    echo "es-ctl list-schms|list-idxs|remove-idx|create-idx [options]"
    echo "  list-schms : list allowed schema configuration files"
    echo "  list-idxs : list all idexes"
    echo "  delete-idx : delete a index"
    echo "    options: NAME"
    echo "      NAME : the name of index to remove"
    echo "  create-idx : create a index"
    echo "    options: NAME [SCHEMA_PATH]"
    echo "      NAME : the name of the index to create"
    echo "      SCHEMA_PATH : json file wiht schema definition. If not defined"
    echo '        /etc/es-ctl/${NAME}_schema.json will be used'

}

list_indexes() {
  curl "${ES_ENTRY_POINT}/_cat/indices?v"
}

delete_index() {
  curl -XDELETE "${ES_ENTRY_POINT}/$1"
}

create_index() {
  schema_path="/etc/es-ctl/$1_schema.json"
  if [ ! -z "$2" ]
  then
    schema_path="$2"
  fi

  curl -XPUT "${ES_ENTRY_POINT}/$1" -d "@${schema_path}"
}

list_schemas() {
  ls -1 /etc/es-ctl
}


case $1 in
  list-idxs)
    list_indexes
    ;;
  create-idx)
    shift
    create_index $@
    ;;
  delete-idx)
    shift
    delete_index $@
    ;;
  list-schms)
    list_schemas
    ;;
  *)
    use
    exit 1
    ;;
esac
