#!/bin/sh
set -e

# Common configuration
ES_ENTRY_POINT="${ES_ENTRY_POINT:-http://elastic-search:9200}"
# Only for get listed here.
WAIT_FOR_SERVICE_UP="${WAIT_FOR_SERVICE_UP}"
WAIT_FOR_SERVICE_UP_TIMEOUT="${WAIT_FOR_SERVICE_UP_TIMEOUT:-10s}"


usage() {
    echo "
es-ctl list-schms|list-idxs|remove-idx|create-idx {options}|create-idxs {options}
  list-schms : list allowed schema configuration files
  list-idxs : list all idexes
  delete-idx : delete a index
    options: NAME
      NAME : the name of index to remove
  create-idx : create a index
    options: NAME [--safe-mode] [SCHEMA_PATH]
      NAME : the name of the index to create
      --safe-mode : Apply only if index does not exists
      SCHEMA_PATH : json file wiht schema definition. If not defined
        /etc/es-ctl/\${NAME}.es.schema.json will be used
  create-idxs : create multiple index
    options: [--safe-mode] NAME1 [-p PATH1] [-a ALIAS1] ... NAMEn [-p PATHn] [-a ALIASn]
      --safe-mode : Apply only if index does not exists
      NAMEx : the name of the index to create. Schema path used will be /etc/es-ctl/\${NAMEx}.es.schema.json by default
      PATHx : Use this path fot this index instead of /etc/es-ctl/\${NAMEx}.es.schema.json
      ALIASx: If defined create alias pointed to this index.
  create-all : create all indexes infering name of index from Schmema file name.
    All flies which path follow /etc/es-ctl/\${NAME}.es.schema.json pattern, will used to create index.
    options: [--safe-mode]
      --safe-mode : Apply only if index does not exists
  delete-idxs : delte multiple index
    options: [--force] NAME1 ... NAMEn
      --force : Do not ask for confirmation
      NAMEx : the name of the index to create. Schema path used will be /etc/es-ctl/\${NAME}.es.schema.json
  list-aliases : list all aliases
  create-alias : create one alias
    options: [--safe-mode] NAME INDICE_NAME
      --safe-mode : Apply only if alias does not exists.
      NAME : the name of the alias to create.
      INDICE_NAME : the name of the indice to be pointed by alias.
  create-aliases : create multiple aliases
    options: [--safe-mode] NAME1 INDICE_NAME1 ... NAMEn INDICE_NAMEn
      --safe-mode : Apply only if alias does not exists.
      NAMEx : the name of the alias to create.
      INDICE_NAMEx : the name of the indice to be pointed by alias.
  add-license: Add lincense to a cluster (cluster must have x-pack plugin installed)
    options: [--force-if-exists] [--no-acknowledge] LICENSE_AS_JSON
      --force-if-exists: If there is one license in cluster, with this option command
        to add license will be run anyway.
      --no-acknowledge: By default acknowledge parameter with true value is sent
        when license is put, with this option paramter is removed from query.
      LICENSE_AS_JSON: String in JSON format with license data
  get-license: List current license

  change-password: Change password for a user. Xpack plugin is required
    options: USER_NAME NEW_PASSWORD
      USER_NAME: User login id.
      NEW_PASSWORD: New password

  list-users: List all users. Xpack plugin is required
    options: [--full]
      --full: If present full information is displayed, else only names is displayed

  list-roles: List all roles. Xpack plugin is required
    options: [--full]
      --full: If present full information is displayed, else only names is displayed

  add-user: Add (or edit) user. Xpack plugin is required
    options: [--full-name FULL_NAME] [--email EMAIL] USER_NAME PASSWORD ROL1 ... ROLn
      FULL_NAME: User full name. In only one parameter
      EMAIL: User e-mail.
      USER_NAME: User id used to log-in
      PASSWORD: Password of the user to log-in

    ENVIRONMENT CONFIGURATION.
      There are some configuration and behaviours that can be set using next Environment
      Variables:

        ES_ENTRY_POINT. Entry point of Elastic Search REST API. Default: http://elastfic-search:9200
          If you need set user password with basic authentication (only one mode supported)
          you shoul set here user and password (as estandar URL way).

        ZOOKEEPER_ENTRY_POINT. Define zookeeper entry point. By default: zookeeper:2181

        KAFKA_BROKER_LIST. Define kafka bootstrap server entry points. By default:
          kafka:9092

        WAIT_FOR_SERVICE_UP. If it is defined we wait (using dockerize) for service(s)
          to be started before to perform any operation. Example values:

          WAIT_FOR_SERVICE_UP=\"tcp://kafka:9092\" wait for tcp connection to kafka:9092
          are available

          WAIT_FOR_SERVICE_UP=\"tcp://kafka:9092 tcp://zookeeper:2181\" Wait for
          kafka:9092 and zookeeper:2818 connections are avilable.

          If one of this can not be process will exit with error will be. See
          https://github.com/jwilder/dockerize for more information.

        WAIT_FOR_SERVICE_UP_TIMEOUT. Set timeot when check services listed on
          WAIT_FOR_SERVICE_UP. Default value 10s
"
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
    local name="$1"
    local path=""
    local alias=""
    local continueWithSubparams=""
    while [ -z "$continueWithSubparams" ]; do
      case $2 in
        -p)
          if [ -z "$3" ]
          then
            echo "Error. -p expecified without path value when create_indexes"
            usage
            exit 1
          fi
          path="$3"
          shift 2
          ;;
        -a)
          if [ -z "$3" ]
          then
            echo "Error. -a expecified without path aliase name when create_indexes"
            usage
            exit 1
          fi
          alias="$3"
          shift 2
          ;;
        * )
          continueWithSubparams="no"
          ;;
      esac
    done

    create_index "$name" "$safe_mode" $path
    if [ -n "$alias" ]; then
      create_alias $safe_mode "$alias" "$name"
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
    usage
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
      usage
      exit 1
    else
      create_alias ${safe_mode} $1 $2
    fi
    echo ""
    shift 2
  done
}


add_license(){
  local force_if_exists="no"
  local force_if_exists="no"
  local acknowledge="?acknowledge=true"
  while true
  do
    case $1 in
      --force-if-exists)
        force_if_exists="yes"
        ;;
      --no-acknowledge)
        acknowledge=""
        ;;
      *)
        break
        ;;
    esac
    shift 1
  done

  # Load license
  local license_data="$1"
  if [ -z "$license_data" ]
  then
    echo "Error. License data is empty in add_license"
    usage
    exit 1
  fi

  # Get if other license is on cluster
  local existing_license="$(get_license | jq '.[]')"
  if [ -n "$existing_license" ]
  then
    if [ "$force_if_exists" == "no" ]
    then
      echo "Error: There is one lincense uploaded in cluster or error found. (Run get-license command for more info)"
      exit 1
    else
      echo "Warning: There is one lincense in cluster but --force-if-exists option was set"
    fi
  fi

  curl \
    -XPOST "${ES_ENTRY_POINT}/_xpack/license${acknowledge}" \
    -H 'Content-Type: application/json' \
    -d "${license_data}"
}

get_license(){
  curl -sL -XGET "${ES_ENTRY_POINT}/_xpack/license" | jq .
}

change_password(){
  local user="$1"
  local passwd="$2"
  if [ -z "$user" ]
  then
    echo "Error: change_password without user name"
    exit 1
    usage
  fi
  if [ -z "$passwd" ]
  then
    echo "Error: change_password without password"
    exit 1
    usage
  fi

  curl \
    -XPUT "${ES_ENTRY_POINT}/_xpack/security/user/${user}/_password" \
    -H 'Content-Type: application/json' \
    -d "{\"${passwd}\"}"
}

list_users(){
  local only_names="keys"
  if [ "$1" == "--full" ]
  then
    only_names="."
  fi

  curl -sL \
    -XGET "${ES_ENTRY_POINT}/_xpack/security/user" \
    -H 'Content-Type: application/json' \
  | jq "${only_names}"
}

list_roles(){
  local only_names="keys"
  if [ "$1" == "--full" ]
  then
    only_names="."
  fi

  curl -sL \
    -XGET "${ES_ENTRY_POINT}/_xpack/security/role" \
    -H 'Content-Type: application/json' \
  | jq "${only_names}"
}

add_user(){
  # --full-name FULL_NAME] [--email EMAIL] USER_NAME PASSWORD ROL1 ... ROLn

  local full_name=""
  local email=""
  while true
  do
    case $1 in
      --full-name)
        if [ -z "$2" ]
        then
          echo "Error. --full-name without value in add_user method"
          usage
          exit 1
        fi
        full_name="\"full_name\" : \"$2\","
        shift 2
        ;;
      --email)
        if [ -z "$2" ]
        then
          echo "Error. --email without value in add_user method"
          usage
          exit 1
        fi
        email="\"email\" : \"$2\","
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  local name="$1"
  if [ -z "$name" ]
  then
    echo "Error. add_user method without user name"
    usage
    exit 1
  fi
  shift 1

  local password="$1"
  if [ -z "$password" ]
  then
    echo "Error. add_user method without password"
    usage
    exit 1
  fi
  shift 1

  local roles=""
  while [ -n "$1" ]
  do
    roles="$1\", \"$roles"
    shift
  done

  if [ -z "$roles" ]
  then
    echo "Error. add_user method without roles"
    usage
    exit 1
  fi

  #Format roles as json
  roles="$(echo "$roles" | sed -e 's/, \"$/]/' -e 's/^/["/')"

  local tempFile="$(mktemp)"
  cat > "$tempFile" << EOF
{
  "password" : "$password",
  "roles" : $roles,
  ${full_name}
  $email
  "metadata" : {}
}
EOF

  curl -sL \
    -XPOST "${ES_ENTRY_POINT}/_xpack/security/user/$name" \
    -H 'Content-Type: application/json' \
    -d "@$tempFile" \
  | jq

  rm -f "$tempFile"
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
  add-license)
    shift
    wait_for_service_up
    # Pass up to parameters escaped because one of then is JSON with spaces
    add_license "$@"
    ;;
  get-license)
    shift
    wait_for_service_up
    get_license $@
    ;;
  change-password)
    shift
    wait_for_service_up
    change_password $@
    ;;
  list-users)
    shift
    wait_for_service_up
    list_users $@
    ;;
  list-roles)
    shift
    wait_for_service_up
    list_roles $@
    ;;
  add-user)
    shift
    wait_for_service_up
    add_user "$@"
    ;;
  *)
    usage
    exit 1
    ;;
esac
