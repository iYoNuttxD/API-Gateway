# API-Gateway - ClickDelivery Platform

## 📋 Visão Geral

Este repositório contém a infraestrutura como código (IaC) para o **API Gateway** da plataforma ClickDelivery, implementado com **Azure API Management (APIM)**.

O API Gateway atua como ponto de entrada único para todas as requisições do frontend (microfrontend/SPA), encaminhando-as para o BFF (Backend for Frontend), que orquestra os microsserviços internos da plataforma.

## 🏗️ Arquitetura

```
[Browser/SPA] → [Azure APIM Gateway] → [BFF Service] → [Microsserviços]
```

## 🚀 Começando

### Estrutura do Repositório

```
.
├── infra/
│   └── apim/               # Templates de infraestrutura do API Gateway
│       ├── bicep/          # Templates Bicep para Azure
│       │   ├── main.bicep           # Template principal
│       │   ├── parameters.json      # Parâmetros de configuração
│       │   └── apim-policy.xml      # Políticas (CORS, rate limit, etc)
│       └── README.md       # Documentação completa (em português)
├── LICENSE
└── README.md               # Este arquivo
```

### Deploy Rápido

1. **Ajuste os parâmetros** em `infra/apim/bicep/parameters.json`
2. **Execute o deploy**:
   ```bash
   az deployment group create \
     --resource-group <seu-resource-group> \
     --template-file infra/apim/bicep/main.bicep \
     --parameters infra/apim/bicep/parameters.json
   ```
3. **Valide** acessando `https://<seu-apim>.azure-api.net/api/v1/health`

## 📚 Documentação

Documentação completa e detalhada (em português) está disponível em:

👉 **[infra/apim/README.md](infra/apim/README.md)**

A documentação inclui:
- Arquitetura detalhada e diagramas
- Guia de configuração passo a passo
- Testes e validação
- Monitoramento e observabilidade
- Troubleshooting
- Manutenção e operações

## ✨ Funcionalidades

- ✅ **CORS configurável** para múltiplas origens
- ✅ **Rate limiting** para proteção contra abuso
- ✅ **Forward de headers** (Authorization, correlation ID, etc)
- ✅ **Timeout configurável** para requisições ao backend
- ✅ **Observabilidade** com Application Insights (opcional)
- ✅ **Domínio customizado** suportado (ex: api.clickdelivery.com)
- ✅ **Tratamento de erros** estruturado em JSON
- ✅ **Templates idempotentes** para CI/CD

## 🔧 Tecnologias

- **Azure API Management** (APIM)
- **Bicep** (Infrastructure as Code)
- **Application Insights** (Observabilidade)
- **Azure CLI** (Deploy e gerenciamento)

## 📄 Licença

Este projeto é licenciado sob os termos da licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor, consulte a [documentação completa](infra/apim/README.md) para mais informações sobre como contribuir.

---

**ClickDelivery Platform Team**