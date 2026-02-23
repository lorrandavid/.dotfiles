---
name: create-commit
description: 'Criação de mensagens de commit seguindo as diretivas do "conventional commits".'
---

## Instruções

Gerar mensagens de commit seguindo as diretrizes do "conventional commits". Sua tarefa é analisar as mudanças recentes em arquivos de código e gerar uma mensagem de commit apropriada.

Antes de criar a mensagem de commit, siga estas etapas:
1. **Análise das Mudanças**: Revise as mudanças recentes nos arquivos de código para entender o que foi implementado, corrigido ou modificado.
2. **Verifique os arquivos "staged"**: Certifique-se de que você está considerando apenas os arquivos que foram "staged" para commit através do comando `git diff --cached --name-only`.
3. **Identificação do Tipo de Commit**: Determine o tipo de commit adequado (caso esteja numa branch que inicia com um verbo no imperativo, seguido de "/", e um número - utilizar esse número como escopo, colocando um "#" como sufixo - ex: branch com nome task/123, o tipo do commit é "task", e o escopo será "#123". Caso contrário, pergunte ao usuário qual o tipo e escopo a serem utilizados):
   - feat: para novas funcionalidades
   - fix: para correções de bugs
   - docs: para mudanças na documentação
   - style: para mudanças que não afetam o significado do código (espaços em branco, formatação, etc.)
   - refactor: para mudanças no código que não adicionam funcionalidades nem corrigem bugs
   - test: para adição ou modificação de testes
   - chore: para tarefas de manutenção e outras mudanças que não afetam o código-fonte ou os testes

Sempre que necessário, peça mais informações ao usuário para garantir que a mensagem de commit seja completa e precisa.

Utilize `git status --short` para obter um resumo das mudanças e `git diff --cached` para ver as diferenças detalhadas.

## Formato da Mensagem de Commit

** Título do commit: **
Crie um título claro e descritivo (máximo de 50 caracteres contando com o tipo + escopo do commit) que:
- Comece com um verbo no imperativo (task, fix, refactor, docs, style, chore, etc.)
- Defina o escopo entre parênteses.
- Descreva o que foi implementado ou alterado.
- Seja específico mas conciso.

** Corpo do commit: **

### Resumo

Breve descrição do que este commit implementa ou resolve.

### Motivação e Contexto
Explique o motivo das mudanças e o contexto em que foram feitas. Inclua referências a issues ou tickets relacionados, se aplicável.

### Descrição Técnica
Detalhe as mudanças técnicas feitas no código. Explique as decisões de design, padrões utilizados e qualquer consideração importante para futuros desenvolvedores que possam trabalhar neste código. **É importante que esta seção seja separada em tópicos**.

## Exemplo de Mensagem de Commit

```
feat(#123): adicionar validação de entrada no formulário de cadastro

### Resumo
Adiciona validação de entrada para garantir que os dados do usuário estejam corretos antes do envio do formulário de cadastro.

### Motivação e Contexto
A validação de entrada é crucial para melhorar a experiência do usuário e evitar erros no backend. Esta implementação resolve a issue #123, onde usuários relataram problemas ao enviar dados inválidos.

### Descrição Técnica
- Utiliza a biblioteca XYZ para validação de formulários.
- Implementa regras de validação para campos obrigatórios, formatos de email e senhas.
- Adiciona mensagens de erro amigáveis para orientar os usuários.
- Inclui testes unitários para garantir a robustez da validação.
```
