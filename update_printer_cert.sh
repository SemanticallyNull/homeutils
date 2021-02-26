#!/bin/bash

set -euo pipefail

source common.sh

upload_certificate_to_printer() {
  local temp_log
  local printer_password
  local printer_domain="${1}"
  local certificate_path="${2}"
  local certificate_password="${3}"

  printer_password="$(op get item mgl6vaseiveh7ildbdi2v2i25a --fields password)"
  temp_log="$(mktemp -t "printercert.printerlog")"

  echo -n "Setting certificate on printer... "

  if ! curl -k -qs "https://${1}/Security/DeviceCertificates/NewCertWithPassword/Upload?fixed_response=true" \
    -X POST \
    --user "admin:${printer_password}" \
    -F "certificate=@${certificate_path}" \
    -F "password=${certificate_password}" >> "${temp_log}" 2>> "${temp_log}"; then
    red "Fail"
    echo "There was a failure whilst uploading the certificate"
    echo "You can review the logs at ${temp_log}"
  fi

  if ! (grep -q "<err:HttpCode>201</err:HttpCode>" "${temp_log}"); then
    red "Fail"
    echo "There was a failure whilst uploading the certificate"
    echo "You can review the logs at ${temp_log}"
    exit 1
  fi

  rm "${temp_log}"
  green "Done"
}

if [[ "${1:-""}x" == "x" ]]; then
  echo "You must provide the printer domain as the first arugment"
  exit 1
fi

eval "$(op signin my.1password.eu)"

certificate_password="$(pwgen 12 1)"
certificate_path="$(mktemp -t "printercert.certpath")"
get_and_reencode_certificate "${1}" "${certificate_path}" "${certificate_password}"
upload_certificate_to_printer "${1}" "${certificate_path}" "${certificate_password}"

rm "${certificate_path}"

echo
green "DONE"
