#!/bin/bash

set -euo pipefail

source common.sh

upload_certificate_to_printer() {
  local temp_log
  local printer_password
  local printer_domain="${1}"
  local certificate_path="${2}"
  local certificate_password="${3}"

  printer_password="$(op get item dodya7tsee44uq6m5fr6apb7im --fields password)"
  temp_log="$(mktemp -t "printercert.printerlog")"
  temp_cookie_jar="$(mktemp -t "printercert.cookiejar")"

  echo -n "Logging into printer... "

  if ! curl -k -qs "https://${printer_domain}/general/status.html" \
    -c "${temp_cookie_jar}" \
    -d "B126=${printer_password}&loginurl=/general/status.html" >> "${temp_log}" 2>> "${temp_log}"; then
    red "Fail"
    echo "There was a failure logging in to the printer"
    echo "You can review the logs at ${temp_log}"
  fi

  if ! (grep -q "AuthCookie" "${temp_cookie_jar}"); then
    red "Fail"
    echo "There was a failure logging in to the printer"
    echo "Cookie was not set after request (this means the password was probably wrong)"
    echo "You can review the logs at ${temp_log}"
    exit 1
  fi

  green "Done"

  echo -n "Installing certificate on printer... "

  if ! curl -v -k "https://${printer_domain}/net/security/certificate/import.html" \
    -X POST \
    -b "${temp_cookie_jar}" \
    -F "pageid=223" \
    -F "B136=" \
    -F "B144=" \
    -F "hidden_certificate_process_control=1" \
    -F "B54=@${certificate_path}" \
    -F "B55=${certificate_password}" \
    -F "hidden_cert_import_password=${certificate_password}" >> "${temp_log}" 2>> "${temp_log}"; then
    red "Fail"
    echo "There was a failure setting the certificate on the printer"
    echo "You can review the logs at ${temp_log}"
  fi

  if grep -q "Submit Error" "${temp_log}"; then
    red "Fail"
    echo "There was a failure setting the certificate on the printer"
    echo "You can review the logs at ${temp_log}"
    exit 1
  fi

  rm "${temp_log}" "${temp_cookie_jar}"
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
