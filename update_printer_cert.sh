#!/bin/bash

set -euo pipefail

red() {
  echo -e "\033[1;91m${*}\033[0m"
}
green() {
  echo -e "\033[1;92m${*}\033[0m"
}

ensure_certbot_dirs() {
  echo -n "Checking for certbot directories... "

  if ! stat "${HOME}/.certbot" > /dev/null; then
    red "Not Found"
    echo "Creating certbot directories..."
    mkdir -p "${HOME}/.certbot/"{log,work,config}
    green "Done"
  else
    green "Found"
  fi
}

ensure_cloudflare_api_token() {
  local cloudflare_token

  echo -n "Checking for Cloudflare API token... "

  if ! stat "${HOME}/.secrets/certbot/cloudflare.ini" > /dev/null; then
    red "Not Found"

    mkdir -p "${HOME}/.secrets/certbot"

    echo "Could not find your Cloudflare API token."
    echo -n "Cloudflare API token: "
    read -r -s cloudflare_token

    echo "dns_cloudflare_api_token = ${cloudflare_token}" > "${HOME}/.secrets/certbot/cloudflare.ini"
  else
    green "Found"
  fi
}

get_certificate() {
  local printer_domain="${1}"
  local temp_log

  temp_log="$(mktemp -t "printercert.certlog")"

  if [[ "${printer_domain}" == "" ]]; then
    echo "Please provide a domain for the certificate"
    exit 1
  fi

  echo -n "Requesting certificate... "
  if ! (certbot --config-dir "${HOME}/.certbot/config" --work-dir "${HOME}/.certbot/work" --logs-dir "${HOME}/.certbot/log"\
    certonly \
    --non-interactive --agree-tos -m hello@katiechapman.ie \
    --dns-cloudflare \
    --dns-cloudflare-credentials "${HOME}/.secrets/certbot/cloudflare.ini" \
    -d "${printer_domain}" >> "$temp_log" 2>> "$temp_log"); then
    red "Error"
    echo "There was a failure whilst generating the certificate"
    echo "You can review the logs at ${temp_log}"
    exit 1
  fi

  green "Done"
  rm "$temp_log"
}

reencode_certificate() {
  local certificate_password="${1}"
  local certificate_path="${2}"

  echo -n "Encoding certificate... "
  openssl pkcs12 -export -out "${certificate_path}" \
    -inkey "${HOME}/.certbot/config/live/printer.d08xk20.com/privkey.pem" \
    -in "${HOME}/.certbot/config/live/printer.d08xk20.com/fullchain.pem" \
    -passout "pass:${certificate_password}"
  green "Done"
}

upload_certificate_to_printer() {
  local printer_password
  local temp_log
  local printer_domain="${1}"
  local certificate_path="${2}"
  local certificate_password="${3}"

  temp_log="$(mktemp -t "printercert.printerlog")"

  echo "Setting certificate on printer... "

  echo -n "Printer password: "
  read -r -s printer_password

  curl -k -qs "https://${1}/Security/DeviceCertificates/NewCertWithPassword/Upload?fixed_response=true" \
    -X POST \
    --user "admin:${printer_password}" \
    -F "certificate=@${certificate_path}" \
    -F "password=${certificate_password}" >> "${temp_log}" 2>> "${temp_log}"

  if ! (grep -q "<err:HttpCode>201</err:HttpCode>" "${temp_log}"); then
    red "Fail"
    echo "There was a failure whilst generating the certificate"
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

ensure_certbot_dirs
ensure_cloudflare_api_token

echo
get_certificate "${1:-""}"

keypassword="$(pwgen 12 1)"
certificate_path="$(mktemp -t "printercert.certpath")"
reencode_certificate "${keypassword}" "${certificate_path}"
upload_certificate_to_printer "${1:-""}" "${certificate_path}" "${keypassword}"

rm "${certificate_path}"

echo
green "DONE"
