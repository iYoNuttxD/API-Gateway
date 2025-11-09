// ============================================================================
// Azure API Management - ClickDelivery Gateway
// ============================================================================
// Template principal para provisionamento do API Gateway usando Azure APIM
// Autor: ClickDelivery Platform Team
// ============================================================================

// Parâmetros de Configuração Geral
// ============================================================================

@description('Localização dos recursos Azure (ex: brazilsouth, eastus)')
param location string = resourceGroup().location

@description('Nome do recurso API Management (ex: cd-apim-gateway)')
@minLength(1)
@maxLength(50)
param apimName string

@description('Email do publisher (obrigatório para APIM)')
param publisherEmail string

@description('Nome do publisher/organização')
param publisherName string

@description('SKU do APIM (Consumption para low-cost, Developer para testes, Basic/Standard/Premium para produção)')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Consumption'

@description('Capacidade do SKU (0 para Consumption, 1+ para outros)')
@minValue(0)
param skuCapacity int = 0

// Parâmetros de Backend (BFF)
// ============================================================================

@description('URL base do backend BFF (ex: https://clickdelivery-bff-service.azurewebsites.net)')
param bffBackendUrl string = 'https://clickdelivery-bff-service.azurewebsites.net'

@description('Nome interno da API no APIM')
param apiName string = 'clickdelivery-bff-api'

@description('Display name da API no APIM')
param apiDisplayName string = 'ClickDelivery BFF API'

@description('Path base da API (sem trailing slash)')
param apiPath string = 'api/v1'

@description('URL da especificação OpenAPI do BFF (opcional - pode ser configurada posteriormente)')
param openApiSpecUrl string = ''

// Parâmetros de Políticas (CORS, Rate Limit, Timeout)
// ============================================================================

@description('Origens permitidas para CORS (lista separada por vírgula)')
param allowedOrigins string = 'https://app.clickdelivery.com'

@description('Número máximo de chamadas permitidas no período de renovação (rate limit)')
@minValue(1)
param rateLimitCalls int = 100

@description('Período de renovação do rate limit em segundos')
@minValue(1)
param rateLimitRenewalPeriod int = 60

@description('Timeout do serviço backend em milissegundos')
@minValue(1000)
@maxValue(300000)
param serviceTimeoutMs int = 30000

// Parâmetros de Observabilidade
// ============================================================================

@description('Habilitar integração com Application Insights')
param enableAppInsights bool = false

@description('Nome do Application Insights (necessário se enableAppInsights = true)')
param appInsightsName string = ''

@description('Nome do Logger no APIM para Application Insights')
param loggerName string = 'apim-logger'

// Parâmetros de Domínio Customizado (Opcional)
// ============================================================================

@description('Domínio customizado (ex: api.clickdelivery.com) - deixe vazio para usar domínio padrão do APIM')
param customDomain string = ''

@description('ID do certificado no Key Vault (necessário se customDomain for especificado)')
@secure()
param certificateKeyVaultSecretId string = ''

// Tags para Organização
// ============================================================================

param tags object = {
  Application: 'ClickDelivery'
  Component: 'API-Gateway'
  Environment: 'Production'
  ManagedBy: 'Bicep-IaC'
}

// ============================================================================
// Recursos
// ============================================================================

// Application Insights (Opcional)
// ============================================================================
resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (enableAppInsights) {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: tags
}

// API Management Service
// ============================================================================
resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
    }
  }
  tags: tags
}

// Logger para Application Insights (se habilitado)
// ============================================================================
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-03-01-preview' = if (enableAppInsights) {
  parent: apimService
  name: loggerName
  properties: {
    loggerType: 'applicationInsights'
    resourceId: enableAppInsights ? appInsights.id : ''
    credentials: {
      instrumentationKey: enableAppInsights ? appInsights.properties.InstrumentationKey : ''
    }
  }
}

// Backend do BFF
// ============================================================================
resource bffBackend 'Microsoft.ApiManagement/service/backends@2023-03-01-preview' = {
  parent: apimService
  name: 'clickdelivery-bff-backend'
  properties: {
    title: 'ClickDelivery BFF Service'
    description: 'Backend para o BFF que orquestra os microsserviços'
    protocol: 'http'
    url: bffBackendUrl
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

// API Definition
// ============================================================================
resource api 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apimService
  name: apiName
  properties: {
    displayName: apiDisplayName
    description: 'API Gateway para o BFF do ClickDelivery - encaminha todas as requisições para o backend BFF'
    path: apiPath
    protocols: [
      'https'
    ]
    subscriptionRequired: false
    type: 'http'
    format: empty(openApiSpecUrl) ? 'openapi-link' : 'openapi-link'
    value: empty(openApiSpecUrl) ? '' : openApiSpecUrl
    serviceUrl: bffBackendUrl
  }
}

// Operação Wildcard (catch-all para pass-through)
// ============================================================================
// Esta operação captura todas as requisições e encaminha para o BFF
resource apiOperationWildcard 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  parent: api
  name: 'wildcard'
  properties: {
    displayName: 'Wildcard Operation'
    method: '*'
    urlTemplate: '/*'
    description: 'Captura todas as requisições e encaminha para o BFF preservando método, path e headers'
  }
}

// Policy da API (aplicada a todas as operações)
// ============================================================================
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    value: loadTextContent('apim-policy.xml')
    format: 'xml'
  }
  dependsOn: [
    apiOperationWildcard
  ]
}

// Named Values (variáveis reutilizáveis nas policies)
// ============================================================================
resource namedValueAllowedOrigins 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apimService
  name: 'allowedOrigins'
  properties: {
    displayName: 'allowedOrigins'
    value: allowedOrigins
    tags: [
      'cors'
    ]
  }
}

resource namedValueRateLimitCalls 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apimService
  name: 'rateLimitCalls'
  properties: {
    displayName: 'rateLimitCalls'
    value: string(rateLimitCalls)
    tags: [
      'ratelimit'
    ]
  }
}

resource namedValueRateLimitPeriod 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apimService
  name: 'rateLimitRenewalPeriod'
  properties: {
    displayName: 'rateLimitRenewalPeriod'
    value: string(rateLimitRenewalPeriod)
    tags: [
      'ratelimit'
    ]
  }
}

resource namedValueServiceTimeout 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apimService
  name: 'serviceTimeoutMs'
  properties: {
    displayName: 'serviceTimeoutMs'
    value: string(serviceTimeoutMs)
    tags: [
      'timeout'
    ]
  }
}

resource namedValueBffBackendUrl 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apimService
  name: 'bffBackendUrl'
  properties: {
    displayName: 'bffBackendUrl'
    value: bffBackendUrl
    tags: [
      'backend'
    ]
  }
}

// Domínio Customizado (Opcional)
// ============================================================================
// NOTA: Configuração de domínio customizado deve ser feita manualmente no Portal
// ou via script Azure CLI após o deployment, pois requer configuração de gateway existente.
// Referência: https://learn.microsoft.com/azure/api-management/configure-custom-domain

// Para configurar via CLI após deploy:
// az apim api update --resource-group <rg> --service-name <apim-name> \
//   --api-id <api-id> --service-url <backend-url>
// 
// Configurar hostname customizado:
// 1. Importar certificado no APIM
// 2. Configurar hostname no gateway
// 3. Atualizar DNS CNAME

// Diagnostic Settings (se Application Insights habilitado)
// ============================================================================
resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2023-03-01-preview' = if (enableAppInsights) {
  parent: api
  name: 'applicationinsights'
  properties: {
    loggerId: enableAppInsights ? apimLogger.id : ''
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    logClientIp: true
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: [
          'x-correlation-id'
          'authorization'
        ]
        body: {
          bytes: 1024
        }
      }
      response: {
        headers: [
          'x-correlation-id'
          'x-bff-proxy'
        ]
        body: {
          bytes: 1024
        }
      }
    }
    backend: {
      request: {
        headers: [
          'x-correlation-id'
        ]
        body: {
          bytes: 1024
        }
      }
      response: {
        headers: [
          'x-correlation-id'
        ]
        body: {
          bytes: 1024
        }
      }
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('ID do recurso API Management')
output apimResourceId string = apimService.id

@description('Nome do API Management')
output apimName string = apimService.name

@description('URL do gateway (endpoint público)')
output gatewayUrl string = apimService.properties.gatewayUrl

@description('URL completa da API (com path base)')
output apiUrl string = '${apimService.properties.gatewayUrl}/${apiPath}'

@description('Portal do desenvolvedor')
output developerPortalUrl string = apimService.properties.developerPortalUrl

@description('Portal de gerenciamento')
output managementApiUrl string = apimService.properties.managementApiUrl

@description('Application Insights Instrumentation Key (se habilitado)')
output appInsightsInstrumentationKey string = enableAppInsights ? appInsights.properties.InstrumentationKey : ''

@description('Application Insights Resource ID (se habilitado)')
output appInsightsId string = enableAppInsights ? appInsights.id : ''
