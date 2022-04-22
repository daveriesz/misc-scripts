#!/bin/bash

# Retrieve text products from NOAA.

# This script has NO WARRANTY.  It is not suitable for any use whatsoever.
# Do not use it.  It will ruin your day.  For informational purposes only.

rooturl="https://api.weather.gov/"

tocaps()
{
  echo "$@" | tr "[a-z]" "[A-Z]"
}

error=0
listproducts=0
listoffices=0
office=
product=

while [ $# -gt 0 ] ; do
  arg=`echo "$1" | sed "s/^\([^=]*\)=\(.*\)$/\1/g"`
  val=`echo "$1" | sed "s/^\([^=]*\)=\(.*\)$/\2/g"`
  if [ "$arg" = "" ] ; then arg="$1" ; fi
  
  case "$arg" in
    --listproducts) listproducts=1 ;;
    --listoffices) listoffices=1 ;;
    --office|ofc) office=`tocaps "$val"` ;;
    --product|prd) product=`tocaps "$val"` ;;
    *) echo "Unrecognized argument: \"$arg\"" >&2 ; error=1 ;;
  esac

  shift
done

if [ "$error" != 0 ] ; then
  echo "Exiting with error." >&2
  exit $error
fi

if [ "$office" = "" -a "$product" = "" ] ; then
  if [ "$listoffices" != 0 ] ; then
    echo "NOAA Office List:"
    officearray=`curl -s "$rooturl/offices/this_is_an_invalid_arguemnt" \
      | jq -r '.parameterErrors[0].message' \
      | sed "s/^Does not have a value in the enumeration \(\[.*\]\)$/\1/g"`
    count=`echo "$officearray" | jq length`
    for (( ii=0 ; ii<$count ; ii++ ))
    {
      ofc=`echo "$officearray" | jq -r '.['$ii']'`
      ofcdata=`curl -s -f "$rooturl/offices/$ofc"`
      if [ $? -ne 0 ] ; then continue ; fi
      echo "$ofcdata" | jq -r '"  \(.id) -- \(.name)"'
    }
  fi

  if [ "$listproducts" != 0 ] ; then
    echo "NOAA Product List:"
    curl -s "$rooturl/products/types" \
      | jq -r '."@graph"[] | "  \(.productCode) -- \(.productName)"'
  fi
elif [ "$office" != "" -a "$product" = "" -a "$listoffices" = 0 -a "$listproducts" != 0 ] ; then
  echo "Products available for office $office:"
  curl -s -f "https://api.weather.gov/products/locations/$office/types" \
  | jq -r '."@graph"[] | "  \(.productCode) -- \(.productName)"'
elif [ "$office" = "" -a "$product" != "" -a "$listoffices" != 0 -a "$listproducts" = 0 ] ; then
  echo "Offices available for product $product:"
  curl -s -f "https://api.weather.gov/products/types/$product/locations" \
  | jq -r ".locations" \
  | egrep -v "^ *[{}] *$" \
  | sed "s/^ *\"\([^\"]*\)\" *: *\"\([^\"]*\)\",* *$/  \1 -- \2/g"
elif [ "$office" != "" -a "$product" != "" -a "$listoffices" = 0 -a "$listproducts" = 0 ] ; then
  url=`curl -s "https://api.weather.gov/products/types/$product/locations/$office" \
    | jq -r '."@graph"[0]."@id"'`
  if [ "$url" = "" ] ; then
    echo "Error:  invalid product or office." >&2
  fi
  curl -s -f "$url" | jq -r '.productText'
else
  echo "Hmm.  I don't know how to handle that." >&2
  exit 1
fi
