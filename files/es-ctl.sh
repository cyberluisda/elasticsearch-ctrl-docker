#!/bin/sh
set -e

# Common configuration
ES_ENTRY_POINT="${ES_ENTRY_POINT:-http://elastic-search:9200}"
# Only for get listed here.
WAIT_FOR_SERVICE_UP="${WAIT_FOR_SERVICE_UP}"
WAIT_FOR_SERVICE_UP_TIMEOUT="${WAIT_FOR_SERVICE_UP_TIMEOUT:-10s}"
CHECK_ERRORS_IN_RESPOSE="${CHECK_ERRORS_IN_RESPOSE:-yes}"
CURL_COMMON_OPTIONS="${CURL_COMMON_OPTIONS:--k}"


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
    options: [--check-old-user-password USER_NAME_OLD PASSWORD_OLD] USER_NAME NEW_PASSWORD
      USER_NAME: User login id.
      NEW_PASSWORD: New password
      --check-old-user-password. Usefull when you need to change default password
        of superuser after bootstramp installation. With this option we call first
        with USER_NAME_OLD and PASSWORD_OLD, if authentication fails (response
        different of 401 status code, command will exit with status 0, no error).
        But if authentication can be granted then change password will be executed
        as usual way.

        For example if just after fitrst installation you need change password of
        \"elastic\" user from default \"changeme\" to more secure password.
        You can call with as example:

        .... change-password elastic changeme elastic MoreSecurePassword

        Initial execution of this command will authenticated with with changeme
        password and then  change-password will be executed.
        In next executions with just this optison, for example after upgrade
        system, changeme password is invalid and can not be authorized (response 401)
        change-password will not have any effect and return with status code 0.

        This will allow to create init services for change defaults passwor in
        Kubernetes as example.
      USER_NAME_OLD Old username to pre-check. NOTE: For sed restrictions '|' chart
        must be escaped, in same way special chars like :@ used in authentication by
        URL.
      PASSWORD_OLD: Old password to pre-check. NOTE: For sed restrictions '|' chart
        must be escaped, in same way special chars like :@ used in authentication by
        URL.

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

  add-role: Add roles. Xpack plugin is required
    options NAME ROLE_SPEC_JSON
      NAME: Name of te roles
      ROLE_SPEC_JSON: Role specification in json format

  list-templates: List all templates with definition.
    options: [-d]
      -d: Show definition (body) for each template

  add-template: Add (or update) template
    options: NAME [-e DEFINITION | -f DEFINITON_JSON_FILE]
      NAME: name of the template
      -e DEFINITION: Use 'DEFINITION' as body of template (json format)
      -f DEFINITION_JSON_FILE: Use 'DEFINITION_JSON_FILE' file as body of template

  delete-templates: Delete templates
    options: NAME_PATTERN
      NAME_PATTERN: Elastic search pattern for templates to delete

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

      CHECK_ERRORS_IN_RESPOSE. If is \"yes\" (default) some errors like unauthorized
        access are checked on response of some commands and exit with error code if
        applied.

      CURL_COMMON_OPTIONS. Command line options to add in all curl executions.
        By default set \"-k\"
"
}

config_cheks(){
    if [ -z "$ES_ENTRY_POINT" ]; then
      printf "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ WARNING !!! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
      printf " ES_ENTRY_POINT environment var is empty\n"
      printf "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
    fi
    if [ "$(echo -n "$ES_ENTRY_POINT" | tail -c 1)" == "/" ]; then
      printf "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ WARNING !!! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
      printf " ES_ENTRY_POINT ends with '/' character. This can lead to curl parsing errors. For example:\n"
      printf " 'parse error: Invalid numeric literal at line 1, column 3'\n"
      printf "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
    fi
}

list_indexes() {
  rm -f /tmp/output_error
  curl ${CURL_COMMON_OPTIONS} "${ES_ENTRY_POINT}/_cat/indices?v" 2>> /tmp/output_error | tee -a /tmp/output_error
  checks_errors_in_response
}

delete_index() {
  rm -f /tmp/output_error
  curl ${CURL_COMMON_OPTIONS} -XDELETE "${ES_ENTRY_POINT}/$1" 2>> /tmp/output_error | tee -a /tmp/output_error | jq .
  checks_errors_in_response
}

create_index() {
  rm -f /tmp/output_error
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
      curl ${CURL_COMMON_OPTIONS} -XPUT "${ES_ENTRY_POINT}/${index_name}" -d "@${schema_path}" 2>> /tmp/output_error | tee -a /tmp/output_error | jq .
    fi
  else
    curl ${CURL_COMMON_OPTIONS} -XPUT "${ES_ENTRY_POINT}/${index_name}" -d "@${schema_path}" 2>> /tmp/output_error | tee -a /tmp/output_error | jq .
  fi
  checks_errors_in_response
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
  rm -f /tmp/output_error
  curl ${CURL_COMMON_OPTIONS} "${ES_ENTRY_POINT}/_cat/aliases?v" 2>> /tmp/output_error | tee -a /tmp/output_error
  checks_errors_in_response
}

create_alias(){
  rm -f /tmp/output_error
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
      curl ${CURL_COMMON_OPTIONS} -XPOST "${ES_ENTRY_POINT}/_aliases" -H 'Content-Type: application/json' -d \
        "{ \"actions\" : [ { \"add\" : { \"index\" : \"${indice}\", \"alias\" : \"${name}\" } } ] }" \
      2>> /tmp/output_error | tee -a /tmp/output_error | jq .
    fi
  else
    curl ${CURL_COMMON_OPTIONS} -XPOST "${ES_ENTRY_POINT}/_aliases" -H 'Content-Type: application/json' -d \
      "{ \"actions\" : [ { \"add\" : { \"index\" : \"${indice}\", \"alias\" : \"${name}\" } } ] }" \
    2>> /tmp/output_error | tee -a /tmp/output_error | jq .
  fi
  checks_errors_in_response
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
  rm -f /tmp/output_error
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
    ${CURL_COMMON_OPTIONS} \
    -XPOST "${ES_ENTRY_POINT}/_xpack/license${acknowledge}" \
    -H 'Content-Type: application/json' \
    -d "${license_data}" \
  2>> /tmp/output_error | tee -a /tmp/output_error | jq .

  checks_errors_in_response
}

get_license(){
  local license="$(curl ${CURL_COMMON_OPTIONS} -sL -XGET "${ES_ENTRY_POINT}/_xpack/license")"
  checks_errors_in_response "$license"
  echo "$license" | jq .
}

change_password(){
  rm -f /tmp/output_error
  local check_old_user="no"
  while true
  do
    case $1 in
      --check-old-user-password)
        if [ -z "$2" -o -z "$3" ]
        then
          echo "Error: change_password with --check-old-user-password without user and or password"
          usage
          exit 1
        fi
        local old_user="$2"
        local old_password="$3"
        check_old_user="yes"
        shift 3
        ;;
      *)
        break
        ;;
    esac
  done

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

  if [ "yes" == "$check_old_user" ]
  then
    #Replacing user password with old user/password in entry point
    local old_entry_point=$(echo "${ES_ENTRY_POINT}" | sed -re "s|(https?://)(\w+:\w+@)?([a-zA-Z\.:0-9/_\-]+)|\1${old_user}:${old_password}@\3|")

    # If old user is unauthorized exit without error
    if curl ${CURL_COMMON_OPTIONS} -s "$old_entry_point" | fgrep '"status":401' > /dev/null
    then
      echo "Info. Old user password now is unauthorized, nothing to do"
      exit 0
    fi
  fi

  curl \
    ${CURL_COMMON_OPTIONS} \
    -XPUT "${ES_ENTRY_POINT}/_xpack/security/user/${user}/_password" \
    -H 'Content-Type: application/json' \
    -d "{\"password\": \"${passwd}\"}" \
  2>> /tmp/output_error | tee -a /tmp/output_error

  checks_errors_in_response
}

list_users(){
  local only_names="keys"
  if [ "$1" == "--full" ]
  then
    only_names="."
  fi

  local users="$(curl ${CURL_COMMON_OPTIONS} -sL \
    -XGET "${ES_ENTRY_POINT}/_xpack/security/user" \
    -H 'Content-Type: application/json' \
    )"

  checks_errors_in_response "$users"
  echo "$users" | jq "${only_names}"
}

list_roles(){
  local only_names="keys"
  if [ "$1" == "--full" ]
  then
    only_names="."
  fi

  local roles="$(curl ${CURL_COMMON_OPTIONS} -sL \
    -XGET "${ES_ENTRY_POINT}/_xpack/security/role" \
    -H 'Content-Type: application/json' \
    )"

  checks_errors_in_response "$roles"
  echo "$roles" | jq "${only_names}"
}

add_user(){
  rm -f /tmp/output_error

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

  curl \
    ${CURL_COMMON_OPTIONS} \
    -sL \
    -XPOST "${ES_ENTRY_POINT}/_xpack/security/user/$name" \
    -H 'Content-Type: application/json' \
    -d "@$tempFile" \
  2>> /tmp/output_error | tee -a /tmp/output_error | jq .

  rm -f "$tempFile"
  checks_errors_in_response
}

add_role(){
  rm -f /tmp/output_error

  # Load role name specificatoin
  local name="$1"
  if [ -z "$name" ]
  then
    echo "Error. role name is empty in add_role"
    usage
    exit 1
  fi
  local role_data="$2"
  if [ -z "$role_data" ]
  then
    echo "Error. Role data specification is empty in add_role"
    usage
    exit 1
  fi

  curl \
    ${CURL_COMMON_OPTIONS} \
    -sL \
    -XPOST "${ES_ENTRY_POINT}/_xpack/security/role/$name" \
    -H 'Content-Type: application/json' \
    -d "${role_data}" \
  2>> /tmp/output_error | tee -a /tmp/output_error | jq .
  checks_errors_in_response
}

list_templates(){
  rm -f /tmp/output_error

  local jq_filter=". | keys"
  if [ "$1" == "-d" ]
  then
    jq_filter="."
  fi

  curl \
    ${CURL_COMMON_OPTIONS} \
    -sL \
    -XGET "${ES_ENTRY_POINT}/_template" \
  2>> /tmp/output_error | tee -a /tmp/output_error | jq "${jq_filter}"
  checks_errors_in_response
}

add_template(){
  rm -f /tmp/output_error

  local name="$1"
  if [ "$1" == "" ]
  then
    echo "Error add-template without name"
    exit 1
  fi

  local template_data=""
  if [ "$2" == "-e" ]
  then
    if [ "$3" == "" ]
    then
      echo "Error add-template -e with empty value for especification"
    fi
    template_data="$3"
  elif [ "$2" == "-f" ]
  then
    if [ ! -f "$3" ]
    then
      echo "Error add-templte -f without file as a third argument"
    fi
    template_data="$(cat "$3")"
  fi

  if [ "" == "${template_data}" ]
  then
    echo "Error add-template without template specification"
    exit 1
  fi

  curl \
    ${CURL_COMMON_OPTIONS} \
    -sL \
    -XPUT "${ES_ENTRY_POINT}/_template/${name}" \
    -H 'Content-Type: application/json' \
    -d "${template_data}" \
  2>> /tmp/output_error | tee -a /tmp/output_error | jq "${jq_filter}"
  checks_errors_in_response
}

delete_templates(){
  rm -f /tmp/output_error

  local name="$1"
  if [ "$1" == "" ]
  then
    echo "Error delete-template without name"
    exit 1
  fi

  curl \
    ${CURL_COMMON_OPTIONS} \
    -sL \
    -XDELETE "${ES_ENTRY_POINT}/_template/${name}" \
  2>> /tmp/output_error | tee -a /tmp/output_error | jq "."
  checks_errors_in_response
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

##
##
# $1 text to search on "unauthorized message", if empty we look on /tmp/output_error file
#
checks_errors_in_response(){
  if [ "yes" == "$CHECK_ERRORS_IN_RESPOSE" ]
  then
    local data=""
    if [ -z "$1" ]
    then
      data="$(cat /tmp/output_error)"
    else
      data="$1"
    fi

    if echo "$data" | fgrep '"status"' | fgrep "401" > /dev/null
    then
      echo "Error: Unauthorized error response on $data"
      exit 1
    elif echo "$data" | fgrep '"error"' > /dev/null
    then
      echo "Error: 'error' word found on $data response"
      exit 1
    fi
  fi
}

case $1 in
  list-idxs)
    config_cheks
    wait_for_service_up
    list_indexes
    ;;
  create-idx)
    shift
    config_cheks
    wait_for_service_up
    create_index $@
    ;;
  create-idxs)
    shift
    config_cheks
    wait_for_service_up
    create_indexes $@
    ;;
  create-all)
    shift
    config_cheks
    wait_for_service_up
    create_all $@
    ;;
  delete-idx)
    shift
    config_cheks
    wait_for_service_up
    delete_index $@
    ;;
  delete-idxs)
    shift
    config_cheks
    wait_for_service_up
    delete_indexes $@
    ;;
  list-schms)
    wait_for_service_up
    list_schemas
    ;;
  list-aliases)
    config_cheks
    wait_for_service_up
    list_aliases
    ;;
  create-alias)
    shift
    config_cheks
    wait_for_service_up
    create_alias $@
    ;;
  create-aliases)
    shift
    config_cheks
    wait_for_service_up
    create_aliases $@
    ;;
  add-license)
    shift
    config_cheks
    wait_for_service_up
    # Pass up to parameters escaped because one of then is JSON with spaces
    add_license "$@"
    ;;
  get-license)
    shift
    config_cheks
    wait_for_service_up
    get_license $@
    ;;
  change-password)
    shift
    config_cheks
    wait_for_service_up
    change_password $@
    ;;
  list-users)
    shift
    config_cheks
    wait_for_service_up
    list_users $@
    ;;
  list-roles)
    shift
    config_cheks
    wait_for_service_up
    list_roles $@
    ;;
  add-user)
    shift
    config_cheks
    wait_for_service_up
    add_user "$@"
    ;;
  add-role)
    shift
    config_cheks
    wait_for_service_up
    add_role "$@"
    ;;
  list-templates)
    shift
    config_cheks
    wait_for_service_up
    list_templates "$@"
    ;;
  add-template)
    shift
    config_cheks
    wait_for_service_up
    add_template "$@"
    ;;
  delete-templates)
    shift
    config_cheks
    wait_for_service_up
    delete_templates "$@"
    ;;
  *)
    usage
    exit 1
    ;;
esac
