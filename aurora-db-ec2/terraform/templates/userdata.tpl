#!/bin/bash
dnf update -y
dnf install -y httpd php php-pgsql php-mysqli mariadb105 postgresql15
systemctl enable httpd
systemctl start httpd

cat > /var/www/html/dbinfo.inc << 'EOF'
<?php
define('DB_SERVER',   '${db_address}');
define('DB_PORT',     '5432');
define('DB_USERNAME', '${db_username}');
define('DB_PASSWORD', '${db_password}');
define('DB_DATABASE', '${db_name}');
?>
EOF

cat > /var/www/html/SamplePage.php << 'EOF'
<?php
require 'dbinfo.inc';

try {
    $dsn  = "pgsql:host=" . DB_SERVER . ";port=" . DB_PORT . ";dbname=" . DB_DATABASE;
    $conn = new PDO($dsn, DB_USERNAME, DB_PASSWORD, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

    echo "<h1>Connected to PostgreSQL successfully!</h1>";
    echo "<p><strong>Host:</strong> " . DB_SERVER . "</p>";
    echo "<p><strong>Database:</strong> " . DB_DATABASE . "</p>";
    echo "<p><strong>User:</strong> " . DB_USERNAME . "</p>";

    $conn->exec("CREATE TABLE IF NOT EXISTS sample (
        id         SERIAL PRIMARY KEY,
        name       VARCHAR(100),
        created_at TIMESTAMP DEFAULT NOW()
    )");

    $stmt = $conn->prepare("INSERT INTO sample (name) VALUES (?)");
    $stmt->execute(['Hello from PHP on EC2!']);

    $rows = $conn->query("SELECT * FROM sample ORDER BY created_at DESC LIMIT 5")->fetchAll(PDO::FETCH_ASSOC);

    echo "<h2>Recent rows in 'sample' table:</h2><ul>";
    foreach ($rows as $row) {
        echo "<li>ID " . $row['id'] . " &mdash; " . $row['name'] . " (" . $row['created_at'] . ")</li>";
    }
    echo "</ul>";

} catch (PDOException $e) {
    echo "<h1>Connection failed</h1>";
    echo "<p>" . htmlspecialchars($e->getMessage()) . "</p>";
}
?>
EOF

chown -R ec2-user:ec2-user /var/www/html
