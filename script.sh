#!/bin/bash
set -u

source "$(dirname "$0")/subscript.sh"

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

# Verificar comandos necesarios
for cmd in zenity openssl find; do
    command -v "$cmd" >/dev/null 2>&1 || { zenity --error --title="Error" --text="Falta comando: $cmd"; exit 1; }
done

main_menu
