#!/usr/bin/env bash

set -euo pipefail

ORB_VERSION="0.1.0"
ORB_HOME="${HOME}/.orb"
ORB_CACHE="${ORB_HOME}/cache"
ORB_INSTALLED="${ORB_HOME}/installed"
ORB_REPOS="${ORB_HOME}/repos"
OFFICIAL_REPO="https://github.com/stringmanolo/orbpackages"
USER_AGENT="orb/${ORB_VERSION}"

mkdir -p "${ORB_HOME}" "${ORB_CACHE}" "${ORB_INSTALLED}" "${ORB_REPOS}"

log() {
  echo "[orb] $*"
}

debug() {
  if [[ "${ORB_DEBUG:-0}" != "0" ]]; then
    echo "[orb:debug] $*" >&2
  fi
}

error() {
  echo "[orb:error] $*" >&2
}

die() {
  error "$@"
  debug "Stack trace:"
  local frame=0
  while caller $frame; do
    frame=$((frame + 1))
  done >&2
  exit 1
}

download() {
  debug "Entering download function"
  debug "  URL: $1"
  debug "  Output: $2"
  
  local url="$1"
  local output="$2"
  local max_retries=3
  local retry_count=0
  local curl_exit=0
  
  # Limpiar URL de comillas adicionales
  url="$(echo "$url" | sed "s/^'//;s/'$//")"
  debug "Cleaned URL: '$url'"
  
  while [[ $retry_count -lt $max_retries ]]; do
    retry_count=$((retry_count + 1))
    debug "Download attempt $retry_count of $max_retries"
    
    if command -v curl &>/dev/null; then
      debug "Using curl with enhanced options"
      
      # Opciones mejoradas para curl:
      # -L: Sigue redirecciones
      # -f: Fall silenciosamente en errores HTTP
      # -s: Modo silencioso
      # -S: Muestra errores incluso en modo silencioso
      # -A: User-Agent específico
      # -H: Headers adicionales para GitHub
      # --retry: Reintentar en fallos temporales
      # --retry-delay: Esperar entre reintentos
      # --retry-max-time: Tiempo máximo para reintentos
      
      curl -fsSL \
           -A "${USER_AGENT}" \
           -H "Accept: application/vnd.github.v3.raw" \
           -H "Accept: text/plain" \
           --retry 2 \
           --retry-delay 1 \
           --retry-max-time 30 \
           -o "${output}" \
           "${url}" 2>&1 | while read -r line; do
        debug "curl: $line"
      done
      
      curl_exit=${PIPESTATUS[0]}
      
    elif command -v wget &>/dev/null; then
      debug "Using wget with enhanced options"
      
      wget -q \
           --user-agent="${USER_AGENT}" \
           --header="Accept: application/vnd.github.v3.raw" \
           --header="Accept: text/plain" \
           --tries=3 \
           --timeout=30 \
           -O "${output}" \
           "${url}" 2>&1 | while read -r line; do
        debug "wget: $line"
      done
      
      curl_exit=${PIPESTATUS[0]}
    else
      die "curl or wget required"
    fi
    
    if [[ $curl_exit -eq 0 ]]; then
      if [[ -f "${output}" ]] && [[ -s "${output}" ]]; then
        debug "Download successful on attempt $retry_count"
        debug "File size: $(wc -c < "${output}") bytes"
        debug "First 100 chars of content:"
        head -c 100 "${output}" 2>/dev/null | while read -r line; do
          debug "  $line"
        done
        return 0
      else
        debug "File created but empty or doesn't exist"
        if [[ -f "${output}" ]]; then
          debug "File exists but size is $(wc -c < "${output}") bytes"
        fi
      fi
    else
      debug "Download failed with exit code: $curl_exit"
      
      # Si tenemos el archivo de salida, mostramos su contenido para debugging
      if [[ -f "${output}" ]]; then
        debug "Response content (first 500 chars):"
        head -c 500 "${output}" 2>/dev/null | cat -v | while read -r line; do
          debug "  $line"
        done
      fi
    fi
    
    # Esperar antes de reintentar (solo si no fue el último intento)
    if [[ $retry_count -lt $max_retries ]]; then
      debug "Waiting 1 second before retry..."
      sleep 1
    fi
  done
  
  error "Failed to download after $max_retries attempts"
  error "URL: ${url}"
  error "Last exit code: $curl_exit"
  
  # Mostrar más información si el archivo existe
  if [[ -f "${output}" ]]; then
    error "Output file exists with size: $(wc -c < "${output}") bytes"
    error "First 200 chars of file:"
    head -c 200 "${output}" 2>/dev/null | cat -v | sed 's/^/  /'
  fi
  
  return 1
}

download_content() {
  debug "Entering download_content function"
  debug "  URL: $1"
  
  local url="$1"
  
  if command -v curl &>/dev/null; then
    debug "Using curl for content download"
    
    if [[ -n "${ORB_DEBUG}" ]]; then
      debug "curl command: curl -sSLf -A \"${USER_AGENT}\" -w \"%{http_code}\n%{size_download}\" \"${url}\""
      local temp_file
      temp_file="$(mktemp)"
      local http_info
      http_info="$(curl -sSLf -A "${USER_AGENT}" -w "%{http_code}\n%{size_download}" -o "${temp_file}" "${url}" 2>&1)"
      local curl_exit=$?
      debug "curl exit code: $curl_exit"
      debug "curl stderr output: ${http_info}"
      
      if [[ -n "${http_info}" ]]; then
        local http_code
        http_code="$(echo "${http_info}" | head -n1)"
        local size_downloaded
        size_downloaded="$(echo "${http_info}" | tail -n1)"
        debug "HTTP response code: ${http_code}"
        debug "Bytes downloaded: ${size_downloaded}"
      fi
      
      if [[ $curl_exit -ne 0 ]]; then
        debug "curl failed with exit code: $curl_exit"
        if [[ -f "${temp_file}" ]]; then
          debug "Response content (first 200 chars): $(head -c 200 "${temp_file}" 2>/dev/null || echo "no content")"
          rm -f "${temp_file}"
        fi
        return $curl_exit
      fi
      
      local content
      content="$(cat "${temp_file}" 2>/dev/null || echo "")"
      debug "Downloaded content length: ${#content} characters"
      debug "First 500 chars of content:"
      echo "${content:0:500}" | while IFS= read -r line; do
        debug "  $line"
      done
      
      echo "${content}"
      rm -f "${temp_file}"
    else
      curl -sSLf -A "${USER_AGENT}" "${url}" 2>/dev/null
    fi
    
  elif command -v wget &>/dev/null; then
    debug "Using wget for content download"
    
    if [[ -n "${ORB_DEBUG}" ]]; then
      debug "wget command: wget --user-agent=\"${USER_AGENT}\" -O- \"${url}\""
      local temp_file
      temp_file="$(mktemp)"
      wget --user-agent="${USER_AGENT}" -O "${temp_file}" "${url}" 2>&1 | while read -r line; do
        debug "wget: $line"
      done
      local wget_exit=$?
      debug "wget exit code: $wget_exit"
      
      if [[ $wget_exit -ne 0 ]]; then
        debug "wget failed with exit code: $wget_exit"
        if [[ -f "${temp_file}" ]]; then
          debug "Response content (first 200 chars): $(head -c 200 "${temp_file}" 2>/dev/null || echo "no content")"
          rm -f "${temp_file}"
        fi
        return $wget_exit
      fi
      
      local content
      content="$(cat "${temp_file}" 2>/dev/null || echo "")"
      debug "Downloaded content length: ${#content} characters"
      
      echo "${content}"
      rm -f "${temp_file}"
    else
      wget -q --user-agent="${USER_AGENT}" -O- "${url}" 2>/dev/null
    fi
    
  else
    die "curl or wget required but not found"
  fi
}


download_with_fallback() {
  debug "Entering download_with_fallback function"
  debug "  Repo URL: $1"
  debug "  File path: $2"
  debug "  Output: ${3:-not specified}"
  
  local repo_url="$1"
  local file_path="$2"
  local output="${3:-}"
  
  # Limpiar repo_url de comillas
  repo_url="$(echo "$repo_url" | sed "s/^'//;s/'$//")"
  
  local main_url="${repo_url}/raw/main/${file_path}"
  local master_url="${repo_url}/raw/master/${file_path}"
   
  debug "Trying main branch URL: ${main_url}"
  
  if command -v curl &>/dev/null; then
    debug "Using curl for fallback download"
    local http_code
    local curl_output
    
    if [[ -n "${output}" ]]; then
      curl_output="$(curl -sSL -A "${USER_AGENT}" -w "%{http_code}" -o "${output}" "${main_url}" 2>&1)"
      http_code="$(echo "${curl_output}" | tail -n1)"
      debug "curl output (last line): ${http_code}"
    else
      curl_output="$(curl -sSL -A "${USER_AGENT}" -w "%{http_code}" -o /dev/null "${main_url}" 2>&1)"
      http_code="$(echo "${curl_output}" | tail -n1)"
      debug "curl output (last line): ${http_code}"
    fi
    
    if [[ "${http_code}" == "200" ]]; then
      debug "Successfully downloaded from main branch (HTTP 200)"
      return 0
    else
      debug "Main branch failed with HTTP code: ${http_code}"
    fi
    
    debug "Trying master branch URL: ${master_url}"
    
    if [[ -n "${output}" ]]; then
      curl_output="$(curl -sSL -A "${USER_AGENT}" -w "%{http_code}" -o "${output}" "${master_url}" 2>&1)"
      http_code="$(echo "${curl_output}" | tail -n1)"
      debug "curl output (last line): ${http_code}"
    else
      curl_output="$(curl -sSL -A "${USER_AGENT}" -w "%{http_code}" -o /dev/null "${master_url}" 2>&1)"
      http_code="$(echo "${curl_output}" | tail -n1)"
      debug "curl output (last line): ${http_code}"
    fi
    
    if [[ "${http_code}" == "200" ]]; then
      debug "Successfully downloaded from master branch (HTTP 200)"
      return 0
    else
      debug "Master branch failed with HTTP code: ${http_code}"
    fi
    
  elif command -v wget &>/dev/null; then
    debug "Using wget for fallback download"
    
    debug "Trying main branch with wget"
    if wget -q --user-agent="${USER_AGENT}" -O "${output:-/dev/null}" "${main_url}" 2>&1; then
      debug "Successfully downloaded from main branch using wget"
      return 0
    else
      debug "Main branch download failed with wget"
    fi
    
    debug "Trying master branch with wget"
    if wget -q --user-agent="${USER_AGENT}" -O "${output:-/dev/null}" "${master_url}" 2>&1; then
      debug "Successfully downloaded from master branch using wget"
      return 0
    else
      debug "Master branch download failed with wget"
    fi
    
  else
    die "curl or wget required but not found"
  fi
  
  error "File not found: ${file_path}"
  error "Tried URLs:"
  error "  ${main_url}"
  error "  ${master_url}"
  error "Make sure file exists and that branch is either main or master"
  return 1
}

download_orb_config() {
  debug "Entering download_orb_config function"
  debug "  Repo URL: $1"
  debug "  Output: ${2:-not specified}"
  
  local repo_url="$1"
  local output="${2:-}"
  
  download_with_fallback "${repo_url}" "orb.config" "${output}"
  local exit_code=$?
  
  if [[ $exit_code -eq 0 ]]; then
    debug "Successfully downloaded orb.config from ${repo_url}"
  else
    error "Failed to download orb.config from ${repo_url}"
  fi
  
  return $exit_code
}

parse_config() {
  debug "Entering parse_config function"
  debug "  Config file: $1"
  
  local config_file="$1"
  declare -gA config
  
  debug "Clearing config array"
  for key in "${!config[@]}"; do
    unset "config[$key]"
  done
  
  if [[ ! -f "${config_file}" ]] || [[ ! -s "${config_file}" ]]; then
    debug "Config file does not exist or is empty: ${config_file}"
    return 1
  fi
  
  debug "Config file exists and has $(wc -l < "${config_file}") lines"
  
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    debug "Processing line $line_num: '${line}'"
    
    if [[ "${line}" =~ ^[[:space:]]*files: ]]; then
      debug "Found files section at line $line_num, stopping parsing"
      break
    fi
    
    # Expresión regular que captura clave y valor (con o sin comillas)
    if [[ "${line}" =~ ^[[:space:]]*([^=]+)=['\"]?(.*)['\"]?$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      
      # Limpiar espacios y comillas del key
      key="$(echo "${key}" | sed 's/[[:space:]]*$//')"
      
      # Limpiar comillas adicionales del value
      value="$(echo "${value}" | sed -e "s/^['\"]//" -e "s/['\"]$//")"
      
      debug "  Parsed key='${key}' value='${value}'"
      config["${key}"]="${value}"
    else
      debug "  Line $line_num doesn't match key=value pattern"
    fi
  done < "${config_file}"
  
  debug "Finished parsing config. Found ${#config[@]} keys:"
  for key in "${!config[@]}"; do
    debug "  ${key}=${config[$key]}"
  done
  
  return 0
}

add_insecure_repo() {
  debug "Entering add_insecure_repo function"
  debug "  Repository URL: $1"
  
  local repo_url="$1"
  local repo_name
  repo_name="$(basename "${repo_url}" .git)"
  debug "  Repository name derived: ${repo_name}"
  
  debug "Testing repository by downloading orb.config"
  if ! download_orb_config "${repo_url}" "/tmp/orb_repo_test"; then
    die "Invalid repository: no orb.config found at ${repo_url}"
  fi
  
  if ! grep -q "type=" "/tmp/orb_repo_test"; then
    error "Downloaded orb.config is malformed. Content:"
    cat "/tmp/orb_repo_test" >&2
    rm -f "/tmp/orb_repo_test"
    die "Invalid repository: malformed orb.config at ${repo_url}"
  fi
  
  debug "Repository validation successful. Adding to ${ORB_REPOS}/${repo_name}"
  echo "${repo_url}" > "${ORB_REPOS}/${repo_name}"
  
  if [[ ! -f "${ORB_REPOS}/${repo_name}" ]]; then
    error "Failed to create repository file: ${ORB_REPOS}/${repo_name}"
    return 1
  fi
  
  log "Added repository: ${repo_name}"
  debug "Repository file created successfully"
  rm -f "/tmp/orb_repo_test"
}

list_repos() {
  debug "Entering list_repos function"
  debug "  ORB_REPOS directory: ${ORB_REPOS}"
  
  if [[ ! -d "${ORB_REPOS}" ]]; then
    debug "ORB_REPOS directory doesn't exist"
    return
  fi
  
  local repo_count=0
  for repo_file in "${ORB_REPOS}"/*; do
    [[ -f "${repo_file}" ]] || continue
    repo_count=$((repo_count + 1))
    debug "  Found repo file: ${repo_file}"
    cat "${repo_file}"
  done
  
  if [[ $repo_count -eq 0 ]]; then
    debug "No repository files found in ${ORB_REPOS}"
  else
    debug "Total repositories found: ${repo_count}"
  fi
}


fetch_official_packages() {
  debug "Entering fetch_official_packages function"
  
  local main_url="${OFFICIAL_REPO}/raw/main/orb.config"
  local master_url="${OFFICIAL_REPO}/raw/master/orb.config"
  
  debug "Trying main branch URL: ${main_url}"
  
  local content
  local exit_code=0
  
  # Usar un enfoque diferente para evitar capturar mensajes de debug
  if [[ -n "${ORB_DEBUG}" ]]; then
    debug "Using debug-aware download method"
    # En modo debug, descargar a un archivo temporal primero
    local temp_file
    temp_file="$(mktemp)"
    
    if command -v curl &>/dev/null; then
      debug "curl command: curl -sSLf -A \"${USER_AGENT}\" -o \"${temp_file}\" \"${main_url}\""
      curl -sSLf -A "${USER_AGENT}" -o "${temp_file}" "${main_url}" 2>/dev/null
      exit_code=$?
    elif command -v wget &>/dev/null; then
      debug "wget command: wget -q --user-agent=\"${USER_AGENT}\" -O \"${temp_file}\" \"${main_url}\""
      wget -q --user-agent="${USER_AGENT}" -O "${temp_file}" "${main_url}" 2>/dev/null
      exit_code=$?
    fi
    
    if [[ $exit_code -eq 0 ]] && [[ -s "${temp_file}" ]]; then
      content="$(cat "${temp_file}")"
      debug "Downloaded ${#content} bytes from main branch"
      rm -f "${temp_file}"
    else
      debug "Main branch download failed with exit code: $exit_code"
      rm -f "${temp_file}"
    fi
  else
    # Sin debug, usar la función normal
    content="$(download_content "${main_url}" 2>/dev/null)"
    exit_code=$?
  fi
  
  if [[ $exit_code -eq 0 ]] && [[ -n "${content}" ]] && echo "${content}" | grep -q "type="; then
    debug "Successfully fetched official packages from main branch"
    # Solo devolver el contenido puro, sin mensajes de debug
    echo "${content}"
    return 0
  else
    debug "Main branch fetch failed or returned empty/invalid content"
    debug "Exit code: $exit_code"
    debug "Content empty? $([[ -z "${content}" ]] && echo "YES" || echo "NO")"
  fi
  
  debug "Trying master branch URL: ${master_url}"
  
  # Repetir para master branch
  if [[ -n "${ORB_DEBUG}" ]]; then
    debug "Trying master branch with debug-aware method"
    temp_file="$(mktemp)"
    
    if command -v curl &>/dev/null; then
      debug "curl command: curl -sSLf -A \"${USER_AGENT}\" -o \"${temp_file}\" \"${master_url}\""
      curl -sSLf -A "${USER_AGENT}" -o "${temp_file}" "${master_url}" 2>/dev/null
      exit_code=$?
    elif command -v wget &>/dev/null; then
      debug "wget command: wget -q --user-agent=\"${USER_AGENT}\" -O \"${temp_file}\" \"${master_url}\""
      wget -q --user-agent="${USER_AGENT}" -O "${temp_file}" "${master_url}" 2>/dev/null
      exit_code=$?
    fi
    
    if [[ $exit_code -eq 0 ]] && [[ -s "${temp_file}" ]]; then
      content="$(cat "${temp_file}")"
      debug "Downloaded ${#content} bytes from master branch"
      rm -f "${temp_file}"
    else
      debug "Master branch download failed with exit code: $exit_code"
      rm -f "${temp_file}"
    fi
  else
    content="$(download_content "${master_url}" 2>/dev/null)"
    exit_code=$?
  fi
  
  if [[ $exit_code -eq 0 ]] && [[ -n "${content}" ]] && echo "${content}" | grep -q "type="; then
    debug "Successfully fetched official packages from master branch"
    echo "${content}"
    return 0
  else
    error "Failed to fetch official packages from both main and master branches"
    error "Official repository: ${OFFICIAL_REPO}"
    error "Last exit code: $exit_code"
    return 1
  fi
}

fetch_repo_packages() {
  debug "Entering fetch_repo_packages function"
  debug "  Repository URL: $1"
  
  local repo_url="$1"
  
  debug "Trying to fetch from main branch"
  local content
  content="$(download_content "${repo_url}/raw/main/orb.config" 2>/dev/null || true)"
  
  if [[ -n "${content}" ]] && echo "${content}" | grep -q "type="; then
    debug "Successfully fetched repo packages from main branch"
    echo "${content}"
    return 0
  else
    debug "Main branch fetch failed for ${repo_url}"
  fi
  
  debug "Trying to fetch from master branch"
  content="$(download_content "${repo_url}/raw/master/orb.config" 2>/dev/null || true)"
  
  if [[ -n "${content}" ]] && echo "${content}" | grep -q "type="; then
    debug "Successfully fetched repo packages from master branch"
    echo "${content}"
    return 0
  else
    error "Failed to fetch packages from ${repo_url}"
    error "Tried both main and master branches"
    return 1
  fi
}

#debug
find_package_in_repo() {
  local repo_url="$1"
  local package_name="$2"

  debug "Entering find_package_in_repo"
  debug "  Repository URL: ${repo_url}"
  debug "  Package name: ${package_name}"

  local repo_content
  repo_content="$(fetch_repo_packages "${repo_url}" 2>/dev/null || true)"

  if [[ -z "${repo_content}" ]]; then
    debug "No content found for repo: ${repo_url}"
    return 1
  fi

  debug "Repo content length: ${#repo_content} characters"

  # Buscar líneas que comiencen con packageX=
  while IFS= read -r line; do
    debug "Processing line: '${line}'"

    if [[ "${line}" =~ ^package[0-9]+= ]]; then
      local package_url="${line#*=}"
      package_url="$(echo "${package_url}" | sed "s/^['\"]//;s/['\"]$//")"

      debug "Found package URL: ${package_url}"

      # Descargar el orb.config de este paquete
      local config_file
      config_file="$(mktemp)"

      if download_orb_config "${package_url}" "${config_file}"; then
        local package_content
        package_content="$(cat "${config_file}" 2>/dev/null || echo "")"
        rm -f "${config_file}"

        if echo "${package_content}" | grep -q "packageName='${package_name}'"; then
          debug "Package found: ${package_name} at ${package_url}"
          echo "${package_url}"
          return 0
        else
          debug "Package name does not match. Looking for '${package_name}'"
        fi
      else
        debug "Failed to download orb.config from: ${package_url}"
        rm -f "${config_file}"
      fi
    fi
  done <<< "${repo_content}"

  debug "Package '${package_name}' not found in repo: ${repo_url}"
  return 1
}

search_package() {
  debug "Entering search_package function"
  debug "  Package: $1"
  debug "  Version: ${2:-not specified}"

  local package="$1"
  local version="${2:-}"
  local found=()

  log "Searching in official repository..."
  local package_url
  if package_url="$(find_package_in_repo "${OFFICIAL_REPO}" "${package}")"; then
    debug "Found package '${package}' in official repository at: ${package_url}"
    found+=("official::${package_url}")
  else
    debug "Package '${package}' NOT found in official repository"
  fi

  debug "Checking user repositories"
  local repo_list
  repo_list="$(list_repos)"
  if [[ -n "${repo_list}" ]]; then
    debug "Found $(echo "${repo_list}" | wc -l) user repositories"
    while IFS= read -r repo; do
      [[ -z "${repo}" ]] && continue
      debug "Searching in repository: ${repo}"
      log "Searching in ${repo}..."
      if package_url="$(find_package_in_repo "${repo}" "${package}")"; then
        debug "Found package '${package}' in repository: ${repo} at ${package_url}"
        found+=("unofficial::${package_url}")
      else
        debug "Package '${package}' NOT found in repository: ${repo}"
      fi
    done <<< "${repo_list}"
  else
    debug "No user repositories configured"
  fi

  debug "Search complete. Found ${#found[@]} location(s)"

  if [[ ${#found[@]} -eq 0 ]]; then
    error "Package '${package}' not found in any repository"
    return 1
  fi

  debug "Package found in locations:"
  for location in "${found[@]}"; do
    echo "${location}"
    debug "  ${location}"
  done
}

install_package() {
  debug "Entering install_package function"
  
  local package=""
  local allow_insecure=false
  local version=""
  local install_type="local"
  
  debug "Parsing arguments: $*"
  
  # Parsear todos los argumentos
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --allow-insecure-repos)
        allow_insecure=true
        debug "Found --allow-insecure-repos flag"
        shift
        ;;
      --global)
        install_type="global"
        debug "Found --global flag"
        shift
        ;;
      --*)
        debug "Ignoring unknown flag: $1"
        shift
        ;;
      *)
        if [[ -z "$package" ]]; then
          package="$1"
          debug "Package name: $package"
        elif [[ -z "$version" ]]; then
          version="$1"
          debug "Version: $version"
        else
          debug "Ignoring extra argument: $1"
        fi
        shift
        ;;
    esac
  done
  
  if [[ -z "$package" ]]; then
    die "Package name required"
  fi
  
  debug "Final parsed values:"
  debug "  Package: $package"
  debug "  Allow insecure: $allow_insecure"
  debug "  Version: ${version:-latest}"
  debug "  Install type: $install_type"
  
  if [[ "$allow_insecure" == "false" ]]; then
    debug "Checking official repository only (insecure repos not allowed)"
    local package_url
    if package_url="$(find_package_in_repo "$OFFICIAL_REPO" "$package")"; then
      debug "Package found in official repository at: $package_url"
      install_from_repo "$package" "$package_url" "$version" "$install_type"
    else
      debug "Package '$package' not found in official repository"
      die "Package '$package' not found in official repository. Use --allow-insecure-repos to search in all repositories"
    fi
  else
    debug "Searching in all repositories (insecure allowed)"
    local locations
    locations="$(search_package "$package" "$version")" || exit 1
    
    if [[ $(echo "$locations" | wc -l) -gt 1 ]]; then
      debug "Multiple locations found, asking user to choose"
      log "Multiple locations found for '$package':"
      local i=1
      while IFS= read -r location; do
        echo "  $i) $location"
        i=$((i + 1))
      done <<< "$locations"
      
      read -rp "Select number (1-$((i-1))): " choice
      debug "User selected option: $choice"
      
      if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt $((i-1)) ]]; then
        die "Invalid selection: $choice"
      fi
      
      local selected
      selected="$(echo "$locations" | sed -n "${choice}p")"
      debug "Selected location: $selected"
      local repo="${selected#*::}"
      install_from_repo "$package" "$repo" "$version" "$install_type"
    else
      debug "Single location found"
      local repo="${locations#*::}"
      debug "Installing from: $repo"
      install_from_repo "$package" "$repo" "$version" "$install_type"
    fi
  fi
}

install_from_repo() {
  debug "Entering install_from_repo function"
  debug "  Package: $1"
  debug "  Repository: $2"
  debug "  Version: ${3:-not specified}"
  debug "  Install type: ${4:-not specified}"
  
  local package="$1"
  local repo="$2"
  local version="$3"
  local install_type="${4:-local}"
  
  debug "Parsed install_type: '${install_type}'"
  
  # Determinar el directorio de instalación basado en el tipo
  local install_base
  if [[ "${install_type}" == "global" ]]; then
    install_base="${ORB_INSTALLED}"
    debug "Global installation to: ${install_base}"
  else
    # Local installation to current directory
    install_base="$(pwd)/.orb/installed"
    debug "Local installation to: ${install_base}"
    
    # Crear directorio .orb si no existe
    mkdir -p "${install_base}"
    debug "Created local directory: ${install_base}"
  fi
  
  debug "Creating temporary config file"
  local config_file
  config_file="$(mktemp)"
  debug "Temporary config file: ${config_file}"
  
  debug "Downloading orb.config from ${repo}"
  if ! download_orb_config "${repo}" "${config_file}"; then
    debug "Failed to download orb.config, removing temp file"
    rm -f "${config_file}"
    die "Failed to download orb.config from ${repo}"
  fi
  
  debug "Config file downloaded successfully"
  debug "Config file content (first 30 lines):"
  head -n 30 "${config_file}" | while IFS= read -r line; do
    debug "  $line"
  done
  
  debug "Parsing config file"
  if ! parse_config "${config_file}"; then
    error "Failed to parse config file"
    debug "Config file content for debugging:"
    cat "${config_file}" >&2
    rm -f "${config_file}"
    die "Invalid config file from ${repo}"
  fi
  
  debug "Validating package name"
  if [[ "${config[packageName]}" != "${package}" ]]; then
    debug "Package mismatch: expected '${package}', found '${config[packageName]}'"
    debug "Available keys in config: ${!config[@]}"
    rm -f "${config_file}"
    die "Package mismatch in config. Expected '${package}', found '${config[packageName]}'"
  fi
  
  local install_version="${version:-${config[version]}}"
  debug "Install version determined: ${install_version}"
  
  local install_dir="${install_base}/${package}/${install_version}"
  debug "Install directory: ${install_dir}"
  
  debug "Creating install directory"
  mkdir -p "${install_dir}"
  
  debug "Saving repository source"
  echo "${repo}" > "${install_dir}/.source"
  
  debug "Copying config file to install directory"
  cp "${config_file}" "${install_dir}/orb.config"
  
  debug "Processing files section"
  local files_section=false
  local file_count=0
  
  debug "Reading config file for files section"
  while IFS= read -r line; do
    debug "DEBUG TOP - files_section=${files_section}, file_count=${file_count}"
    debug "Read line: '${line}'"
    
    if [[ "${line}" =~ ^[[:space:]]*files: ]]; then
      debug "Entered files section"
      files_section=true
      continue
    fi
    
    if [[ "${files_section}" == true ]]; then
      debug "DEBUG - INSIDE files_section"
      
      if [[ "${line}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*= ]] && [[ -n "${line// }" ]]; then
        debug "DEBUG - BREAKING: Found new key-value pair"
        break
      fi
      
      if [[ -z "${line// }" ]]; then
        debug "Skipping empty line"
        continue
      fi
      
      debug "Processing file entry: '${line}'"
      
      local clean_line="${line#"${line%%[![:space:]]*}"}"
      clean_line="${clean_line%"${clean_line##*[![:space:]]}"}"
      
      debug "Clean line: '${clean_line}'"
      
      if [[ "${clean_line}" =~ ^\"([^\"]+)\" ]]; then
        local file_name="${BASH_REMATCH[1]}"
        debug "Found file name: '${file_name}'"
        
        local remaining="${clean_line#*\"${file_name}\"}"
        debug "Remaining after file name: '${remaining}'"
        
        remaining="$(echo "$remaining" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")"
        debug "Cleaned remaining: '${remaining}'"
        
        local file_url="${remaining}"
        file_url="$(echo "$file_url" | sed "s/^'//;s/'$//;s/'$//")"
        
        debug "DEBUG - After extraction:"
        debug "  file_url='${file_url}'"
        debug "  file_url length: ${#file_url}"
        debug "  Is file_url non-empty? $([[ -n "$file_url" ]] && echo "YES" || echo "NO")"
        debug "  Does file_url match http(s) pattern? $([[ "$file_url" =~ ^https?:// ]] && echo "YES" || echo "NO")"
        debug "  file_count before increment: ${file_count}"
        
        if [[ -n "$file_url" ]] && [[ "$file_url" =~ ^https?:// ]]; then
          file_count=$((file_count + 1))
          debug "DEBUG - AFTER INCREMENT: file_count=${file_count}"
          debug "File #${file_count}:"
          debug "  Name: ${file_name}"
          debug "  URL: ${file_url}"
          
          local file_dir
          file_dir="$(dirname "${install_dir}/${file_name}")"
          if [[ "${file_dir}" != "." ]] && [[ "${file_dir}" != "${install_dir}" ]]; then
            debug "Creating directory: ${file_dir}"
            mkdir -p "${file_dir}"
          fi
          
          debug "Downloading file from: ${file_url}"
          if download "${file_url}" "${install_dir}/${file_name}"; then
            debug "Successfully downloaded ${file_name}"
            debug "File size: $(wc -c < "${install_dir}/${file_name}") bytes"
            debug "First 5 lines of file:"
            head -n 5 "${install_dir}/${file_name}" 2>/dev/null | while IFS= read -r content_line; do
              debug "  $content_line"
            done
          else
            error "Failed to download ${file_name} from ${file_url}"
          fi
        else
          error "Invalid URL extracted: '${file_url}'"
          debug "Original line was: '${line}'"
        fi
      else
        debug "File name not found between double quotes"
      fi
    fi
  done < "${config_file}"
  
  debug "Processed ${file_count} files"
  
  local bundle_files="${config[bundleFiles]:-false}"

  if [[ "${bundle_files}" == "true" ]]; then
    debug "Bundle requested. Bundle files: ${bundle_files}"
    local bundle_name="${config[bundleFileName]:-${config[packageName]}}"
    debug "Bundle file name: ${bundle_name}"
    bundle_package "${install_dir}" "${config[packageName]}" "${bundle_name}"
  else
    debug "Bundle not requested or not specified"
  fi

  debug "Saving installation metadata"
  echo "${install_version} ${repo} $(date -Iseconds)" >> "${install_base}/${package}.meta"
  
  if [[ "${install_type}" == "local" ]]; then
    debug "Updating project dependencies for local installation"
    create_or_update_orb_json "${package}" "${install_version}"
  else
    debug "Skipping orb.json update for global installation"
  fi
  
  log "Installed ${package} ${install_version} (${install_type})"
  
  debug "Installation directory contents:"
  find "${install_dir}" -type f 2>/dev/null | while IFS= read -r file; do
    debug "  $(basename "${file}") - $(wc -c < "${file}") bytes"
  done
  
  debug "Cleaning up temporary config file"
  rm -f "${config_file}"
}

bundle_package() {
  debug "Entering bundle_package function"
  debug "  Directory: $1"
  debug "  Package name: $2"
  debug "  Bundle name: $3"
  
  local dir="$1"
  local package_name="$2"
  local bundle_name="${3:-${package_name}}"
  
  local bundle_file="${dir}/${bundle_name}.sh"
  debug "Bundle file: ${bundle_file}"
  
  cat > "${bundle_file}" <<EOF
#!/usr/bin/env bash
# Bundled package: ${package_name}
# Generated by orb on $(date)
EOF
  
  local file_count=0
  for file in "${dir}"/*.sh; do
    [[ -f "${file}" ]] || continue
    if [[ "${file}" == "${bundle_file}" ]]; then
      debug "Skipping bundle file itself"
      continue
    fi
    file_count=$((file_count + 1))
    debug "Adding file #${file_count}: ${file}"
    echo "" >> "${bundle_file}"
    echo "# Source: $(basename "${file}")" >> "${bundle_file}"
    echo "# --- Start of $(basename "${file}") ---" >> "${bundle_file}"
    cat "${file}" >> "${bundle_file}"
    echo "# --- End of $(basename "${file}") ---" >> "${bundle_file}"
  done
  
  chmod +x "${bundle_file}"
  debug "Bundle created successfully with ${file_count} files"
  debug "Bundle size: $(wc -l < "${bundle_file}") lines"
}

create_or_update_orb_json() {
  local package="$1"
  local version="$2"
  local orb_json="orb.json"
  
  debug "Updating $orb_json with ${package}@${version}"
  
  if [[ ! -f "$orb_json" ]]; then
    cat > "$orb_json" <<EOF
{
  "name": "$(basename "$(pwd)")",
  "version": "1.0.0",
  "dependencies": {},
  "devDependencies": {}
}
EOF
    debug "Created new $orb_json"
  fi
  
  if command -v jq &>/dev/null; then
    jq ".dependencies.\"$package\" = \"$version\"" "$orb_json" > "$orb_json.tmp" && mv "$orb_json.tmp" "$orb_json"
  else # Try without jq if jq not available
   
    debug "Trying without jq (if u see this, install jq to avoid errors)"
    local temp_file
    temp_file="$(mktemp)"
    
    if grep -q "\"$package\"" "$orb_json"; then
      sed "s/\"$package\": \"[^\"]*\"/\"$package\": \"$version\"/" "$orb_json" > "$temp_file"
    else
      sed "/\"dependencies\": {/a\    \"$package\": \"$version\"," "$orb_json" | 
        sed 's/\"dependencies\": {,\n/\"dependencies\": {\n/' > "$temp_file"
    fi
    
    mv "$temp_file" "$orb_json"
  fi
  
  log "Added ${package}@${version} to $orb_json"
}

remove_from_orb_json() {
  local package="$1"
  local orb_json="orb.json"
  
  if [[ ! -f "$orb_json" ]]; then
    return 0
  fi
  
  debug "Removing ${package} from $orb_json"
  
  if command -v jq &>/dev/null; then
    jq "del(.dependencies.\"$package\")" "$orb_json" > "$orb_json.tmp" && mv "$orb_json.tmp" "$orb_json"
  else
    local temp_file
    temp_file="$(mktemp)"
    
    # Eliminar línea de dependencia
    grep -v "\"$package\":" "$orb_json" > "$temp_file"
    mv "$temp_file" "$orb_json"
  fi
  
  debug "Removed ${package} from $orb_json"
}

uninstall_package() {
  debug "Entering uninstall_package function"
  
  local force=false
  local global=false
  local package=""
  
  debug "Parsing arguments: $*"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force=true
        debug "Force flag detected"
        shift
        ;;
      --global)
        global=true
        debug "Global flag detected"
        shift
        ;;
      *)
        package="$1"
        debug "Package name: ${package}"
        shift
        ;;
    esac
  done
  
  if [[ -z "${package}" ]]; then
    die "Package name required"
  fi
  
  # Determinar directorio base basado en global/local
  local install_base
  if [[ "${global}" == "true" ]]; then
    install_base="${ORB_INSTALLED}"
    debug "Global uninstall from: ${install_base}"
  else
    install_base="$(pwd)/.orb/installed"
    debug "Local uninstall from: ${install_base}"
  fi
  
  local package_dir="${install_base}/${package}"
  local meta_file="${install_base}/${package}.meta"
  
  debug "Package directory: ${package_dir}"
  debug "Metadata file: ${meta_file}"
  
  if [[ ! -d "${package_dir}" ]]; then
    debug "Package directory not found: ${package_dir}"
    
    # Si estamos en modo local y no encontramos, sugerir usar --global
    if [[ "${global}" != "true" ]] && [[ -d "${ORB_INSTALLED}/${package}" ]]; then
      error "Package '${package}' found in global installation"
      error "Try: orb uninstall ${package} --global"
    fi
    
    die "Package '${package}' is not installed"
  fi
  
  debug "Package found. Listing installed versions:"
  local versions=()
  for version_dir in "${package_dir}"/*; do
    if [[ -d "${version_dir}" ]]; then
      local version_name
      version_name="$(basename "${version_dir}")"
      versions+=("${version_name}")
      debug "  - ${version_name}"
    fi
  done
  
  if [[ ${#versions[@]} -eq 0 ]]; then
    debug "No version directories found in ${package_dir}"
    echo "No installed versions found for ${package}"
  else
    echo "The following versions of '${package}' will be removed:"
    for version in "${versions[@]}"; do
      echo "  - ${version}"
    done
    
    if [[ "${force}" != "true" ]]; then
      read -rp "Are you sure? [y/N]: " confirm
      if [[ "${confirm}" != "y" ]] && [[ "${confirm}" != "Y" ]]; then
        log "Uninstallation cancelled"
        return 0
      fi
    else
      debug "Force mode enabled, skipping confirmation"
    fi
  fi
  
  debug "Removing package directory: ${package_dir}"
  if ! rm -rf "${package_dir}"; then
    error "Failed to remove package directory: ${package_dir}"
    return 1
  fi
  
  debug "Removing metadata file: ${meta_file}"
  if [[ -f "${meta_file}" ]]; then
    rm -f "${meta_file}"
  fi
  
  # Solo remover de orb.json para instalaciones locales
  if [[ "${global}" != "true" ]]; then
    debug "Removing from project dependencies"
    remove_from_orb_json "${package}"
  fi
  
  local cache_dir="${ORB_CACHE}/${package}"
  if [[ -d "${cache_dir}" ]]; then
    debug "Removing from cache: ${cache_dir}"
    rm -rf "${cache_dir}"
  fi
  
  local location="local"
  [[ "${global}" == "true" ]] && location="global"
  
  log "Uninstalled ${package} (${location})"
  debug "Package removal completed successfully"
}

list_packages() {
  debug "Entering list_packages function"
  debug "  Allow insecure: $1"
  
  local allow_insecure="${1:-false}"
  
  log "Official packages:"
  debug "Fetching official packages"
  local official_content
  
  # Manejar modo debug separadamente
  if [ -n "${ORB_DEBUG}" ] && [ "${ORB_DEBUG}" != "0" ] && [ "${ORB_DEBUG}" != "false" ]; then
    debug "Running fetch_official_packages in debug mode"
    local temp_stderr
    temp_stderr="$(mktemp)"
    official_content="$(fetch_official_packages 2>"${temp_stderr}" || true)"
    
    # Mostrar los mensajes de debug desde stderr
    if [ -s "${temp_stderr}" ]; then
      while IFS= read -r line; do
        debug "$line"
      done < "${temp_stderr}"
    fi
    rm -f "${temp_stderr}"
  else
    official_content="$(fetch_official_packages 2>/dev/null || true)"
  fi
  
  if [ -z "${official_content}" ]; then
    debug "No official packages content received or content is empty"
    echo "  (Unable to fetch official packages)"
    echo ""
  else
    debug "Processing official packages content"
    debug "Official content length: ${#official_content} characters"
    debug "Official content (raw):"
    echo "${official_content}" | while IFS= read -r line; do
      debug "  '$line'"
    done
    
    # Contar las líneas que son paquetes
    local package_lines
    package_lines="$(echo "${official_content}" | grep -c '^package[0-9]\+=' || echo "0")"
    debug "Found $package_lines package lines in official content"
    
    if [ "$package_lines" -eq 0 ]; then
      debug "No package lines found in official content"
      echo "  (No packages found in official repository)"
      echo ""
    else
      debug "Processing each package line"
      
      # Procesar cada línea que comience con packageX=
      echo "${official_content}" | grep '^package[0-9]\+=' | while IFS= read -r line; do
        debug "Processing package line: '$line'"
        
        # Extraer la URL, quitando comillas simples o dobles
        local package_url="${line#*=}"
        debug "Raw package URL: '$package_url'"
        
        # Limpiar comillas
        package_url="$(echo "$package_url" | sed "s/^['\"]//;s/['\"]$//")"
        debug "Cleaned package URL: '$package_url'"
        
        # Descargar el orb.config del paquete
        local package_content=""
        local config_file
        config_file="$(mktemp)"
        
        debug "Downloading orb.config from package repository: $package_url"
        if download_orb_config "$package_url" "$config_file"; then
          package_content="$(cat "$config_file" 2>/dev/null || echo "")"
          rm -f "$config_file"
          
          if [ -n "$package_content" ] && echo "$package_content" | grep -q "type="; then
            debug "Successfully downloaded package config"
            
            # Parsear el contenido del paquete
            declare -A pkg_config
            local in_files=false
            
            while IFS= read -r config_line; do
              if echo "$config_line" | grep -q "^[[:space:]]*files:"; then
                in_files=true
                continue
              fi
              if [ "$in_files" = false ] && echo "$config_line" | grep -q "^[[:space:]]*[^=]*=.*"; then
                local key
                local value
                key="$(echo "$config_line" | sed "s/^[[:space:]]*\([^=]*\)=.*/\1/")"
                value="$(echo "$config_line" | sed "s/^[[:space:]]*[^=]*=['\"]\?\([^'\"]*\)['\"]\?$/\1/")"
                pkg_config["$key"]="$value"
              fi
            done <<< "$package_content"
            
            if [ -n "${pkg_config[packageName]:-}" ]; then
              debug "Found package: ${pkg_config[packageName]}"
              echo "- ${pkg_config[packageName]} ${pkg_config[version]:-unknown version} by ${pkg_config[author]:-unknown author}"
              echo "  ${pkg_config[shortDescription]:-No description}"
              echo ""
            else
              debug "No packageName found in config for URL: $package_url"
              echo "- (Invalid package config)"
              echo ""
            fi
          else
            debug "Package config is empty or invalid"
            echo "- (Invalid package config from $package_url)"
            echo ""
          fi
        else
          debug "Failed to download orb.config from: $package_url"
          echo "- (Failed to download package info)"
          echo ""
        fi
      done
    fi
  fi
  
  if [ "$allow_insecure" = "true" ]; then
    echo ""
    log "Unofficial packages:"
    debug "Listing unofficial packages"
    
    local repo_count=0
    for repo_file in "${ORB_REPOS}"/*; do
      [ -f "${repo_file}" ] || continue
      repo_count=$((repo_count + 1))
      
      local repo
      repo="$(cat "${repo_file}")"
      debug "Processing repository: $repo"
      echo "  Repository: $repo"
      
      local repo_content
      if [ -n "${ORB_DEBUG}" ] && [ "${ORB_DEBUG}" != "0" ] && [ "${ORB_DEBUG}" != "false" ]; then
        local temp_stderr
        temp_stderr="$(mktemp)"
        repo_content="$(fetch_repo_packages "$repo" 2>"${temp_stderr}" || true)"
        
        if [ -s "${temp_stderr}" ]; then
          while IFS= read -r line; do
            debug "$line"
          done < "${temp_stderr}"
        fi
        rm -f "${temp_stderr}"
      else
        repo_content="$(fetch_repo_packages "$repo" 2>/dev/null || true)"
      fi
      
      if [ -z "$repo_content" ]; then
        debug "Failed to fetch repository content"
        echo "    (Unable to fetch packages from this repository)"
        echo ""
        continue
      fi
      
      # Procesar paquetes del repositorio no oficial
      echo "$repo_content" | grep '^package[0-9]\+=' | while IFS= read -r line; do
        if echo "$line" | grep -q '^package[0-9]\+='; then
          local package_url="${line#*=}"
          package_url="$(echo "$package_url" | sed "s/^['\"]//;s/['\"]$//")"
          
          debug "Processing unofficial package URL: $package_url"
          
          local package_content=""
          local config_file
          config_file="$(mktemp)"
          
          if download_orb_config "$package_url" "$config_file"; then
            package_content="$(cat "$config_file" 2>/dev/null || echo "")"
            rm -f "$config_file"
            
            if [ -n "$package_content" ] && echo "$package_content" | grep -q "type="; then
              declare -A pkg_config
              local in_files=false
              
              while IFS= read -r config_line; do
                if echo "$config_line" | grep -q "^[[:space:]]*files:"; then
                  in_files=true
                  continue
                fi
                if [ "$in_files" = false ] && echo "$config_line" | grep -q "^[[:space:]]*[^=]*=.*"; then
                  local key
                  local value
                  key="$(echo "$config_line" | sed "s/^[[:space:]]*\([^=]*\)=.*/\1/")"
                  value="$(echo "$config_line" | sed "s/^[[:space:]]*[^=]*=['\"]\?\([^'\"]*\)['\"]\?$/\1/")"
                  pkg_config["$key"]="$value"
                fi
              done <<< "$package_content"
              
              if [ -n "${pkg_config[packageName]:-}" ]; then
                echo "- ${pkg_config[packageName]} ${pkg_config[version]:-unknown version} by ${pkg_config[author]:-unknown author}"
                echo "  ${pkg_config[shortDescription]:-No description}"
                echo ""
              fi
            fi
          fi
        fi
      done
    done
    
    if [ "$repo_count" -eq 0 ]; then
      debug "No unofficial repositories found"
      echo "  (No unofficial repositories added)"
      echo "  Use 'orb --allow-insecure-repo <url>' to add repositories"
    fi
  fi
}

bundle_file() {
  debug "Entering bundle_file function"
  debug "  Input file: $1"
  debug "  Output file: ${2:-not specified}"
  
  local input_file="$1"
  local output_file="${2:-}"
  
  if [[ ! -f "${input_file}" ]]; then
    die "File not found: ${input_file}"
  fi
  
  debug "Input file exists. Size: $(wc -l < "${input_file}") lines"
  
  local temp_dir
  temp_dir="$(mktemp -d)"
  debug "Created temporary directory: ${temp_dir}"
  
  local bundled_file="${temp_dir}/bundled.sh"
  local current_line=0
  local import_count=0
  
  debug "Processing input file line by line"
  while IFS= read -r line; do
    current_line=$((current_line + 1))
    
    if [[ "${line}" =~ ^[[:space:]]*#[[:space:]]*orb[[:space:]]+import[[:space:]]+([^[:space:]]+)([[:space:]]+([^[:space:]]+))? ]]; then
      local package="${BASH_REMATCH[1]}"
      local version="${BASH_REMATCH[3]}"
      import_count=$((import_count + 1))
      
      debug "Found import at line ${current_line}:"
      debug "  Package: ${package}"
      debug "  Version: ${version:-latest}"
      
      # Buscar primero en local (./.orb/installed), luego en global (~/.orb/installed)
      local local_install_dir="./.orb/installed/${package}"
      local global_install_dir="${ORB_INSTALLED}/${package}"
      
      local install_base
      if [[ -d "${local_install_dir}" ]]; then
        install_base="${local_install_dir}"
        debug "Found package in local installation"
      elif [[ -d "${global_install_dir}" ]]; then
        install_base="${global_install_dir}"
        debug "Found package in global installation"
      else
        die "Package '${package}' not installed. Run 'orb install ${package}' first"
      fi
      
      local install_dir
      if [[ -n "${version}" ]]; then
        install_dir="${install_base}/${version}"
        debug "Looking for specific version: ${install_dir}"
      else
        debug "Looking for latest version of ${package}"
        
        # Filtrar solo directorios que parezcan versiones
        local latest_version
        latest_version="$(find "${install_base}" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | grep -E '^[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)"
        
        if [[ -z "${latest_version}" ]]; then
          die "No valid version found for package '${package}'"
        fi
        
        install_dir="${install_base}/${latest_version}"
        debug "Latest version directory: ${install_dir}"
      fi
      
      if [[ ! -d "${install_dir}" ]]; then
        die "Version '${version}' not found for package '${package}'"
      fi
      
      debug "Loading package config from: ${install_dir}/orb.config"
      local config_file="${install_dir}/orb.config"
      if [[ ! -f "${config_file}" ]]; then
        die "Config file not found: ${config_file}"
      fi
      
      parse_config "${config_file}"
      
      debug "Checking if package is bundlable: ${config[isPackageBundlable]:-false}"
      local is_bundlable="${config[isPackageBundlable]:-false}"
      if [[ "${is_bundlable}" == "false" ]]; then
        debug "Package is not marked as bundlable, but proceeding anyway"
      fi
      
      local bundle_files="${config[bundleFiles]:-false}"
      local bundle_name="${config[bundleFileName]:-${config[packageName]}}"
      
      if [[ "${bundle_files}" == "true" ]] && [[ -f "${install_dir}/${bundle_name}.sh" ]]; then
        debug "Using pre-bundled file: ${install_dir}/${bundle_name}.sh"
        cat "${install_dir}/${bundle_name}.sh" >> "${bundled_file}"
        echo "" >> "${bundled_file}"
      else
        debug "Bundling individual files"
        local file_count=0
        # Buscar todos los archivos en el directorio de instalación (recursivamente)
        while IFS= read -r file; do
          # Saltar directorios
          [[ -f "$file" ]] || continue
          # Saltar el archivo de configuración y el bundle pre-empaquetado si existe
          local filename=$(basename "$file")
          if [[ "$filename" == "orb.config" ]] || [[ "$filename" == ".source" ]] || [[ "$filename" == "${bundle_name}.sh" ]]; then
            continue
          fi
          file_count=$((file_count + 1))
          debug "  Adding file #${file_count}: ${file}"
          echo "# Source: ${file#${install_dir}/} from ${package} ${version:-latest}" >> "${bundled_file}"
          cat "${file}" >> "${bundled_file}"
          echo "" >> "${bundled_file}"
        done < <(find "${install_dir}" -type f ! -name "orb.config" ! -name ".source" ! -name "${bundle_name}.sh")
        debug "Added ${file_count} files from package ${package}"
      fi
    else
      echo "${line}" >> "${bundled_file}"
    fi
  done < "${input_file}"
  
  debug "Finished processing file. Total lines: ${current_line}, imports: ${import_count}"
  
  if [[ -z "${output_file}" ]]; then
    output_file="${input_file%.sh}_bundled.sh"
    debug "No output file specified, using default: ${output_file}"
  fi
  
  debug "Copying bundled file to: ${output_file}"
  cp "${bundled_file}" "${output_file}"
  chmod +x "${output_file}"
  
  debug "Cleaning up temporary directory: ${temp_dir}"
  rm -rf "${temp_dir}"
  
  log "Successfully bundled file: ${output_file}"
  debug "Output file size: $(wc -l < "${output_file}") lines"
  debug "Output file location: $(realpath "${output_file}" 2>/dev/null || echo "${output_file}")"
}

self_update() {
  debug "Entering self_update function"
  
  log "Checking for updates..."
  
  local main_url="https://raw.githubusercontent.com/stringmanolo/orb/main/orb.sh"
  local master_url="https://raw.githubusercontent.com/stringmanolo/orb/master/orb.sh"
  
  local temp_file
  temp_file="$(mktemp)"
  local download_success=false
  
  debug "Trying main branch..."
  if command -v curl &>/dev/null; then
    if curl -sSLf -o "$temp_file" "$main_url"; then
      download_success=true
    fi
  elif command -v wget &>/dev/null; then
    if wget -q -O "$temp_file" "$main_url"; then
      download_success=true
    fi
  fi
  
  if [[ "$download_success" != "true" ]]; then
    debug "Main branch failed, trying master branch..."
    if command -v curl &>/dev/null; then
      curl -sSLf -o "$temp_file" "$master_url" 2>/dev/null && download_success=true
    elif command -v wget &>/dev/null; then
      wget -q -O "$temp_file" "$master_url" 2>/dev/null && download_success=true
    fi
  fi
  
  if [[ "$download_success" != "true" ]]; then
    error "Failed to download update"
    rm -f "$temp_file"
    return 1
  fi
  
  local new_version
  new_version="$(grep -m1 '^ORB_VERSION=' "$temp_file" | cut -d'"' -f2 2>/dev/null || echo "")"
  
  if [[ -z "$new_version" ]]; then
    error "Could not determine new version"
    rm -f "$temp_file"
    return 1
  fi
  
  debug "Current version: $ORB_VERSION, New version: $new_version"
  
  if [[ "$ORB_VERSION" == "$new_version" ]]; then
    log "Already up to date (v$ORB_VERSION)"
    rm -f "$temp_file"
    return 0
  fi
  
  log "New version available: v$new_version"
  log "Current version: v$ORB_VERSION"
  
  local force=false
  for arg in "$@"; do
    if [[ "$arg" == "--force" ]]; then
      force=true
    fi
  done
  
  if [[ "$force" != "true" ]]; then
    echo ""
    read -rp "Update to v$new_version? [y/N]: " answer
    if [[ "$answer" != "y" ]] && [[ "$answer" != "Y" ]]; then
      log "Update cancelled"
      rm -f "$temp_file"
      return 0
    fi
  fi
  
  local backup_file="$0.backup.$(date +%Y%m%d_%H%M%S)"
  debug "Creating backup: $backup_file"
  
  if ! cp "$0" "$backup_file"; then
    error "Failed to create backup"
    rm -f "$temp_file"
    return 1
  fi
  
  chmod +x "$temp_file"
  
  debug "Replacing current file with new version"
  
  if cat "$temp_file" > "$0"; then
    chmod +x "$0"
    
    rm -f "$temp_file"
    
    log ""
    log "   Update successful!"
    log "   Backup saved as: $backup_file"
    log "   New version: v$new_version"
    log ""
    log "Please run your command again."
    
    exit 0
  else
    error "Failed to update. Restoring backup..."
    
    if cp "$backup_file" "$0"; then
      chmod +x "$0"
      log "Restored from backup"
    else
      error "CRITICAL: Failed to restore from backup!"
      error "Please manually restore from: $backup_file"
    fi
    
    rm -f "$temp_file"
    return 1
  fi
}

check_update() {
  debug "Entering check_update function"
  
  log "Checking for updates..."
  
  local main_url="https://raw.githubusercontent.com/stringmanolo/orb/main/orb.sh"
  local new_version=""
  
  if command -v curl &>/dev/null; then
    new_version="$(curl -sSLf "$main_url" 2>/dev/null | grep -m1 '^ORB_VERSION=' | cut -d'"' -f2 || true)"
  elif command -v wget &>/dev/null; then
    new_version="$(wget -q -O- "$main_url" 2>/dev/null | grep -m1 '^ORB_VERSION=' | cut -d'"' -f2 || true)"
  fi
  
  if [[ -z "$new_version" ]]; then
    error "Could not check for updates"
    return 1
  fi
  
  if [[ "$ORB_VERSION" == "$new_version" ]]; then
    log "You have the latest version (v$ORB_VERSION)"
    return 0
  else
    log "Update available!"
    log "Current: v$ORB_VERSION"
    log "Latest:  v$new_version"
    log ""
    log "Run 'orb --update' to update"
    return 0
  fi
}

main() {
  debug "=== orb ${ORB_VERSION} starting ==="
  debug "Command line arguments: $*"
  debug "ORB_HOME: ${ORB_HOME}"
  debug "Current working directory: $(pwd)"
  debug "User: $(whoami)"

  # Check for updates if last time command ran was 1 week ago
  local last_check_file="${ORB_HOME}/.last_update_check"
  local current_time=$(date +%s)
  local last_check_time=0

  if [[ -f "$last_check_file" ]]; then
    last_check_time=$(cat "$last_check_file" 2>/dev/null || echo "0")
  fi

  # Check once per week (604800 seconds)
  if [[ $((current_time - last_check_time)) -gt 604800 ]]; then
    echo "$current_time" > "$last_check_file"

    # Run check in background to not interrupt user
    (
      if check_update 2>/dev/null | grep -q "Update available"; then
        echo ""
        echo "   Update available for orb!"
        echo "   Run 'orb --update' to get the latest version."
        echo ""
      fi
    ) &
  fi

  case "${1:-}" in
    --help|-h)
      debug "Showing help"
      cat <<EOF
orb - Bash package manager

Usage:
  orb <command> [options]

Commands:
  install <package> [version]   Install a package (local by default)
  uninstall <package>           Uninstall a package
  list                          List available packages
  bundle <file> [output]        Bundle a file with imports
  init <name> [version]         Initialize a new orb project
  --allow-insecure-repo <url>   Add an insecure repository
  
Update Commands:
  --update, self-update         Update orb to the latest version
  --check-update                Check for updates without installing
  --force-update                Update without confirmation
  
Options:
  --allow-insecure-repos        Allow insecure repositories for install/list
  --global                      Install/uninstall globally
  --force                       Force uninstall without confirmation
  --version                     Show version
  --help                        Show this help

Debug:
  Set ORB_DEBUG=1 for debug output
EOF
      ;;

    --version|-v)
      debug "Showing version"
      echo "orb ${ORB_VERSION}"
      ;;
    
    --allow-insecure-repo)
      debug "Processing --allow-insecure-repo command"
      [[ $# -ge 2 ]] || die "Repository URL required for --allow-insecure-repo"
      debug "Adding insecure repository: $2"
      add_insecure_repo "$2"
      ;;
    
    init)
      [[ $# -ge 2 ]] || die "Project name required"
      local project_name="$2"
      local version="${3:-1.0.0}"
      
      if [[ -f "orb.json" ]]; then
        die "orb.json already exists in this directory"
      fi
      
      cat > "orb.json" <<EOF
{
  "name": "${project_name}",
  "version": "${version}",
  "description": "",
  "main": "main.sh",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {},
  "devDependencies": {},
  "keywords": [],
  "author": "",
  "license": "ISC"
}
EOF
      log "Initialized empty orb project in $(pwd)"
      log "Created orb.json"
      ;;

    install)
      debug "Processing install command"
      [[ $# -ge 2 ]] || die "Package name required"
      local allow_insecure=false
      local global=false
      local package="$2"
      local version="${3:-}"
      
      debug "Checking for flags"
      for arg in "$@"; do
        if [[ "${arg}" == "--allow-insecure-repos" ]]; then
          allow_insecure=true
          debug "Found --allow-insecure-repos flag"
        fi
        if [[ "${arg}" == "--global" ]]; then
          global=true
          debug "Found --global flag"
        fi
      done
      
      debug "Installing package: ${package}"
      debug "  Allow insecure: ${allow_insecure}"
      debug "  Global: ${global}"
      debug "  Version: ${version:-latest}"
     
      shift
      install_package "$@"
      ;;

    uninstall)
      debug "Processing uninstall command"
      [[ $# -ge 2 ]] || die "Package name required"
      local force=false
      local global=false
      local package="$2"
      
      debug "Checking for flags"
      for arg in "$@"; do
        if [[ "${arg}" == "--force" ]]; then
          force=true
          debug "Found --force flag"
        fi
        if [[ "${arg}" == "--global" ]]; then
          global=true
          debug "Found --global flag"
        fi
      done
      
      debug "Uninstalling package: ${package}"
      debug "  Force: ${force}"
      debug "  Global: ${global}"
      
      if [[ "${force}" == "true" ]] && [[ "${global}" == "true" ]]; then
        uninstall_package "${package}" "--force" "--global"
      elif [[ "${force}" == "true" ]]; then
        uninstall_package "${package}" "--force"
      elif [[ "${global}" == "true" ]]; then
        uninstall_package "${package}" "--global"
      else
        uninstall_package "${package}"
      fi
      ;;

    list)
      debug "Processing list command"
      local allow_insecure=false
      
      debug "Checking for --allow-insecure-repos flag"
      for arg in "$@"; do
        if [[ "${arg}" == "--allow-insecure-repos" ]]; then
          allow_insecure=true
          debug "Found --allow-insecure-repos flag"
          break
        fi
      done
      
      debug "Listing packages"
      debug "  Allow insecure: ${allow_insecure}"
      
      list_packages "${allow_insecure}"
      ;;
    
    bundle)
      debug "Processing bundle command"
      [[ $# -ge 2 ]] || die "Input file required for bundle command"
      debug "Bundling file: $2"
      debug "Output file: ${3:-autogenerated}"
      
      bundle_file "$2" "${3:-}"
      ;;
    
    --update|self-update|upgrade)
      debug "Processing update command"
      self_update "$@"
      ;;
    
    --check-update)
      debug "Processing check-update command"
      check_update
      ;;
    
    --force-update)
      debug "Processing force-update command"
      self_update "--force"
      ;;

    "")
      debug "No command specified, showing help"
      error "No command specified"
      echo "Try 'orb --help' for usage"
      exit 1
      ;;
    
    *)
      debug "Unknown command: ${1}"
      error "Unknown command: ${1}"
      echo "Try 'orb --help' for usage"
      exit 1
      ;;
  esac
  
  debug "=== orb command completed successfully ==="
}

main "$@"
