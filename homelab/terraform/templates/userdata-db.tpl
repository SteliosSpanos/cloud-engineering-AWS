#!/bin/bash
set -x

dnf update -y
dnf install -y httpd php php-pgsql jq
systemctl enable httpd
systemctl start httpd

# Install and configure CloudWatch Agent
dnf install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CWEOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/httpd-access"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/httpd-error"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/messages"
          }
        ]
      }
    }
  }
}
CWEOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Fetch database credentials from Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "${secret_arn}" --region "${region}" --query SecretString --output text)
DB_USER=$(echo "$SECRET_JSON" | jq -r '.username')
DB_PASS=$(echo "$SECRET_JSON" | jq -r '.password')

# Write database config outside document root
mkdir -p /var/www/inc

cat > /var/www/inc/dbinfo.inc << DBEOF
<?php
define('DB_SERVER',   '${db_address}');
define('DB_PORT',     '5432');
define('DB_USERNAME', '$DB_USER');
define('DB_PASSWORD', '$DB_PASS');
define('DB_DATABASE', '${db_name}');
?>
DBEOF

chmod 600 /var/www/inc/dbinfo.inc
chown apache:apache /var/www/inc/dbinfo.inc

cat > /var/www/html/SamplePage.php << 'EOF'
<?php include "/var/www/inc/dbinfo.inc"; ?>
<html>
<body>
<h1>Sample page</h1>
<?php

  $connection = pg_connect("host=" . DB_SERVER . " port=" . DB_PORT . " dbname=" . DB_DATABASE . " user=" . DB_USERNAME . " password=" . DB_PASSWORD . " sslmode=require");

  if (!$connection) {
    echo "Failed to connect to PostgreSQL";
    exit;
  }

  VerifyEmployeesTable($connection);

  $employee_name = htmlentities($_POST['NAME'] ?? '');
  $employee_address = htmlentities($_POST['ADDRESS'] ?? '');

  if (strlen($employee_name) || strlen($employee_address)) {
    AddEmployee($connection, $employee_name, $employee_address);
  }
?>

<!-- Input form -->
<form action="<?PHP echo $_SERVER['SCRIPT_NAME'] ?>" method="POST">
  <table border="0">
    <tr>
      <td>NAME</td>
      <td>ADDRESS</td>
    </tr>
    <tr>
      <td>
        <input type="text" name="NAME" maxlength="45" size="30" />
      </td>
      <td>
        <input type="text" name="ADDRESS" maxlength="90" size="60" />
      </td>
      <td>
        <input type="submit" value="Add Data" />
      </td>
    </tr>
  </table>
</form>

<!-- Display table data. -->
<table border="1" cellpadding="2" cellspacing="2">
  <tr>
    <td>ID</td>
    <td>NAME</td>
    <td>ADDRESS</td>
  </tr>

<?php

$result = pg_query($connection, "SELECT * FROM EMPLOYEES");

while($row = pg_fetch_row($result)) {
  echo "<tr>";
  echo "<td>",$row[0], "</td>",
       "<td>",$row[1], "</td>",
       "<td>",$row[2], "</td>";
  echo "</tr>";
}
?>

</table>

<?php

  pg_free_result($result);
  pg_close($connection);

?>

</body>
</html>


<?php

function AddEmployee($connection, $name, $address) {
   $result = pg_query_params($connection,
     'INSERT INTO EMPLOYEES (NAME, ADDRESS) VALUES ($1, $2)',
     array($name, $address));

   if(!$result) echo("<p>Error adding employee data.</p>");
}

function VerifyEmployeesTable($connection) {
  $result = pg_query($connection,
    "SELECT table_name FROM information_schema.tables WHERE table_name = 'employees' AND table_schema = 'public'");

  if(pg_num_rows($result) == 0) {
     $query = "CREATE TABLE EMPLOYEES (
         ID SERIAL PRIMARY KEY,
         NAME VARCHAR(45),
         ADDRESS VARCHAR(90)
       )";

     if(!pg_query($connection, $query)) echo("<p>Error creating table.</p>");
  }
}
?>
EOF

chown -R ec2-user:ec2-user /var/www/html
