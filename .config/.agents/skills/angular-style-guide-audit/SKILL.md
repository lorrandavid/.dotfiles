---
name: angular-style-guide-audit
description: Audita código Angular contra o style guide oficial (https://angular.dev/style-guide) e três regras do projeto (subscribe em componentes, componentes grandes com divisão smart/dumb e complexidade CDD medida por script), e gera um relatório somente leitura. Cobre nomes de arquivos, estrutura por feature, um conceito por arquivo, inject(), seletores, nomes de inputs/outputs, ordem de membros, lógica fora da UI, templates complexos, protected, readonly, ngClass/ngStyle, handlers, lifecycle hooks, subscribe() em componentes, tamanho de componentes e pontos de complexidade cognitiva por classe. Use sempre que o usuário pedir para auditar, revisar, checar conformidade, medir complexidade ou "ver o que está fora do padrão" num projeto, pasta ou arquivo Angular, mesmo que não cite "style guide" ou "auditoria".
---

# Auditoria Angular contra o style guide

Esta skill compara código Angular com o style guide oficial e com três regras do projeto, e entrega um relatório. Ela não altera código.

O texto oficial está em `references/style-guide.md`. Leia esse arquivo antes de começar. Ele é a fonte da verdade: cite as seções dele pelo título em inglês e use as palavras dele quando explicar uma regra.

## Escopo: o guia e as regras do projeto

Audite as regras do style guide, os trechos de nomes que ele cita (seletores, inputs e outputs) e as três regras do projeto do Passo 3. Não reporte OnPush, control flow (`@if`/`*ngIf`), signals vs. RxJS fora do contexto de `subscribe()`, `strict`, `any`, standalone, lazy loading, pastas `core/`/`shared/` ou sufixos de arquivo como regra. Esses temas podem ser bons conselhos, mas não fazem parte do escopo, e misturá-los tira a confiança do relatório. Se você notar um problema sério fora do escopo, cite-o numa linha em "Fora do escopo", sem severidade.

Mantenha a separação no relatório: achados do guia citam a seção do guia; achados das regras do projeto citam a regra do projeto. Nunca apresente uma regra do projeto como se fosse do guia.

O guia é um conjunto de recomendações, não de requisitos. Escreva os achados como recomendações ("o guia recomenda…"), não como erros.

## Regras de interpretação

Estas regras evitam os falsos positivos mais comuns.

- **Consistência dentro do arquivo vence o guia.** A seção "When in doubt, prefer consistency" diz que um arquivo não deve misturar convenções. Não recomende mudar um único membro de um arquivo para o estilo do guia se o resto do arquivo segue outro estilo. Recomende o arquivo inteiro ou nada.
- **Sufixos de tipo não são violação.** O guia pede que o nome do arquivo reflita o identificador dentro dele. `UserProfileComponent` em `user-profile.component.ts` respeita a regra, assim como `UserProfile` em `user-profile.ts`. Reporte só quando o nome não bate com a classe (por exemplo, `PaymentFormComponent` em `checkout.component.ts`). Se o projeto mistura as duas convenções, reporte uma vez como inconsistência.
- **Vários componentes num arquivo podem estar certos.** "One concept per file" aceita classes pequenas que formam um só conceito. Reporte só quando as classes não são relacionadas ou o arquivo é grande. Na dúvida, o guia manda preferir arquivos menores: reporte como baixa e explique.
- **`handleKeydown` pode estar certo.** O guia aceita um nome genérico quando o handler é longo e delega para métodos com nomes específicos.
- **`@Input()` sem `readonly` está certo.** A regra de `readonly` vale para `input()`, `model()`, `output()`, queries por sinal e, na API de decorators, só para `@Output` e queries.
- **Regras de julgamento ficam marcadas.** "Avoid overly complex logic in templates", "Keep components and directives focused on presentation" e "Keep lifecycle methods simple" não têm critério exato. Mostre o trecho, explique por que ele parece complexo e marque o achado como "julgamento".
- **Confirme cada achado lendo o código.** Uma busca por texto encontra comentários, strings e código gerado. Abra o arquivo e confirme antes de reportar.
- **Ignore código que não é do projeto:** `node_modules/`, `dist/`, `.angular/`, `coverage/` e arquivos gerados.

## Passo 1: Contexto

1. Encontre a raiz (`angular.json` ou `project.json` do Nx) e o escopo pedido. Se o usuário citou uma pasta ou arquivo, audite só isso, mas leia o resto quando precisar de contexto (por exemplo, para saber o prefixo de seletor do projeto).
2. Leia a versão de `@angular/core` em `package.json`. Ela não muda as regras, mas muda a correção sugerida: `input()`/`output()` existem a partir da v17.1, `model()` a partir da v17.2 e `inject()` a partir da v14. Num projeto que não tem a API, a correção diz que precisa atualizar a versão antes.
3. Descubra o prefixo de seletor: campo `prefix` em `angular.json` e o prefixo mais frequente nos seletores.
4. Descubra a convenção de nome de arquivo dominante (com ou sem sufixo `.component`).
5. Verifique se as dependências estão instaladas (`node_modules/typescript` existe na raiz). O script do Passo 3 precisa delas.

## Passo 2: Verificar as regras

Para cada regra, a tabela mostra o que procurar. As buscas são pontos de partida. Use a ferramenta de busca disponível (Grep, `rg`) e confirme cada resultado lendo o arquivo.

### Naming

| Seção do guia | O que procurar |
|---|---|
| Separate words in file names with hyphens | Arquivos `.ts`, `.html`, `.css`, `.scss` com camelCase, PascalCase ou `_` no nome. |
| Use the same name for a file's tests with `.spec` at the end | Testes com `.test.ts` ou nome diferente do arquivo testado. |
| Match file names to the TypeScript identifier within | Classe principal com nome diferente do arquivo. Arquivos genéricos: `utils.ts`, `helpers.ts`, `common.ts` (com ou sem prefixo de pasta). |
| Use the same file name for a component's TypeScript, template, and styles | `templateUrl`/`styleUrl(s)` que apontam para nomes diferentes do `.ts`. Estilo extra sem palavra que descreve o conteúdo. |

### Project structure

| Seção do guia | O que procurar |
|---|---|
| All the application's code goes in a directory named `src` | Código de UI fora de `src/`. |
| Bootstrap your application in a file named `main.ts` directly inside `src` | `bootstrapApplication`/`bootstrapModule` fora de `src/main.ts`. |
| Group closely related files together in the same directory | Template ou estilo em pasta diferente do `.ts`. Pasta `tests/` ou `__tests__/` com testes de código de outras pastas. |
| Organize your project by feature areas | Pastas por tipo: `components/`, `directives/`, `services/`, `pipes/`, `models/`, `guards/`, `interceptors/`. Pastas com tantos arquivos que ficam difíceis de navegar (conte os arquivos e cite o número). |
| One concept per file | Arquivos com mais de um `@Component`/`@Directive`/`@Injectable`/`@Pipe`. Decida pelas regras de interpretação acima. |

### Dependency injection

| Seção do guia | O que procurar |
|---|---|
| Prefer the `inject` function over constructor parameter injection | `constructor(` com parâmetros `private`/`public`/`protected`/`readonly` ou com `@Inject(...)` em classes Angular. Cite a migração automática: `ng generate @angular/core:inject`. |

### Components and directives

| Seção do guia | O que procurar |
|---|---|
| Choosing component selectors | Seletor de elemento sem hífen. Prefixo diferente do prefixo do projeto. Prefixo `ng` (severidade alta: o guia diz "Never"). |
| Choosing directive selectors | Diretiva sem o prefixo do projeto. Seletor de atributo fora de camelCase (`[mr-tooltip]` em vez de `[mrTooltip]`). |
| Naming component and directive members | Inputs ou outputs com nome de propriedade ou evento do DOM (`click`, `change`, `focus`, `blur`, `submit`, `input`, `title`, `hidden`, `id`, `style`, `value` em elementos que já têm). Inputs/outputs com prefixo (`appValue`). Outputs com prefixo `on` (`onSave`) ou fora de camelCase. Conflito de nome com evento do DOM é severidade alta, porque o evento nativo também dispara o handler. |
| Group Angular-specific properties before methods | Injeções, inputs, outputs ou queries declarados depois de métodos ou espalhados entre eles. |
| Keep components and directives focused on presentation | Validação de formulário, transformação de dados ou regra de negócio dentro do componente que não depende da UI. Sugira o destino: função pura, validator ou serviço. Julgamento. |
| Avoid overly complex logic in templates | Expressões com vários operadores, ternários aninhados, cadeias de chamadas ou cálculos no template. Sugira um `computed()` (ou getter, se o projeto não usa signals). Julgamento. |
| Use `protected` on class members that are only used by a component's template | Membros sem modificador ou `public` usados no template e não usados de fora (busque o nome em outros arquivos antes de reportar). Não se aplica a inputs, outputs e models, que são API pública. |
| Use `readonly` for properties that shouldn't change | `input()`, `input.required()`, `model()`, `output()`, `viewChild()`, `viewChildren()`, `contentChild()`, `contentChildren()`, `@Output()`, `@ViewChild(ren)`, `@ContentChild(ren)` sem `readonly`. |
| Prefer `class` and `style` over `ngClass` and `ngStyle` | `[ngClass]`, `[ngStyle]`, `NgClass` e `NgStyle` em `imports`. |
| Name event handlers for what they _do_, not for the triggering event | Handlers como `handleClick`, `onClick`, `onSubmit`, `onChange`, `clicked`. Aceite nomes genéricos quando o handler delega por tipo de evento. |
| Keep lifecycle methods simple | `ngOnInit`, `ngOnChanges`, `ngAfterViewInit` e outros hooks com lógica longa em vez de chamadas a métodos com nomes claros. Julgamento. |
| Use lifecycle hook interfaces | Classe com `ngOnInit`, `ngOnDestroy`, `ngOnChanges` etc. sem o `implements` correspondente. |

## Passo 3: Verificar as regras do projeto

Estas regras não estão no guia. Elas vêm do time e usam o script `scripts/cdd-complexity.mjs` para ter números exatos.

### Rodar o script

```sh
node <skill>/scripts/cdd-complexity.mjs <raiz-do-projeto> [--config <arquivo>] [--json] [<pasta-ou-arquivo> ...]
```

- Sem caminhos, o script analisa `src/`. Num escopo menor, passe as pastas ou arquivos pedidos (relativos à raiz).
- A configuração padrão é `scripts/cdd.config.json`: limite de 14 pontos por classe, globs ignorados, pesos de cada item e limites de tamanho de componente. Se o projeto tiver um `cdd.config.json` próprio na raiz, passe-o com `--config`.
- O script usa o compilador TypeScript e o type checker do próprio projeto. Assim, `loop` só conta métodos como `map`/`forEach` quando o receptor é de fato um array, `Map` ou `Set`, e `project-coupling` resolve aliases do `tsconfig`. Se o TypeScript não estiver instalado, o script para com erro. Nesse caso, peça ao usuário para instalar as dependências. Não estime os pontos à mão: o objetivo da regra é um número exato.
- Avisos de "type ... is unresolved" indicam chamadas que o script não contou porque o tipo não foi resolvido (por exemplo, `any`). Cite o total de avisos no relatório.
- Use `--json` quando precisar dos detalhes (linhas de cada ponto). A saída em tabela já traz pontos, linhas por item, tipos acoplados, tamanho de classe e template e linhas de `subscribe()`.

### Complexidade cognitiva (CDD)

Cada classe acumula pontos pelos itens da configuração: `if`/`else if`, `case`, ternário, `&&`/`||`, laços e métodos de iteração, `try/catch`, lambdas com corpo em bloco passadas como argumento, e cada tipo do projeto referenciado (contado uma vez por tipo). Código fora de classes aparece como "(file scope)".

- Reporte cada classe acima do limite, com o total e o detalhamento por item. Severidade média.
- Para cada uma, leia o código e sugira reduções ligadas aos itens que mais pesam. Por exemplo: muitos tipos acoplados indicam responsabilidades demais (divida a classe); laços e lambdas com corpo indicam transformação de dados (extraia funções puras); `if` encadeados indicam regra de decisão (extraia ou use um mapa de casos).
- Os pontos não incluem o template. A complexidade do template fica na seção do guia "Avoid overly complex logic in templates".

### Evitar `subscribe()` em componentes e diretivas

O script lista as linhas de `subscribe()` em classes com `@Component` ou `@Directive`. Serviços não entram nesta regra. Leia cada chamada e classifique-a:

| Situação | Severidade | Correção |
|---|---|---|
| `subscribe` dentro de outro `subscribe` | alta | Encadeie com `switchMap`, `concatMap`, `mergeMap` ou `exhaustMap`, conforme a semântica. |
| Stream longo (rota, `valueChanges`, `interval`, store, `fromEvent`) sem `takeUntilDestroyed()`, `async` ou outra finalização | alta | Vazamento de memória. Troque por `toSignal()` ou `async`. Se a assinatura for mesmo necessária, use `takeUntilDestroyed()`. |
| Resultado guardado em campo para o template exibir | média | `toSignal()` ou pipe `async`. Para carregar dados a partir de um parâmetro, considere `rxResource`/`httpResource` se a versão do projeto tiver essas APIs (verifique se ainda são experimentais nessa versão). |
| Estado derivado de outro observable dentro do `subscribe` | média | `computed()` sobre `toSignal()`, ou operadores no `pipe()`. |
| Parâmetro de rota lido com `subscribe` | média | `toSignal(route.paramMap)` ou inputs de rota (`withComponentInputBinding`). |

A regra é "evitar, a menos que seja estritamente necessário". Considere necessário, e liste em "Em conformidade", quando a chamada dispara um efeito colateral imperativo a partir de uma ação do usuário, sem guardar valor para o template, e o stream termina sozinho (por exemplo, `save()` com HTTP num clique), ou quando integra uma API imperativa de terceiros sem alternativa declarativa. Explique o motivo em cada caso.

`toSignal()` e `takeUntilDestroyed()` existem a partir da v16. Numa versão anterior, sugira o pipe `async` ou `takeUntil` com `ngOnDestroy`.

### Evitar componentes muito grandes (smart/dumb)

O script marca componentes com classe ou template acima dos limites de `componentLimits` (padrão: 200 linhas de classe, 150 de template). Considere também grande um componente acima do limite de CDD.

Para cada componente grande, procure a divisão entre:

- **Smart (container):** injeta serviços ou stores, carrega dados, trata rotas e mantém o estado. Tem template curto, que compõe componentes filhos.
- **Dumb (apresentação):** recebe dados por inputs, avisa ações por outputs, não injeta serviços de dados e pode ser reutilizado ou testado sem mocks.

Sinais de oportunidade: o componente injeta serviços de dados e também tem template longo; blocos do template repetidos ou dentro de `@for`/`*ngFor` com corpo grande; seções visuais independentes (cabeçalho, filtros, lista, detalhe, formulário); métodos usados só por uma parte do template.

A sugestão deve ser concreta: nome de cada componente novo, o bloco do template (com linhas) que vai para ele, seus inputs e outputs, e o que fica no container. Severidade média. Se o componente for grande mas já for só apresentação, sem divisão natural, registre como observação e não como achado.

## Passo 4: Severidade

O guia não define severidade. Use esta escala e explique-a no relatório:

- **Alta:** pode causar bug ou conflito real. Prefixo `ng`, input ou output com nome do DOM, propriedade inicializada pelo Angular que o código sobrescreve (sem `readonly`), `subscribe` aninhado, assinatura longa sem finalização.
- **Média:** prejudica a estrutura ou a API pública. Pastas por tipo, vários conceitos num arquivo, lógica fora da UI no componente, membros de template públicos, seletor sem prefixo, arquivo com nome que não bate com a classe, classe acima do limite de CDD, componente grande sem divisão smart/dumb, `subscribe` que guarda ou deriva estado.
- **Baixa:** legibilidade e consistência. `inject()`, ordem de membros, `ngClass`/`ngStyle`, nomes de handlers, lifecycle hooks, `implements` ausente, `readonly` ausente sem reatribuição.

## Passo 5: Relatório

Escreva em português, a menos que o usuário peça outro idioma. Use frases curtas e voz ativa. Use este modelo:

```markdown
# Auditoria do style guide Angular: <projeto ou escopo>

## Resumo

- Angular <versão>. Escopo: <pastas/arquivos>. Prefixo de seletor: `<prefixo>`. Convenção de nomes: <com/sem sufixo>.
- Achados: <n> altos, <n> médios, <n> baixos.
- <Uma ou duas frases sobre os principais padrões, por exemplo "O projeto organiza pastas por tipo e usa injeção pelo construtor em todos os serviços.">

## Achados

### <Seção do guia, em inglês, exatamente como no guia>

Severidade: <alta|média|baixa>. <"Julgamento." quando aplicável>

<Uma frase com o que o guia recomenda e por quê, usando o motivo do próprio guia.>

| Arquivo | Problema | Correção sugerida |
|---|---|---|
| `caminho/arquivo.ts:linha` | <o que está no código> | <mudança concreta, com nome novo ou destino> |

<Repita para cada seção com achados, da maior severidade para a menor.>

## Regras do projeto

Estas regras não fazem parte do style guide.

### Complexidade cognitiva (CDD)

Script: `cdd-complexity.mjs`, TypeScript <versão>, <n> arquivos, limite <n> pontos por classe, config `<arquivo>`. <n> avisos de tipo não resolvido.

| Classe | Pontos | Itens que mais pesam | Redução sugerida |
|---|---|---|---|
| `caminho/arquivo.ts:linha` Nome | <n>/<limite> | <item n (linhas)> | <mudança concreta> |

<Se nenhuma classe passar do limite, diga isso e cite as 3 classes com mais pontos.>

### `subscribe()` em componentes

<Tabela com arquivo:linha, situação, severidade e correção. Liste à parte as chamadas consideradas necessárias, com o motivo.>

### Componentes grandes (smart/dumb)

<Para cada componente: tamanho da classe e do template, e a proposta de divisão com nomes, blocos do template, inputs, outputs e o que fica no container.>

## Em conformidade

<Seções do guia e regras do projeto verificadas sem achados, em uma lista curta. Inclua os casos aceitos pelas regras de interpretação, por exemplo "`seat-map.ts` tem dois componentes, mas formam um só conceito".>

## Fora do escopo

<Opcional. Problemas sérios que não são do guia, uma linha cada.>

## Próximos passos

<Ordem sugerida de correção: altas primeiro; depois mudanças de estrutura (pastas, arquivos), porque mudam caminhos de import; depois o resto. Cite migrações automáticas quando existirem.>
```

Agrupe por seção do guia, não por arquivo. Quando a mesma violação aparece em muitos arquivos (por exemplo, 40 construtores), liste todos na tabela se forem até cerca de 15. Acima disso, liste os 15 mais relevantes e informe o total e o padrão de busca que encontra o resto.

Termine perguntando se o usuário quer aplicar correções e quais.
