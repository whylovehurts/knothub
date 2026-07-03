# Prompt de Refatoração: Separação de Arquitetura Client-Side (UI ↔ Controller) em Luau

Você atuará como um Engenheiro de Software especialista em Luau (ambiente Client-Side). Sua tarefa é refatorar os scripts principais (`main.lua`) de um projeto executado inteiramente no cliente, aplicando um padrão de arquitetura desacoplado para separar a Interface de Usuário (Frontend) da Lógica de Execução Local (Backend/Controller), visando manutenibilidade e eficiência de memória.

## 1. Diretrizes de Arquitetura e Separação de Conceitos (SoC)
* **Frontend (Camada de Apresentação):** O script `main.lua` ou os scripts acoplados à UI devem atuar exclusivamente como consumidores de serviços locais. A UI deve apenas escutar inputs do usuário e despachar requisições para os módulos de lógica, sendo proibido o processamento interno de dados ou execuções diretas de regras de negócio.
* **Backend Local (Camada de Controle/Serviço):** Toda a lógica operacional, manipulação de estados locais e tabelas de funções devem ser centralizadas em `ModuleScripts` dedicados.

## 2. Otimização de Tabelas de Funções (Luau Memory Management)
Como o script gerencia grandes volumes de funções localmente, o backend deve estruturar o armazenamento de dados utilizando um dos seguintes padrões nativos do Luau para otimização de pegada de memória (memory footprint):
* **Metatabelas com `__index` (Prototype Pattern):** Compartilhamento de métodos através de protótipos para evitar a duplicação de closures na memória.
* **Flyweight Pattern via ModuleScripts:** Centralização de dicionários estáticos de funções imutáveis.
* **Lazy Loading (Carregamento Sob Demanda):** Inicialização dinâmica de subtabelas de funções apenas no momento da primeira chamada do método.

## 3. Padrão de Invocação Local (Desacoplamento)
* A comunicação entre a UI e os módulos de lógica deve ser feita por chamadas diretas a uma API exposta pelo módulo (métodos públicos) ou através de `BindableEvents` locais para arquiteturas orientadas a eventos dentro do próprio cliente.
* O acionamento de um elemento visual deve se limitar a encapsular os parâmetros necessários e repassar a execução imediatamente para o Controller responsável.

## 4. Entregáveis Requeridos
1. **Estrutura Refatorada do `main.lua` (Frontend):** Código focado estritamente na captura de eventos de UI e delegação imediata para o módulo lógico.
2. **Módulo de Lógica Local (Backend):** Um `ModuleScript` demonstrando a implementação de uma tabela de funções em larga escala utilizando uma das técnicas de otimização de memória citadas.
3. **Padrão de Extensibilidade:** Código limpo e modularizado que permita a inserção de novas funcionalidades no backend sem a necessidade de alterar a estrutura de escuta da UI.