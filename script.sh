#!/bin/bash
set -u
KEYDIR="./claves"
PUBDIR="$KEYDIR/publicas"
mkdir -p "$PUBDIR"

err()  { zenity --error --title="Error" --text="$1"; }
info() { zenity --info --title="Información" --text="$1"; }
ask()  { zenity --question --title="Confirmar" --text="$1"; }
tmpfile() { mktemp; }

trap 'rm -f "$aes"' EXIT

gen_rsa() {
    name=$(zenity --entry --title="Nueva clave RSA" --text="Nombre base de las claves:") || return
    name=$(echo "$name" | tr -d '\n')
    [[ -z "$name" ]] && { err "Nombre vacío"; return; }
    priv="$KEYDIR/${name}_priv.pem"
    pub="$PUBDIR/${name}_pub.pem"
    bits=$(zenity --list --radiolist --title="Tamaño RSA" --column="Sel" --column="Bits" TRUE 2048 FALSE 4096) || return
    bits=$(echo "$bits" | tr -d '\n')
    if [[ -f "$priv" || -f "$pub" ]]; then
        ask "Sobrescribir claves existentes?" || return
    fi
    if openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:$bits -out "$priv" &&
       openssl rsa -in "$priv" -pubout -out "$pub"; then
        chmod 600 "$priv"; chmod 644 "$pub"
        info "Claves generadas:\nPrivada: $priv\nPública: $pub"
    else
        err "Error generando claves RSA"
    fi
}

view_pubkey() {
    files=()
    while IFS= read -r file; do
        files+=("$file")
    done < <(find "$PUBDIR" -maxdepth 1 -type f \( -name "*.pem" -o -name "*.pub" \) | sort)
    if [[ ${#files[@]} -eq 0 ]]; then
        err "No hay claves públicas en el keyring"
        return
    fi
    pub=$(zenity --list --title="Selecciona clave pública" --column="Clave pública" "${files[@]}") || return
    [[ -f "$pub" ]] && zenity --text-info --title="Contenido de $(basename "$pub")" --filename="$pub" --width=600 --height=400 || err "Clave no encontrada"
}

hybrid_encrypt() {
    infile=$(zenity --file-selection --title="Archivo a cifrar") || return
    pub=$(zenity --file-selection --title="Clave pública RSA") || return
    aes=$(tmpfile)
    openssl rand 32 >"$aes"
    outfile="${infile}.enc"
    keyout="${infile}.key.enc"
    if openssl enc -aes-256-cbc -pbkdf2 -salt -in "$infile" -out "$outfile" -pass file:"$aes" &&
       openssl pkeyutl -encrypt -pubin -inkey "$pub" -in "$aes" -out "$keyout"; then
        rm -f "$aes"
        info "Cifrado híbrido completado:\nDatos: $outfile\nClave cifrada: $keyout"
    else
        rm -f "$aes"
        err "Error en cifrado híbrido"
    fi
}

hybrid_decrypt() {
    infile=$(zenity --file-selection --title="Archivo cifrado (.enc)") || return
    keyenc=$(zenity --file-selection --title="Clave AES cifrada (.key.enc)") || return
    priv=$(zenity --file-selection --title="Clave privada RSA") || return
    aes=$(tmpfile)
    if openssl pkeyutl -decrypt -inkey "$priv" -in "$keyenc" -out "$aes" &&
       out="${infile%.enc}" &&
       openssl enc -d -aes-256-cbc -pbkdf2 -in "$infile" -out "$out" -pass file:"$aes"; then
        rm -f "$aes"
        info "Descifrado completado: $out"
    else
        rm -f "$aes"
        err "Error en descifrado híbrido"
    fi
}

gen_aes_key() {
    name=$(zenity --entry --title="Generar clave AES" --text="Nombre de la clave (guardada en $KEYDIR):" --entry-text "key_$(date +%s)") || return
    name=$(echo "$name" | tr -d '\n')
    [[ -z "$name" ]] && { err "Debe introducir un nombre para la clave."; return; }
    keyfile="$KEYDIR/${name}.key"
    if [[ -f "$keyfile" ]]; then
        ask "La clave ya existe. ¿Desea sobrescribirla?" || return
    fi
    if openssl rand 32 >"$keyfile"; then
        chmod 600 "$keyfile"
        info "Clave AES (32 bytes) generada correctamente: $keyfile"
    else
        err "Error generando la clave AES."
    fi
}

sym_encrypt() {
    infile=$(zenity --file-selection --title="Archivo a cifrar") || return
    keyfile=$(zenity --file-selection --title="Selecciona clave AES" --filename="$KEYDIR/") || return
    outfile=$(zenity --file-selection --save --confirm-overwrite --title="Guardar archivo cifrado" --filename="${infile}.enc") || return
    if openssl enc -aes-256-cbc -pbkdf2 -salt -in "$infile" -out "$outfile" -pass file:"$keyfile"; then
        info "Archivo cifrado: $outfile"
    else
        err "Error cifrando"
    fi
}

sym_decrypt() {
    infile=$(zenity --file-selection --title="Archivo a descifrar") || return
    keyfile=$(zenity --file-selection --title="Selecciona clave AES" --filename="$KEYDIR/") || return
    outfile=$(zenity --file-selection --save --confirm-overwrite --title="Guardar archivo descifrado" --filename="${infile%.enc}") || return
    if openssl enc -d -aes-256-cbc -pbkdf2 -in "$infile" -out "$outfile" -pass file:"$keyfile"; then
        info "Archivo descifrado: $outfile"
    else
        err "Error descifrando"
    fi
}

manage_pubkeys() {
    action=$(zenity --list --radiolist --title="Gestión claves públicas" \
      --column="Sel" --column="Acción" TRUE "Importar (buscar)" FALSE "Exportar (desde keyring)" FALSE "Listar (ver)" ) || return
    case "$action" in
      "Importar (buscar)")
        dir=$(zenity --file-selection --directory --title="Selecciona directorio para buscar claves") || return
        pattern=$(zenity --entry --title="Patrón de búsqueda" --text="Introduce patrón (ej: *.pem):" --entry-text "*.pem") || return
        mapfile -t results < <(find "$dir" -maxdepth 4 -type f -name "$pattern" 2>/dev/null || true)
        if [[ ${#results[@]} -eq 0 ]]; then
          err "No se encontraron archivos con ese patrón en $dir"
          return
        fi
        listargs=(--title "Resultados" --column "Seleccionar" --column "Archivo")
        for f in "${results[@]}"; do
          listargs+=(FALSE "$f")
        done
        selected=$(zenity --list --checklist "${listargs[@]}" --width=900 --height=400) || return
        IFS="|" read -r -a toimport <<< "$selected"
        for s in "${toimport[@]}"; do
          [[ -z "$s" ]] && continue
          dest="$PUBDIR/$(basename "$s")"
          if cp -f "$s" "$dest"; then
            chmod 644 "$dest"
          else
            err "Error importando $s"
          fi
        done
        info "Importación finalizada en $PUBDIR"
        ;;
      "Exportar (desde keyring)")
        if [[ ! -d "$PUBDIR" || $(find "$PUBDIR" -maxdepth 1 -type f | wc -l) -eq 0 ]]; then
          err "No hay claves en el keyring para exportar"
          return
        fi
        pub=$(zenity --file-selection --title="Selecciona clave pública del keyring" --filename="$PUBDIR/") || return
        dest=$(zenity --file-selection --save --confirm-overwrite --title="Exportar como" --filename="$(basename "$pub")") || return
        if cp -f "$pub" "$dest"; then
          chmod 644 "$dest"
          info "Clave exportada a $dest"
        else
          err "Error exportando la clave"
        fi
        ;;
      "Listar (ver)")
        view_pubkey
        ;;
    esac
}

main_menu() {
    while true; do
        choice=$(zenity --list --title="Confidencialidad" \
          --column="Opción" \
          "1. Generar claves" \
          "2. Gestión de claves públicas" \
          "3. Cifrado asimétrico" \
          "4. Generar clave random" \
          "5. Cifrado simétrico" \
          "6. Salir" --height=400 --width=400) || break
        case "$choice" in
            "1. Generar claves") gen_rsa ;;
            "2. Gestión de claves públicas") manage_pubkeys ;;
            "3. Cifrado asimétrico")
                opt=$(zenity --list --radiolist --title="Cifrado asimétrico" --column="Sel" --column="Acción" TRUE "Cifrar" FALSE "Descifrar") || continue
                opt=$(echo "$opt" | tr -d '\n')
                [[ "$opt" == "Cifrar" ]] && hybrid_encrypt || hybrid_decrypt
                ;;
            "4. Generar clave random") gen_aes_key ;;
            "5. Cifrado simétrico")
                opt=$(zenity --list --radiolist --title="Cifrado simétrico" --column="Sel" --column="Acción" TRUE "Cifrar" FALSE "Descifrar") || continue
                opt=$(echo "$opt" | tr -d '\n')
                [[ "$opt" == "Cifrar" ]] && sym_encrypt || sym_decrypt
                ;;
            "6. Salir") break ;;
        esac
    done
}

for cmd in zenity openssl find; do
    command -v "$cmd" >/dev/null 2>&1 || { err "Falta comando: $cmd"; exit 1; }
done

main_menu
