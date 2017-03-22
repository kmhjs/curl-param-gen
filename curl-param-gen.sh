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
  if [[ ${args[(i)${options[1]}]} == $((${#args} + 1)) ]]
  then
    return 0
  fi

  if [[ ${args[(i)${options[2]}]} != $((${#args} + 1)) ]]
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
function _zcpb::get_option_index()
{
  local option_key=$1
  shift

  local -i idx=${*[(i)${option_key}]}
  if [[ ${idx} == $# ]]
  then
    return 1
  fi

  echo ${idx}
  return 0
}

#
# Check zcl availability
#
function _zcpb::is_zcl_available()
{
  type zcl 1>/dev/null 2>/dev/null
}

#
# Check given index is valid for array
#
# Note: For index validation of (i) option result
#
# @param index value [1..N]
# @param Target array
#
function _zcpb::is_valid_index_for_array()
{
  local -i index=$1
  shift

  (( ${index} < $(($# + 1)) ))
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
  local -a args=($*)

  if ! _zcpb::is_zcl_available
  then
    echo "Error: zcl unavailable." 1>&2
    return 1
  fi

  #
  # Pickup parameters
  #
  # * Pickup parameter value, and remove from args list
  #

  # Pick up definition file path
  local definition_conf_path
  {
    local -i opt_idx

    if ! _zcpb::verify_no_duplicated_options '-d' '--definition-file' ${args}
    then
      echo 'Found duplicated option -d/--definition-file' 1>&2
      return 1
    fi

    foreach option_key ('-d' '--definition-file')
    do
      opt_idx=$(_zcpb::get_option_index ${option_key} ${args})
      if _zcpb::is_valid_index_for_array ${opt_idx} ${args}
      then
        definition_conf_path=${args[$((${opt_idx} + 1))]}
        args[${opt_idx},$((${opt_idx} + 1))]=()
        break
      else
        echo 'Could not find the definition file' 1>&2
        return 1
      fi
    done
  }

  # Pick up configuration paths
  local -aU user_conf_paths=()
  {
    local -i opt_idx=0
    local opt_value

    while _zcpb::is_valid_index_for_array ${opt_idx} ${args}
    do
      # Set invalid value
      opt_idx=$((${#args} + 1))

      # Search option
      local -i is_end=1
      foreach option_key ('-c' '--configuration-file')
      do
        opt_idx=$(_zcpb::get_option_index ${option_key} ${args})
        if _zcpb::is_valid_index_for_array ${opt_idx} ${args}
        then
          is_end=0
          break
        fi
      done

      if (( ${is_end} == 1 ))
      then
        break
      fi

      opt_value=${args[$((${opt_idx} + 1))]}
      if [[ -z ${opt_value} ]]
      then
        break
      fi

      args[${opt_idx},$((${opt_idx} + 1))]=()
      user_conf_paths+=(${opt_value})
    done

    if (( ${#user_conf_paths} == 0 ))
    then
      echo 'Could not find the configuration file' 1>&2
      return 1
    fi
  }

  # Pick up modes
  local -a modes=(${args})

  #
  # Validate variables
  #
  {
    if [[ ! -f ${definition_conf_path} ]]
    then
      echo "Error: Definition configuration file not found" 1>&2
      return 1
    fi

    foreach user_conf_path (${user_conf_paths})
    do
      if [[ ! -f ${user_conf_path} ]]
      then
        echo "Error: User configuration file not found" 1>&2
        return 1
      fi
    done
  }
  #
  # Import user configuration as variable
  #
  foreach user_conf_path (${user_conf_paths})
  do
    source ${user_conf_path}
  done

  #
  # Map values to associated array
  #
  local -A base=()
  local -A header=()
  local -A query=()
  local -A cookie=()
  {
    eval $(zcl ${definition_conf_path} _zcpb::eval_string :type :key :value)
  }

  #
  # Build header
  #
  local -a headers=()
  {
    foreach k v (${(kv)header})
    do
      headers+=("-H '${k}:${v}'")
    done
  }

  #
  # Build query
  #
  local queries=''
  {
    foreach k v (${(kv)query})
    do
      if [[ -z ${queries} ]]
      then
        queries+="${k}=${v}"
        continue
      fi

      queries+="&${k}=${v}"
    done
  }

  #
  # Build cookie
  #
  local cookies='Cookie:'
  {
    foreach k v (${(kv)cookie})
    do
      cookies+=" ${k}=${v};"
    done
    cookies="-H '${cookies[1,-2]}'"
  }

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
