#! /usr/bin/env zsh -f

#
# Load libraries
#
source ./lib/zcl
source ./lib/option_extension.zsh
source ./lib/array_extension.zsh

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
# Check zcl availability
#
function _zcpb::is_zcl_available()
{
  type zcl 1>/dev/null 2>/dev/null
}

#
# Show help
#
function _zcpb::show_help()
{
cat <<EOF
SYNOPSIS
  ./curl-param-gen.sh [-h] [--pretty] [-d definition-file-path] [-c configuration-file-path] ...

OPTIONS
  -h, --help : Show this message
  --pretty : Print curl command line with indent
  -d, --definition-file : Set definition file path
  -c, --configuration-file : Set configuration file path

USAGE
  1. Show curl command for configuration

    ./curl-param-gen.sh -d definition.conf -c conf1.conf -c conf2.conf

  2. Show help

    ./curl-param-gen.sh -h
EOF
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
  local -ax args=($*)

  #
  # Check args contains help option or not
  #
  foreach option_key ('-h' '--help')
  do
    local -i opt_idx=$(@array::first_index ${option_key} ${args})
    if @array::is_valid_index ${opt_idx} ${args}
    then
      _zcpb::show_help
      return 0
    fi
  done

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
    local -x result

    if @option::has_duplicated_options '-d' '--definition-file' ${args}
    then
      echo 'Found duplicated option -d/--definition-file' 1>&2
      return 1
    fi

    foreach option_key ('-d' '--definition-file')
    do
      @option::value_pop args result ${option_key}
      if [[ -n ${result} ]]
      then
        definition_conf_path=${result}
        break
      fi
    done

    if [[ -z ${definition_conf_path} ]]
    then
      echo 'Could not find the definition file' 1>&2
      return 1
    fi
  }

  # Pick up configuration paths
  local -aU user_conf_paths=()
  {
    local -x result=0

    while [[ -n ${result} ]]
    do
      # Search option
      local -i is_end=1
      result=''

      foreach option_key ('-c' '--configuration-file')
      do
        @option::value_pop args result ${option_key}
        if [[ -n ${result} ]]
        then
          break
        fi
      done

      if [[ -z ${result} ]]
      then
        break
      fi

      user_conf_paths+=(${result})
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
