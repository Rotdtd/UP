#!/bin/bash

set -e

echo "=========================================="
echo " INSTALADOR WEB USUARIOS ACTIVOS"
echo " Apache : 8888"
echo " Cuenta : puertos 80 y 443"
echo "=========================================="

# Comprobar root
if [ "$EUID" -ne 0 ]; then
    echo "Ejecuta este script como root:"
    echo "sudo bash instalar_online.sh"
    exit 1
fi

echo ""
echo "[1/8] Actualizando paquetes..."
apt update

echo ""
echo "[2/8] Instalando Apache, PHP y herramientas..."
apt install -y apache2 php libapache2-mod-php iproute2

echo ""
echo "[3/8] Creando respaldo de configuración..."

mkdir -p /root/backup_online

cp -a /etc/apache2/ports.conf \
    /root/backup_online/ports.conf.bak 2>/dev/null || true

cp -a /etc/apache2/sites-available/000-default.conf \
    /root/backup_online/000-default.conf.bak 2>/dev/null || true

echo ""
echo "[4/8] Configurando Apache solamente en puerto 8888..."

# Desactivar todos los sitios actuales
for site in /etc/apache2/sites-enabled/*.conf; do
    if [ -e "$site" ]; then
        a2dissite "$(basename "$site")" >/dev/null 2>&1 || true
    fi
done

# Configuración de puertos de Apache
cat > /etc/apache2/ports.conf <<'EOF'
Listen 8888
EOF

# Crear sitio Apache
cat > /etc/apache2/sites-available/online8888.conf <<'EOF'
<VirtualHost *:8888>

    ServerName localhost

    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    DirectoryIndex index.php index.html

</VirtualHost>
EOF

a2ensite online8888.conf

echo ""
echo "[5/8] Activando PHP..."
a2enmod php8.1 2>/dev/null || true

echo ""
echo "[6/8] Creando endpoint /server/online..."

mkdir -p /var/www/html/server/online

cat > /var/www/html/server/online/index.php <<'EOF'
<?php

header("Content-Type: text/plain; charset=utf-8");
header("Cache-Control: no-store, no-cache, must-revalidate");
header("Pragma: no-cache");

// Contar conexiones ESTABLISHED cuyo puerto local sea 80 o 443
$comando = "/usr/bin/ss -H state established '( sport = :443 or sport = :80 )' | /usr/bin/wc -l";

$total = shell_exec($comando);

echo intval(trim($total));

?>
EOF

chown -R www-data:www-data /var/www/html/server
chmod -R 755 /var/www/html/server

echo ""
echo "[7/8] Comprobando configuración Apache..."

apache2ctl configtest

echo ""
echo "[8/8] Reiniciando Apache..."

systemctl enable apache2
systemctl restart apache2

echo ""
echo "=========================================="
echo " INSTALACIÓN TERMINADA"
echo "=========================================="

echo ""
echo "Apache:"
systemctl is-active apache2

echo ""
echo "Puerto 8888:"
ss -ltnp | grep ':8888' || true

echo ""
echo "Prueba local:"
curl -s http://127.0.0.1:8888/server/online
echo ""

echo ""
echo "=========================================="
echo " URL:"
echo " http://TU-IP:8888/server/online"
echo "=========================================="
