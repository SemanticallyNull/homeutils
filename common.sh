red() {
  echo -e "\033[1;91m${*}\033[0m"
}
green() {
  echo -e "\033[1;92m${*}\033[0m"
}

ensure_certbot_dirs() {
  echo -n "Checking for certbot directories... "

  if ! stat "${HOME}/.certbot" > /dev/null 2> /dev/null; then
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

  if ! stat "${HOME}/.secrets/certbot/cloudflare.ini" > /dev/null 2> /dev/null; then
    red "Not Found"

    mkdir -p "${HOME}/.secrets/certbot"

    echo -n "Getting API token..."
    cloudflare_token="$(op get item gt5phu3isngmvozkqrq6c4vqjm --fields password)"

    echo "dns_cloudflare_api_token = ${cloudflare_token}" > "${HOME}/.secrets/certbot/cloudflare.ini"

    green "Done"
  else
    green "Found"
  fi
}

get_certificate() {
  local printer_domain="${1}"
  local temp_log

  temp_log="$(mktemp -t "printercert.certlog")"

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
  local printer_domain="${1}"
  local certificate_path="${2}"
  local certificate_password="${3}"

  echo -n "Encoding certificate... "
  openssl pkcs12 -export -out "${certificate_path}" \
    -inkey "${HOME}/.certbot/config/live/${printer_domain}/privkey.pem" \
    -in "${HOME}/.certbot/config/live/${printer_domain}/fullchain.pem" \
    -passout "pass:${certificate_password}"
  green "Done"
}

get_and_reencode_certificate() {
  local printer_domain="${1}"
  local certificate_path="${2}"
  local certificate_password="${3}"

  ensure_certbot_dirs
  ensure_cloudflare_api_token

  echo
  get_certificate "${printer_domain}"

  reencode_certificate "${printer_domain}" "${certificate_path}" "${certificate_password}"
}
