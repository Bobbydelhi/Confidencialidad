#!/bin/bash

set -u

err()  { zenity --error --title="Error" --text="$1"; }
info() { zenity --info --title="Información" --text="$1"; }

main_menu() {
    while true; do
        opcion=$(zenity --list --radiolist \
            --title="Menú Principal" \
            --column="Sel" --column="Acción" \
            TRUE "1. Actualizar y Upgradear el sistema" \
            FALSE "2. Abrir Gestor de Claves y Cifrado" \
            FALSE "3. Salir" \
            --height=300 --width=400) || exit 0

        case "$opcion" in
            "1. Actualizar y Upgradear el sistema")
                gnome-terminal -- bash -c 'echo "Actualizando sistema..."; sudo apt update && sudo apt upgrade -y; echo "✅ Actualización completada"; read -p "Pulsa Enter para cerrar..."'
                ;;

            "2. Abrir Gestor de Claves y Cifrado")
                if [[ -f "./script.sh" ]]; then
                    bash ./script.sh
                else
                    err "No se encontró el archivo script.sh"
                fi
                ;;

            "3. Salir")
                info "Saliendo del programa. ¡Hasta pronto!"
                exit 0
                ;;
        esac
    done
}

# Verificar que Zenity esté instalado
command -v zenity >/dev/null 2>&1 || { echo "Error: falta el comando zenity. Instálalo con: sudo apt install zenity"; exit 1; }

main_menu
