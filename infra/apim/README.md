# Azure API Management - ClickDelivery Gateway

## 📋 Índice
- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Funcionalidades](#funcionalidades)
- [Pré-requisitos](#pré-requisitos)
- [Estrutura de Arquivos](#estrutura-de-arquivos)
- [Configuração e Deploy](#configuração-e-deploy)
- [Configurações Avançadas](#configurações-avançadas)
- [Testes e Validação](#testes-e-validação)
- [Monitoramento](#monitoramento)
- [Troubleshooting](#troubleshooting)
- [Manutenção](#manutenção)

---

## 🎯 Visão Geral

Este módulo contém a infraestrutura como código (IaC) para provisionamento do **API Gateway** da plataforma ClickDelivery, utilizando **Azure API Management (APIM)**. 

O gateway atua como ponto de entrada único para todas as requisições do frontend, encaminhando-as para o BFF (Backend for Frontend), que por sua vez orquestra os microsserviços internos.

### Papel do Gateway na Arquitetura

O API Gateway é responsável por:
- **Ponto de entrada único**: Exposição de uma única URL pública para o frontend
- **Roteamento**: Encaminhamento de requisições para o BFF mantendo paths, métodos e headers
- **Segurança**: Aplicação de políticas de CORS, rate limiting e forward de tokens de autenticação
- **Observabilidade**: Geração e propagação de correlation IDs para rastreamento
- **Resiliência**: Timeouts configuráveis e tratamento de erros estruturado

---

## 🏗️ Arquitetura

### Diagrama de Fluxo

```
┌─────────────────────────┐
│  Microfrontend / SPA    │
│  (Browser)              │
└───────────┬─────────────┘
            │ HTTPS
            │ https://api.clickdelivery.com
            ▼
┌─────────────────────────────────────────────────┐
│  Azure API Management (APIM)                    │
│  ┌──────────────────────────────────────────┐   │
│  │  Policies:                               │   │
│  │  • CORS                                  │   │
│  │  • Rate Limiting                         │   │
│  │  • Header Forwarding                     │   │
│  │  • Correlation ID                        │   │
│  │  • Timeout Control                       │   │
│  └──────────────────────────────────────────┘   │
└───────────┬─────────────────────────────────────┘
            │ HTTPS
            │ https://clickdelivery-bff-service.azurewebsites.net
            ▼
┌─────────────────────────┐
│  BFF Service            │
│  (Backend for Frontend) │
└───────────┬─────────────┘
            │
            ▼
    ┌───────┴───────┐
    │ Microsserviços │
    └───────────────┘
    │  • User        │
    │  • Orders      │
    │  • Delivery    │
    │  • Rental      │
    │  • Notification│
    │  • Report      │
    └───────────────┘
```

### Fluxo de Requisição

1. **Cliente** → Envia requisição para `https://api.clickdelivery.com/api/v1/me/summary`
2. **APIM** → Recebe requisição e aplica policies:
   - Valida origem CORS
   - Verifica rate limit
   - Gera/propaga `x-correlation-id`
   - Adiciona headers de forwarding
3. **APIM** → Encaminha para `https://clickdelivery-bff-service.azurewebsites.net/api/v1/me/summary`
4. **BFF** → Processa e orquestra chamadas aos microsserviços
5. **BFF** → Retorna resposta
6. **APIM** → Adiciona header `x-bff-proxy: true` e retorna ao cliente

---

## ✨ Funcionalidades

### 1. CORS (Cross-Origin Resource Sharing)
- Configuração de origens permitidas via parâmetro
- Suporte para múltiplas origens separadas por vírgula
- Headers customizados permitidos
- Credenciais desabilitadas por padrão (segurança)

### 2. Rate Limiting
- Proteção contra abuso de API
- Limite configurável de requisições por período
- Headers informativos: `X-RateLimit-Remaining`, `X-RateLimit-Limit`, `Retry-After`
- Baseado em IP do cliente

### 3. Header Forwarding
- `Authorization`: Token de autenticação
- `x-correlation-id`: Rastreamento de requisições (gerado automaticamente se ausente)
- `x-forwarded-host`: Host original da requisição
- `x-forwarded-proto`: Protocolo original (https)
- `x-real-ip`: IP do cliente

### 4. Timeout Configurável
- Controle de timeout para requisições ao backend
- Default: 30 segundos
- Evita requisições travadas

### 5. Tratamento de Erros
- Respostas de erro estruturadas em JSON
- Inclui correlation ID para rastreamento
- Informações contextuais sobre o erro

### 6. Observabilidade (Opcional)
- Integração com Application Insights
- Log de requisições e respostas
- Correlação de traces
- Sampling configurável

---

## 🔧 Pré-requisitos

### Ferramentas Necessárias
- **Azure CLI** versão 2.40.0 ou superior
  ```bash
  az --version
  az login
  ```
- **Bicep CLI** (incluído no Azure CLI)
  ```bash
  az bicep version
  ```

### Permissões Azure
- **Contributor** no Resource Group de destino, ou
- Permissões específicas:
  - `Microsoft.ApiManagement/*`
  - `Microsoft.Insights/*` (se Application Insights habilitado)

### Recursos Dependentes
- **Backend BFF**: URL do serviço BFF já provisionado (ex: `https://clickdelivery-bff-service.azurewebsites.net`)
- **Resource Group**: Grupo de recursos criado no Azure

---

## 📁 Estrutura de Arquivos

```
infra/apim/
├── bicep/
│   ├── main.bicep           # Template principal do APIM
│   ├── parameters.json      # Parâmetros de configuração (exemplo)
│   └── apim-policy.xml      # Políticas XML (CORS, rate limit, etc)
├── terraform/               # (Futuro) Templates Terraform
└── README.md                # Esta documentação
```

### Descrição dos Arquivos

- **main.bicep**: Template Bicep que define todos os recursos Azure necessários (APIM, API, Backend, Named Values, etc)
- **parameters.json**: Arquivo de exemplo com valores de parâmetros para deploy
- **apim-policy.xml**: Definição XML das políticas aplicadas às requisições (carregado dinamicamente pelo Bicep)
- **README.md**: Documentação completa de uso e configuração

---

## 🚀 Configuração e Deploy

### Passo 1: Ajustar Parâmetros

Edite o arquivo `parameters.json` com os valores apropriados para seu ambiente:

```json
{
  "apimName": {
    "value": "cd-apim-gateway-prod"  // Nome único do APIM
  },
  "publisherEmail": {
    "value": "seu-email@clickdelivery.com"  // Obrigatório
  },
  "publisherName": {
    "value": "ClickDelivery Platform Team"
  },
  "skuName": {
    "value": "Consumption"  // Consumption, Developer, Basic, Standard, Premium
  },
  "bffBackendUrl": {
    "value": "https://clickdelivery-bff-service.azurewebsites.net"
  },
  "allowedOrigins": {
    "value": "https://app.clickdelivery.com,https://staging.clickdelivery.com"
  },
  "rateLimitCalls": {
    "value": 100  // Requisições permitidas por período
  },
  "rateLimitRenewalPeriod": {
    "value": 60  // Período em segundos
  },
  "enableAppInsights": {
    "value": true  // Habilitar observabilidade
  }
}
```

### Passo 2: Deploy via Azure CLI

#### 2.1 Validar Template

```bash
cd infra/apim/bicep

# Validar sintaxe do Bicep
az bicep build --file main.bicep

# Validar deployment (what-if)
az deployment group what-if \
  --resource-group <seu-resource-group> \
  --template-file main.bicep \
  --parameters parameters.json
```

#### 2.2 Executar Deploy

```bash
# Deploy completo
az deployment group create \
  --resource-group <seu-resource-group> \
  --template-file main.bicep \
  --parameters parameters.json \
  --name apim-deployment-$(date +%Y%m%d-%H%M%S)
```

**Tempo estimado**: 
- SKU Consumption: ~5-10 minutos
- SKU Developer/Basic: ~30-45 minutos
- SKU Standard/Premium: ~45-60 minutos

#### 2.3 Verificar Outputs

Após o deploy, capture os outputs importantes:

```bash
# Listar outputs do deployment
az deployment group show \
  --resource-group <seu-resource-group> \
  --name <deployment-name> \
  --query properties.outputs
```

Outputs disponíveis:
- `gatewayUrl`: URL pública do gateway (ex: `https://cd-apim-gateway.azure-api.net`)
- `apiUrl`: URL completa da API (ex: `https://cd-apim-gateway.azure-api.net/api/v1`)
- `developerPortalUrl`: Portal do desenvolvedor
- `appInsightsInstrumentationKey`: Chave do Application Insights (se habilitado)

### Passo 3: Configurar Domínio Customizado (Opcional)

Para usar domínio próprio como `api.clickdelivery.com`:

#### 3.1 Obter Certificado TLS

Opções:
- **Azure Key Vault** (recomendado)
- Let's Encrypt
- Certificado comercial

#### 3.2 Configurar DNS

Adicione registro CNAME apontando para o gateway APIM:

```
CNAME  api.clickdelivery.com  →  cd-apim-gateway.azure-api.net
```

#### 3.3 Atualizar Parâmetros e Re-deploy

```json
{
  "customDomain": {
    "value": "api.clickdelivery.com"
  },
  "certificateKeyVaultSecretId": {
    "value": "https://<key-vault-name>.vault.azure.net/secrets/<cert-name>"
  }
}
```

Execute novo deploy com os parâmetros atualizados.

### Passo 4: Deploy via Azure DevOps / GitHub Actions (CI/CD)

#### GitHub Actions (exemplo)

```yaml
name: Deploy APIM

on:
  push:
    branches: [main]
    paths:
      - 'infra/apim/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Bicep
        uses: azure/arm-deploy@v1
        with:
          resourceGroupName: clickdelivery-rg
          template: ./infra/apim/bicep/main.bicep
          parameters: ./infra/apim/bicep/parameters.json
          deploymentName: apim-${{ github.run_number }}
```

#### Azure DevOps (exemplo)

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - infra/apim/*

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: AzureCLI@2
  displayName: 'Deploy APIM'
  inputs:
    azureSubscription: 'Azure-Connection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      az deployment group create \
        --resource-group clickdelivery-rg \
        --template-file infra/apim/bicep/main.bicep \
        --parameters infra/apim/bicep/parameters.json \
        --name apim-$(Build.BuildNumber)
```

---

## ⚙️ Configurações Avançadas

### Adicionar Novas Origens CORS

**Opção 1: Re-deploy com parâmetro atualizado**

```json
{
  "allowedOrigins": {
    "value": "https://app.clickdelivery.com,https://admin.clickdelivery.com,https://staging.clickdelivery.com"
  }
}
```

**Opção 2: Atualizar Named Value via Portal**

1. Acesse Portal Azure → API Management
2. Navegue para **APIs** → **Named values**
3. Edite `allowedOrigins`
4. Adicione novos domínios separados por vírgula

### Alterar Rate Limit

**Via Named Values (sem re-deploy):**

1. Portal Azure → APIM → Named values
2. Edite `rateLimitCalls` (ex: `200`)
3. Edite `rateLimitRenewalPeriod` (ex: `120`)
4. Alterações aplicadas imediatamente

**Via Re-deploy:**

```json
{
  "rateLimitCalls": {
    "value": 200
  },
  "rateLimitRenewalPeriod": {
    "value": 120
  }
}
```

### Configurar Timeout do Backend

```json
{
  "serviceTimeoutMs": {
    "value": 60000  // 60 segundos
  }
}
```

### Habilitar Application Insights

```json
{
  "enableAppInsights": {
    "value": true
  },
  "appInsightsName": {
    "value": "cd-apim-insights-prod"
  }
}
```

### Import de OpenAPI Specification

Se o BFF expõe especificação OpenAPI:

```json
{
  "openApiSpecUrl": {
    "value": "https://clickdelivery-bff-service.azurewebsites.net/swagger/v1/swagger.json"
  }
}
```

Isso importa automaticamente todas as operações definidas no BFF.

### Subscription Keys (Autenticação de API)

Para exigir subscription key nas requisições:

1. Modifique no `main.bicep`:
```bicep
resource api 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  properties: {
    subscriptionRequired: true  // Alterar de false para true
  }
}
```

2. Criar subscription no Portal:
   - APIM → Subscriptions → Add
   - Escopo: API específica
   - Gerar keys

3. Clientes devem incluir header:
```
Ocp-Apim-Subscription-Key: <sua-key>
```

---

## 🧪 Testes e Validação

### Teste 1: Health Check

```bash
# Endpoint de saúde do BFF via gateway
curl -X GET https://api.clickdelivery.com/api/v1/health \
  -H "Content-Type: application/json" \
  -v
```

**Resposta esperada:**
- Status: `200 OK`
- Header: `x-bff-proxy: true`
- Header: `x-correlation-id: <uuid>`
- Body: JSON vindo do BFF

### Teste 2: CORS Preflight

```bash
curl -X OPTIONS https://api.clickdelivery.com/api/v1/me/summary \
  -H "Origin: https://app.clickdelivery.com" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: authorization" \
  -v
```

**Resposta esperada:**
- Status: `200 OK`
- Header: `Access-Control-Allow-Origin: https://app.clickdelivery.com`
- Header: `Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS`

### Teste 3: Rate Limiting

```bash
# Executar múltiplas requisições rapidamente
for i in {1..110}; do
  curl -X GET https://api.clickdelivery.com/api/v1/health -w "\n%{http_code}\n"
done
```

**Resposta esperada (após limite):**
- Status: `429 Too Many Requests`
- Header: `Retry-After: <segundos>`
- Body: JSON estruturado com erro

### Teste 4: Autenticação (com Authorization)

```bash
TOKEN="Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

curl -X GET https://api.clickdelivery.com/api/v1/me/summary \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -v
```

**Verificar:**
- Header `Authorization` chegou ao BFF
- Resposta autenticada correta

### Teste 5: Correlation ID

```bash
# Enviar correlation ID customizado
curl -X GET https://api.clickdelivery.com/api/v1/health \
  -H "x-correlation-id: test-123-456" \
  -v
```

**Verificar:**
- Response header `x-correlation-id: test-123-456`
- Mesmo ID propagado para logs

### Script de Validação Completo

```bash
#!/bin/bash

GATEWAY_URL="https://api.clickdelivery.com"
BASE_PATH="/api/v1"

echo "=== Teste 1: Health Check ==="
curl -s -w "\nStatus: %{http_code}\n" \
  "${GATEWAY_URL}${BASE_PATH}/health"

echo -e "\n=== Teste 2: CORS Preflight ==="
curl -s -I -X OPTIONS \
  -H "Origin: https://app.clickdelivery.com" \
  -H "Access-Control-Request-Method: GET" \
  "${GATEWAY_URL}${BASE_PATH}/me/summary" | grep -i "access-control"

echo -e "\n=== Teste 3: Correlation ID ==="
curl -s -I -H "x-correlation-id: test-validation" \
  "${GATEWAY_URL}${BASE_PATH}/health" | grep -i "x-correlation-id"

echo -e "\n=== Teste 4: Rate Limit Headers ==="
curl -s -I "${GATEWAY_URL}${BASE_PATH}/health" | grep -i "x-ratelimit"

echo -e "\n✅ Validação completa!"
```

---

## 📊 Monitoramento

### Application Insights (se habilitado)

#### Acessar Logs

1. Portal Azure → Application Insights → Logs
2. Query exemplo:

```kusto
// Requisições com erro no APIM
requests
| where timestamp > ago(1h)
| where success == false
| where cloud_RoleName == "cd-apim-gateway"
| project timestamp, name, resultCode, duration, customDimensions
| order by timestamp desc
```

#### Métricas Importantes

- **Availability**: Taxa de sucesso das requisições
- **Performance**: Latência (p50, p95, p99)
- **Failures**: Taxa de erro por tipo
- **Rate Limit**: Requisições bloqueadas

#### Criar Alertas

```bash
# Alerta para taxa de erro > 5%
az monitor metrics alert create \
  --name "apim-error-rate-high" \
  --resource-group <rg-name> \
  --scopes <apim-resource-id> \
  --condition "avg Failed Requests > 5" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action <action-group-id>
```

### Azure Monitor

#### Métricas Nativas do APIM

- **Requests**: Total de requisições
- **Capacity**: Utilização do gateway (para SKUs não-Consumption)
- **Gateway Requests**: Requisições por backend
- **Duration**: Tempo de resposta

#### Dashboard Recomendado

1. Portal Azure → Dashboards → New dashboard
2. Adicionar tiles:
   - Gráfico de linha: Requests over time
   - Gráfico de área: Error rate
   - Número: Total requests (last 24h)
   - Gráfico de barras: Top endpoints

---

## 🔍 Troubleshooting

### Problema: Deploy falha com erro de SKU

**Erro:**
```
The specified SKU is not available in the selected location
```

**Solução:**
- Verificar SKUs disponíveis na região:
```bash
az provider show --namespace Microsoft.ApiManagement \
  --query "resourceTypes[?resourceType=='service'].locations" -o table
```
- Usar região alternativa ou SKU diferente

### Problema: CORS não funciona

**Sintomas:**
- Erro no browser: "No 'Access-Control-Allow-Origin' header"

**Diagnóstico:**
1. Verificar origem no Named Value `allowedOrigins`
2. Testar preflight: `curl -X OPTIONS -H "Origin: <sua-origem>"`
3. Verificar logs do APIM

**Solução:**
- Adicionar origem correta aos `allowedOrigins`
- Verificar que política CORS está ativa (inbound)

### Problema: Rate limit não aplica

**Sintomas:**
- Mais de 100 requisições/min sem bloqueio

**Diagnóstico:**
1. Verificar Named Values: `rateLimitCalls`, `rateLimitRenewalPeriod`
2. Conferir se policy está aplicada

**Solução:**
```bash
# Verificar policy via CLI
az apim api policy show \
  --resource-group <rg> \
  --service-name <apim-name> \
  --api-id clickdelivery-bff-api
```

### Problema: Backend não responde (504 Gateway Timeout)

**Sintomas:**
- Requisições demoram 30s e retornam 504

**Diagnóstico:**
1. Verificar se BFF está respondendo diretamente
2. Checar Named Value `serviceTimeoutMs`
3. Logs do Application Insights

**Solução:**
- Aumentar timeout: `serviceTimeoutMs: 60000`
- Otimizar performance do BFF
- Verificar conectividade de rede

### Problema: Correlation ID não propaga

**Sintomas:**
- Logs sem correlation ID

**Diagnóstico:**
```bash
curl -v -H "x-correlation-id: test-123" \
  https://api.clickdelivery.com/api/v1/health
```

**Solução:**
- Verificar que BFF lê e propaga o header
- Conferir política `set-header` no inbound

### Problema: Custom domain não resolve

**Sintomas:**
- `api.clickdelivery.com` não responde

**Diagnóstico:**
1. Verificar DNS:
```bash
nslookup api.clickdelivery.com
```
2. Verificar certificado no Key Vault
3. Conferir hostname configuration no APIM

**Solução:**
- Aguardar propagação DNS (até 48h)
- Validar certificado válido e não expirado
- Re-deploy com parâmetros corretos

---

## 🔧 Manutenção

### Atualização de Versão

#### Atualizar Bicep

```bash
# Atualizar Azure CLI (inclui Bicep)
az upgrade

# Verificar versão
az bicep version
```

#### Atualizar API Version

No `main.bicep`, atualizar `@<version>` dos recursos para versões mais recentes:

```bicep
resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  // Atualizar para versão mais nova quando disponível
}
```

### Backup e Restore

#### Backup Manual

```bash
# Backup da configuração do APIM
az apim backup \
  --resource-group <rg> \
  --name <apim-name> \
  --backup-name apim-backup-$(date +%Y%m%d) \
  --storage-account-name <storage-account> \
  --storage-account-container backups \
  --storage-account-key <key>
```

#### Restore

```bash
az apim restore \
  --resource-group <rg> \
  --name <apim-name> \
  --backup-name apim-backup-20240101 \
  --storage-account-name <storage-account> \
  --storage-account-container backups \
  --storage-account-key <key>
```

### Limpeza de Recursos (Ambiente de Teste)

```bash
# Deletar apenas o APIM
az apim delete \
  --resource-group <rg> \
  --name <apim-name> \
  --yes

# Deletar deployment completo
az deployment group delete \
  --resource-group <rg> \
  --name <deployment-name>
```

---

## 📝 Checklist Pós-Deploy

Após executar o deploy, validar os seguintes itens:

### ✅ Configuração Básica
- [ ] APIM provisionado com sucesso
- [ ] API criada com nome `clickdelivery-bff-api`
- [ ] Backend configurado apontando para BFF
- [ ] Named Values criados (allowedOrigins, rateLimitCalls, etc)

### ✅ Políticas (Policies)
- [ ] CORS configurado com origens corretas
- [ ] Rate limit ativo e testado
- [ ] Headers de forwarding funcionando (Authorization, x-correlation-id)
- [ ] Timeout configurado adequadamente

### ✅ Conectividade
- [ ] Gateway URL acessível: `https://<apim-name>.azure-api.net`
- [ ] Endpoint de health respondendo: `/api/v1/health`
- [ ] Requisições chegando ao BFF corretamente
- [ ] DNS configurado (se usando domínio customizado)

### ✅ Segurança
- [ ] TLS 1.2+ habilitado (TLS 1.0/1.1 desabilitado)
- [ ] Certificado válido configurado (se domínio customizado)
- [ ] Origens CORS limitadas (não usar `*` em produção)
- [ ] Secrets não hardcoded no código

### ✅ Observabilidade
- [ ] Application Insights integrado (se habilitado)
- [ ] Correlation IDs propagando corretamente
- [ ] Logs visíveis no portal
- [ ] Métricas sendo coletadas

### ✅ Testes
- [ ] Health check via gateway funcional
- [ ] CORS preflight testado
- [ ] Rate limit testado e bloqueando após limite
- [ ] Autenticação (Authorization header) passando
- [ ] Endpoints principais do BFF acessíveis via gateway

### ✅ Documentação
- [ ] Parâmetros documentados no `parameters.json`
- [ ] URLs e endpoints anotados
- [ ] Credenciais armazenadas em local seguro (Key Vault)
- [ ] Runbook de troubleshooting disponível

---

## 📚 Referências

### Documentação Microsoft

- [Azure API Management - Documentação Oficial](https://learn.microsoft.com/azure/api-management/)
- [Bicep - Documentação](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [APIM Policies Reference](https://learn.microsoft.com/azure/api-management/api-management-policies)
- [APIM - Best Practices](https://learn.microsoft.com/azure/api-management/api-management-best-practices)

### Bicep Resources

- [APIM Service Resource](https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service)
- [APIM API Resource](https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis)
- [APIM Policies](https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies)

### Ferramentas Úteis

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Bicep Playground](https://aka.ms/bicepdemo)
- [REST API Tester](https://reqbin.com/)

---

## 🤝 Contribuindo

### Reportar Problemas

Abra uma issue no repositório descrevendo:
- Ambiente (SKU do APIM, região Azure, etc)
- Passos para reproduzir
- Comportamento esperado vs atual
- Logs relevantes

### Sugestões de Melhoria

Pull requests são bem-vindos! Áreas de interesse:
- Terraform templates (alternativa ao Bicep)
- Policies adicionais (caching, JWT validation, etc)
- Scripts de automação
- Melhorias na documentação

---

## 📄 Licença

Este projeto é licenciado sob os termos da licença MIT. Veja o arquivo LICENSE para mais detalhes.

---

## 👥 Contato

**ClickDelivery Platform Team**
- Email: platform-team@clickdelivery.com
- Slack: #platform-team

---

**Última atualização:** 2024
**Versão da documentação:** 1.0.0
