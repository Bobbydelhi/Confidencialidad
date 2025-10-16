#  Gestor de Claves y Cifrado

**Autor:** El Boudali  
**GitHub:** [BobbyDelhi](https://github.com/BobbyDelhi)

Este proyecto es un conjunto de scripts en **Bash** que permiten generar claves **RSA** y **AES**, realizar **cifrado simétrico** y **asimétrico (híbrido)**, verificar la **integridad de archivos** y gestionar **claves públicas** mediante una interfaz gráfica con **Zenity**.

---

# Instalación

1. Actualizar la máquina en caso de no ejecutar main.sh:
```bash
sudo apt update
sudo apt upgrade -y

```

3. Instalacion de dependencias
```bash
sudo apt install zenity
sudo apt install openssl
```


4. Clonar o copiar el script `script.sh` en un directorio.
```bash

git clone https://github.com/Bobbydelhi/Confidencialidad.git

```


5. Dar permisos de ejecución:
```bash
chmod +x main.sh script.sh subscript.sh 



```
6. Ejecutar programa:
```bash
./main.sh

```
