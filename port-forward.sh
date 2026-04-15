#!/bin/bash

echo "=== Starting port forwards ==="
echo ""
echo "  App (login-page):  http://localhost:8080"
echo "  Grafana:           http://localhost:3000"
echo ""

# Fetch Grafana admin password
GRAFANA_PASS=$(kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "  Grafana credentials:  admin / $GRAFANA_PASS"
echo ""
echo "Press Ctrl+C to stop all port forwards."
echo ""

# Start port forwards in background
kubectl port-forward svc/login-page-service 8080:80 -n sopra-hr &
PID_APP=$!

kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring &
PID_GRAFANA=$!

# Trap Ctrl+C to kill both
trap "kill $PID_APP $PID_GRAFANA 2>/dev/null; echo ''; echo 'Port forwards stopped.'; exit 0" INT TERM

# Wait for both
wait
