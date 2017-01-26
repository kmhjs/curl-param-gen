# curl-param-gen

Generate curl parameter from configuration file.

## Requirements

* `zsh` >= `5.2`

## Usage

1. Main script requires [kmhjs/zcl](https://github.com/kmhjs/zcl). Run `init.sh` as `./init.sh` .
    * `zcl` will be downloaded into `lib` directory.
2. Prepare your definition and configuration file.
3. Use script as `./curl-param-gen.sh ./example/definition.conf ./example/user.conf`

### Notes

* Pretty print option is available.
    * Use script as `./curl-param-gen.sh ./example/definition.conf ./example/user.conf --pretty` .

## Example

### Definition

* Available value for `:type` field
  * `base` : Base configurations
  * `header` : Header values
  * `cookie` : Cookie values
  * `query` : Query parameters

Note that value must be urlencoded value if you use constant value.

```
(
  :type  'base'
  :key   'url'
  :value '${base_url}'
)
(
  :type  'base'
  :key   'path'
  :value '${base_path}'
)

(
  :type  'header'
  :key   'type'
  :value '${header_type}'
)
(
  :type  'header'
  :key   'session_id'
  :value '${header_option}'
)

(
  :type  'query'
  :key   'name'
  :value '${query_name}'
)
(
  :type  'query'
  :key   'id'
  :value '${query_id}'
)
(
  :type  'query'
  :key   'option'
  :value '${query_option}'
)
(
  :type  'query'
  :key   'constant_field'
  :value 'constant-value'
)

(
  :type  'cookie'
  :key   'session_id'
  :value '${cookie_session_id}'
)
(
  :type  'cookie'
  :key   'option'
  :value '${cookie_option}'
)
```

### Private configuration

Following configuration is an example for example definition.  
Variable name must be matched to definition value field (if you use variable in `:value`) .

Note that value must be urlencoded value.

```
base_url='http://example.com'
base_path='/task'

header_type='sample'
header_option='header-option'

query_name='username'
query_id='0123456789'
query_option='query-option'

cookie_session_id='session-id-value-0123456789'
cookie_option='cookie-option'
```

### Result

The result for following command execution.

```
./curl-param-gen.sh ./example/definition.conf ./example/user.conf --pretty
```

```
curl -H 'session_id:header-option' \
     -H 'type:sample' \
     -H 'Cookie: session_id=session-id-value-0123456789; option=cookie-option' \
     'http://example.com/task?option=query-option&constant_field=constant-value&id=0123456789&name=username'
```


## License

See `LICENSE`.
