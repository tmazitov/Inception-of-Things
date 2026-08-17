echo 'Checking SSH connection to tmazitovS'
vagrant ssh tmazitovS -c "echo SSH OK && hostname && uptime"

echo $'\nChecking SSH connection to nmagdanoSW'
vagrant ssh nmagdanoSW -c "echo SSH OK && hostname && uptime"