---
name: angular-architecture-audit
description: Audita uma aplicação Angular existente contra o style guide oficial (angular.dev/style-guide) e regras de arquitetura por feature - standalone, signals, OnPush, fronteiras entre features, componentes focados em apresentação e um conceito por arquivo. Use sempre que o usuário pedir para auditar, revisar, checar conformidade ou avaliar a arquitetura, estrutura de pastas ou qualidade de um projeto Angular, mesmo que não cite "auditoria" ou "style guide". Somente leitura; gera relatório priorizado.
---

# Auditoria de arquitetura Angular

Use esta skill quando o usuário pedir para auditar, revisar ou verificar a conformidade de uma aplicação Angular com o style guide (https://angular.dev/style-guide) e com as regras de arquitetura do projeto.

## Princípios

- A auditoria é somente leitura. Não altere código sem autorização explícita do usuário.
- Cada achado deve citar arquivo e linha, a regra violada e uma correção concreta.
- Não invente violações. Se um padrão não puder ser confirmado no código, marque como "verificar manualmente".
- Confirme cada achado lendo o trecho do arquivo antes de classificá-lo. Buscas por texto geram falsos positivos, como padrões em comentários.
- Responda em português, a menos que o usuário peça outro idioma.

## Passo 1: Inventário do projeto

1. Localize a raiz do projeto (presença de `angular.json` e `package.json`).
2. Leia `package.json` e registre a versão do `@angular/core`. Regras como `inject()`, signals, `input()`/`output()`, control flow nativo e `loadComponent` dependem da versão.
3. Leia `tsconfig.json` e verifique `compilerOptions.strict`.
4. Verifique se a aplicação é standalone: procure `app.config.ts` e a ausência de `app.module.ts`.
5. Liste as pastas de primeiro nível em `src/app/`.

## Passo 2: Estrutura de pastas

- **Pastas de tipo** em qualquer nível de feature: `components/`, `services/`, `models/`, `guards/`, `pipes/`, `directives/`, `interceptors/`, `interfaces/`. Use `Glob` com `src/app/**/components` e os demais nomes. Em `features/` ou `shared/` no topo, é achado alto. Dentro de uma feature, é médio.
- **Organização de topo**: a app deve ter `core/`, `shared/` e `features/` (ou equivalente por domínio). Arquivos de domínio soltos em `app/` são achado médio.
- **Pastas por assunto**: nomes devem descrever o assunto (`seat-map/`, `payment/`), não a tecnologia.
- **Estrutura rasa**: subpastas com um único arquivo, sem necessidade, são achado baixo.

## Passo 3: Fronteiras de dependência

- `shared/` nunca importa de `features/` nem de `core/`.
- Uma feature nunca importa caminhos internos de outra. Deve importar apenas o `index.ts` público.
- Dependências entre features são unidirecionais, sem ciclos.
- `core/` não importa de `features/`.

Comandos úteis:

- Imports que atravessam features por caminho profundo: `Grep` com pattern `from '(\.\./)+features/[a-z-]+/` e revise os resultados que não terminam em `index`.
- Imports de `shared` apontando para `features`: `Grep` em `src/app/shared` com pattern `features/`.
- Ciclos: verifique manualmente os imports entre features.

Cada violação é achado alto.

## Passo 4: Componentes e diretivas

Verifique em cada arquivo `*.component.ts` e `*.directive.ts`:

| Regra | Como detectar | Severidade |
|---|---|---|
| Standalone | Angular 19 ou superior: `standalone: false` explícito. Versões anteriores: `standalone: true` ausente. Em ambos os casos, `imports` ausente em componente que usa outros componentes | alta |
| NgModule | `@NgModule` em qualquer arquivo, sem justificativa documentada | alta |
| OnPush | ausência de `changeDetection: ChangeDetectionStrategy.OnPush` | média |
| `inject()` | `constructor(private ...)` ou `constructor(private readonly ...)` | baixa |
| Host bindings | `@HostBinding` ou `@HostListener` (preferir `host: {}`) | baixa |
| ngClass/ngStyle | `[ngClass]` ou `[ngStyle]` nos templates | baixa |
| Decoradores de input/output | `@Input`/`@Output` em versões com `input()`/`output()` disponíveis | baixa |
| Controle de fluxo | `*ngIf`, `*ngFor`, `*ngSwitch` em Angular 17 ou superior | baixa |
| `@for` sem track | `@for` sem `track` | alta |
| Membros de template | propriedades usadas só no HTML marcadas como `public` em vez de `protected` | baixa |
| Nomes de seletor | prefixo inconsistente ou seletor fora de kebab-case | baixa |

### Foco na apresentação (style guide: Keep components and directives focused on presentation)

Código dentro de componentes e diretivas deve, em geral, se relacionar com a UI exibida. Código que faz sentido por si só, desacoplado da UI, deve ser extraído para outros arquivos.

Sinais de que um componente acumula lógica que não é de apresentação:

- **Regras de validação** definidas inline no componente (ex.: `validarCpf`, regex de e-mail, algoritmo de dígito verificador). Deve virar validator em `shared/validation/` ou função pura em arquivo próprio. Severidade média.
- **Transformações de dados**: `map`, `reduce`, `filter` ou formatação de DTO dentro de métodos do componente, como cálculo de total, agrupamento de sessões por data ou conversão de resposta da API. Deve ir para função pura, `*.utils.ts`, store ou serviço. Severidade média.
- **Regra de negócio**: cálculo de preço, taxa de serviço, cupom, expiração de reserva ou decisão de fluxo dentro do componente. Deve ir para store, serviço ou modelo. Severidade alta quando a regra for de domínio, média quando for apenas formatação.
- **Métodos longos**: componente com métodos que não tocam template, signals ou inputs/outputs e que contam com várias linhas. Severidade baixa a média.
- **Acesso direto a dados**: `subscribe` com lógica de transformação dentro, em vez de delegar ao serviço ou store.

Como verificar: liste os métodos de cada componente e pergunte, para cada um, se ele depende do estado da tela, de inputs, de outputs ou do template. Se não depender, é candidato a extração. Use `Grep` com `output_mode: "content"` em padrões como `reduce\(|\.map\(|\.filter\(|subscribe\(` dentro de arquivos `*.component.ts` para localizar os trechos.

A correção sugerida deve sempre nomear o destino (função pura, validator, util, store ou serviço) e indicar se o código pode ser testado isoladamente.

## Passo 5: Um conceito por arquivo (style guide: One concept per file)

Prefira arquivos focados em um único conceito. Para classes do Angular, normalmente isso significa um componente, diretiva ou serviço por arquivo. É aceitável mais de um componente ou diretiva no mesmo arquivo quando as classes são pequenas e fazem parte de um único conceito. Na dúvida, adote a abordagem que leva a arquivos menores.

Como verificar:

- Conte classes exportadas por arquivo: `Grep` com pattern `^export (default )?(abstract )?class` em `output_mode: "count"` ou `"files_with_matches"` e confirme os arquivos com mais de uma ocorrência.
- Conte `@Component`, `@Directive`, `@Injectable` por arquivo da mesma forma.

Classificação:

- **Dois ou mais componentes/diretivas/serviços não relacionados no mesmo arquivo**: achado médio. Sugerir um arquivo por classe.
- **Componente pai com subcomponentes pequenos e coesos no mesmo arquivo** (ex.: `seat-map` com `seat` interno e ambos usados só ali): aceitável. Registre como observação, não como achado.
- **Arquivo com um componente e muitas funções utilitárias ou tipos não relacionados**: achado baixo. Sugerir extração para `*.utils.ts` ou `*.model.ts`.
- **Arquivo com mais de cerca de 300 a 400 linhas**: achado baixo, indicando possível divisão. Em caso de dúvida, recomende a divisão.

Ao recomendar divisão, indique os nomes dos novos arquivos seguindo a convenção de sufixos (`.component.ts`, `.service.ts`, `.store.ts`, `.model.ts`, `.utils.ts`, `.validator.ts`).

## Passo 6: Estado e serviços

- **Chamadas HTTP** (`HttpClient`) devem estar apenas em `data-access/` ou em serviços de feature. Componentes com `http.get`/`http.post` são achado alto.
- **Signals**: estado local deve preferir `signal()`/`computed()`. Uso excessivo de `BehaviorSubject` para estado de tela é achado baixo.
- **Stores de fluxo**: estado de fluxo com vários passos deve ser provido na rota (`providers` na rota), não como singleton `providedIn: 'root'`. Achado médio.
- **Escrita de signal fora do store**: componentes escrevendo diretamente em signals de outro domínio são achado médio.
- **Subscriptions**: `subscribe()` sem `takeUntilDestroyed()` ou sem `async` pipe / `toSignal()` é achado médio.

## Passo 7: Rotas

- Rotas de feature devem usar `loadComponent` ou `loadChildren`. Imports estáticos de componentes de feature em `app.routes.ts` são achado alto.
- Guards devem ser funções (`CanActivateFn`), não classes, em Angular 15 ou superior.
- Rotas de fluxo devem validar pré-requisitos com guard (ex.: não acessar pagamento sem assento).

## Passo 8: Nomenclatura e arquivos

- Nomes de arquivo em kebab-case com sufixo de tipo: `.component.ts`, `.service.ts`, `.store.ts`, `.guard.ts`, `.model.ts`, `.pipe.ts`, `.directive.ts`, `.interceptor.ts`, `.token.ts`, `.routes.ts`, `.utils.ts`, `.validator.ts`.
- Nomes de classe em PascalCase com o sufixo correspondente (`MovieService`, não `Movies`).

## Passo 9: Tipagem e qualidade

- `strict: true` é obrigatório. Ausência é achado alto.
- Uso de `any` explícito: `Grep` com pattern `:\s*any\b|<any>|as any`. Cada ocorrência confirmada é achado médio.
- `// @ts-ignore` ou `// @ts-expect-error` sem justificativa é achado médio.
- Testes: serviços, stores, guards e funções extraídas da UI devem ter `*.spec.ts`. Ausência em regras de negócio é achado médio.

## Passo 10: Estilos e tema

- Cores, espaçamentos e tipografia devem vir de tokens. Valor fixo repetido em vários componentes é achado baixo.
- Estilos globais apenas no arquivo global ou em `styles/`, não em componentes.

## Passo 11: Relatório

1. **Resumo**: versão do Angular, total de achados por severidade e nota geral de conformidade (alta, média ou baixa), com justificativa de uma frase.
2. **Achados críticos e altos**, em tabela: severidade, arquivo:linha, regra violada, correção sugerida.
3. **Achados médios e baixos**, agrupados por regra. Liste as ocorrências dentro de cada grupo, sem repetir a explicação.
4. **Observações aceitáveis**, como subcomponentes coesos no mesmo arquivo.
5. **Itens para verificar manualmente**, com a dúvida explicada.
6. **Plano de correção priorizado**: fronteiras entre features, depois standalone e NgModule, depois lógica fora da UI e um conceito por arquivo, depois OnPush e estado, por último nomenclatura e estilo.
7. Pergunte se o usuário quer que as correções sejam aplicadas e em qual ordem.

Referência oficial: https://angular.dev/style-guide