#! /usr/bin/env zsh -f

#
# Load zcl
#
source ./lib/zcl

#
# Generates mapping script line (will be used by `eval`)
#
# @param conf_type Configuration type defined as {base, header, query, cookie}.
# @param key Key value for each field. If ${conf_type} is 'base', keys were defined as {url, path}.
# @param value Value for field.
#
function _zcpb::eval_string()
{
  local conf_type=$1
  local key=$2
  local value=$3

  echo "${conf_type}[${key}]=${value};"
}

#
# Verifies there are no duplicated options
# (Duplicated options means short/long option etc. Not same options)
#
# @param 1st option string
# @param 2nd option string
# @param Args for script
#
function _zcpb::verify_no_duplicated_options()
{
  local -a options=($1 $2)
  local -a args=($*)

  # Verify args for this function
  if [[ ${#options} != 2 ]]
  then
    echo "Error: Invalid option was found for $0" 1>&2
    return 1
  fi

  # Remove heading option string
  args[1,2]=()

  # Verify the number of args
  if [[ ${#args} == 0 ]]
  then
    echo "Error: No args for verify in $0" 1>&2
    return 1
  fi

  # Verify the target
  if [[ ${args[(i)${options[1]}]} == 0 ]]
  then
    return 0
  fi

  if [[ ${args[(i)${options[2]}]} != 0 ]]
  then
    return 1
  fi

  return 0
}

#
# Select next target index of given option
#
# Example:
#   ./$0 --key -k1 v1 -k2 v2 --key v3 --key v4 -k5 v5
#
#   returns, 6. Index of option correspond to value v3.
#
# @param Parse target option
# @return Result index (null if value not found for key)
#
function _zcpb::get_option()
{
  local option_key=$1
  shift

  local -i idx=${*[(i)${option_key}]}
  if [[ ${idx} == 0 ]]
  then
    return 1
  fi

  echo ${*[$((${idx} + 1))]}
  return 0
}

#
# Main task of zcpb
#
# @param definition_conf_path Parameter definition file path.
# @param user_conf_path Actual parameter value stored file path.
# @param modes Modes defined as {--pretty}.
#
function _zcpb::main()
{
  #
  # Verifies zcl is available or not
  #
  if ! type zcl 1>/dev/null 2>/dev/null
  then
    echo "Error: zcl unavailable." 1>&2
    return 1
  fi

  #
  # Pickup parameters
  #
  local definition_conf_path=$1
  local user_conf_path=$2
  local -a modes=(${*[3,-1]})

  #
  # Validate variables
  #
  if [[ ! -f ${definition_conf_path} ]]
  then
    echo "Error: Definition configuration file not found" 1>&2
    return 1
  fi

  if [[ ! -f ${user_conf_path} ]]
  then
    echo "Error: User configuration file not found" 1>&2
    return 1
  fi

  #
  # Import user configuration as variable
  #
  source ${user_conf_path}

  #
  # Map values to associated array
  #
  typeset -A base=()
  typeset -A header=()
  typeset -A query=()
  typeset -A cookie=()

  eval $(zcl ${definition_conf_path} _zcpb::eval_string :type :key :value)

  #
  # Build header
  #
  typeset -a headers=()
  foreach k v (${(kv)header})
  do
    headers+=("-H '${k}:${v}'")
  done

  #
  # Build query
  #
  typeset queries=''
  foreach k v (${(kv)query})
  do
    if [[ -z ${queries} ]]
    then
      queries+="${k}=${v}"
      continue
    fi

    queries+="&${k}=${v}"
  done

  #
  # Build cookie
  #
  typeset cookies='Cookie:'
  foreach k v (${(kv)cookie})
  do
    cookies+=" ${k}=${v};"
  done
  cookies="-H '${cookies[1,-2]}'"

  #
  # Display result
  #
  if [[ ${modes[(I)--pretty]} != 0 ]]
  then
    local indent_heading_space='     '
    local linebreak_escape=' \'

    echo "curl ${headers[1]}${linebreak_escape}"
    foreach header_element (${headers[2,-1]})
    do
      echo "${indent_heading_space}${header_element}${linebreak_escape}"
    done
    echo "${indent_heading_space}${cookies}${linebreak_escape}"
    echo "${indent_heading_space}'${base[url]}${base[path]}?${queries}'"
  else
    echo "curl ${headers} ${cookies} '${base[url]}${base[path]}?${queries}'"
  fi
}

_zcpb::main $*
