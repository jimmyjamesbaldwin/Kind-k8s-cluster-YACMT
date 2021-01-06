Write-Host "Bootstrapping Kubernetes cluster (using Kind) and waiting for startup..." -ForegroundColor Green
kind create cluster --config cluster.yaml --wait 1m

Write-Host "`nDeploying Ingress-Nginx..." -ForegroundColor Green
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s

Write-Host "`nGenerating CA Private Key & Signing Cert..." -ForegroundColor Green
New-Item -ItemType directory -Path certificates > $null
openssl genrsa -out .\certificates\CA.key 2048
openssl req -x509 -new -nodes -key .\certificates\CA.key -sha256 -days 365 -subj "/C=GB/ST=London/L=London/O=jimmyjamesbaldwin/OU=jimmyjamesbaldwin/CN=*.cluster.com" -out .\certificates\CA.crt

Write-Host "`nCreating yaml Secret containing CA details..." -ForegroundColor Green
$keypairYaml = (Get-Content -path .\k8s\ca-key-pair.yaml -Raw) -replace '<cert>', ([Convert]::ToBase64String((Get-Content -Path .\certificates\CA.crt -Encoding Byte)))
$keypairYaml = $keypairYaml -replace '<key>', ([Convert]::ToBase64String((Get-Content -Path .\certificates\CA.key -Encoding Byte))) > .\k8s\ca-key-pair.yaml

Write-Host "`nDeploying cert-manager..." -ForegroundColor Green
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml
Start-Sleep 90 # wait for the cert-manager admission controllers to finish setting up
kubectl apply -f .\k8s\ca-key-pair.yaml
kubectl apply -f .\k8s\ca-issuer.yaml

Write-Host "`nDeploying demo helloworld application..." -ForegroundColor Green
kubectl apply -f .\k8s\demo-helloworld.yaml




