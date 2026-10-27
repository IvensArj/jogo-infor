# Interações condicionais e persistentes

Compatível com a versão local Godot 4.7.2. GameState e SaveManager permanecem
inalterados; o formato de save continua sendo v2, com suporte à leitura de v1.

## Configuração no Inspector

Em um Interactable, adicione Resources ao array **Condições / requirements**:
FlagRequirement, ItemRequirement ou EventRequirement. Todos precisam passar
(AND). Configure failure_message para explicar o primeiro bloqueio.
Uma entrada nula bloqueia; IDs inválidos nunca satisfazem um requisito,
inclusive FlagRequirement com expected_value=false.
Uma flag válida ainda ausente vale false, conforme GameState.get_flag().

Em **Consequências / effects**, adicione SetFlagEffect, CollectItemEffect ou
CompleteEventEffect. Os efeitos executam na ordem do array. Configure os IDs
e, para flags, value. Recursos podem ser compartilhados: não guardam estado
de uma instância do objeto ou do personagem.

show_when_locked=true mantém o objeto selecionável com o motivo do bloqueio;
false o remove dos candidatos enquanto bloqueado. enabled e one_shot continuam
definindo disponibilidade. PromptAnchor, prompt_offset, prioridade, direção,
margem de troca, Input Map e resolução de ícones foram preservados.

## Contrato e extensões

- InteractionRequirement herda Resource e implementa
  is_met(interactor: Node2D) -> bool, sem mutações.
- InteractionEffect herda Resource e implementa is_valid() -> bool (preflight,
  sem mutações) e execute(interactor: Node2D, source: Node2D) -> bool.
- interact() agora retorna bool. false não é sucesso; interaction_performed
  só é emitido quando o retorno é true e o alvo ainda está vivo.
- interacted e _on_interact continuam disponíveis. O hook é executado depois
  dos efeitos e antes de interacted. A implementação antiga do hook que retorna
  void continua compatível; novos comportamentos que podem falhar devem usar
  efeitos com retorno bool.
- interaction_denied informa falhas de requisitos/configuração. Objeto
  indisponível, carga em andamento e reentrância simplesmente retornam false.
- availability_changed notifica o indicador. Requisitos são armazenados em cache
  por personagem e invalidados por progress_changed. Toda tentativa reavalia.
  Ao modificar Resources/arrays ou condições externas durante o jogo, chame
  invalidate_requirements(). Não altere os dicionários do GameState diretamente.
- Subclasses com _ready() devem chamar super._ready().

Os efeitos atuais são idempotentes graças aos métodos existentes de GameState:
repetir uma atribuição não repete a notificação. Recursos duplicados no array
ainda executam na ordem declarada; efeitos personalizados precisam definir sua
própria política de idempotência.

Toda a configuração é validada antes do primeiro efeito. A execução usa uma
cópia do array e bloqueia reentrância. Após cada efeito, verifica personagem,
origem, ancestrais em exclusão e transição. Uma interrupção retorna false sem
anunciar conclusão. Não existe transação genérica: efeitos já aplicados não
são desfeitos se um efeito posterior falhar. Por isso, valide no preflight,
prefira efeitos idempotentes e coloque transições/destruição por último.
Use queue_free(), nunca free() sobre a origem que está executando uma chamada;
a Godot bloqueia essa liberação imediata. Transições devem ser agendadas para
depois da interação, por call_deferred(). Não use await em execute().

## Porta e chave

Instancie gameplay/objects/door/flag_door.tscn. Dê a cada instância um
persistent_id exclusivo e uma state_flag estável. Substitua o requisito de
alavanca por ItemRequirement, item_id="nivel/chave", com mensagem
"Encontre a chave primeiro.". Configure SetFlagEffect com flag_id igual à
state_flag da porta e value=true. A chave deve registrar esse mesmo item_id
usando o coletável existente ou CollectItemEffect. O requisito não consome a chave.

FlagDoor oculta DoorVisual e adia a mudança de disabled da colisão sólida.
A área de interação permanece existente; disponibilidade impede nova seleção.
Não substitua DoorBody por uma Area2D: ele é a barreira física.

## Alavanca persistente

Instancie gameplay/objects/lever/flag_lever.tscn. A cena já contém:

- FlagRequirement: test_level/lever_activated, expected_value=false.
- SetFlagEffect: mesma flag, value=true.
- state_flag: mesma flag; persistent_id: test_level/lever_001.
- one_shot=true e show_when_locked=false.

FlagInteractable centraliza apenas a projeção de uma flag no objeto.
apply_persistent_state() consulta a flag, restaura has_interacted e o visual;
nunca executa efeitos. Reset, carregamento e rollback usam a mesma projeção.
Uma alavanca ativada fica verde e inclinada; deixa de ser selecionável.
Ao duplicar instâncias independentes, ajuste ID, state_flag, requisitos e efeitos.

## IDs

Use a validação existente GameState.is_valid_id(): String não vazia, sem espaços
nas extremidades, tabs ou quebras de linha. Não normalize IDs legados. Prefira
nivel/objeto. persistent_id identifica a instância perante SaveManager;
state_flag identifica seu estado em GameState.flags. Não há segundo registro
de progresso por persistent_id. Configurar uma state_flag inválida faz a
validação de persistência rejeitar o objeto. IDs persistentes duplicados na
mesma cena continuam rejeitados pelo SaveManager.

Flags podem ser compartilhadas deliberadamente entre objetos. A validação
existente não verifica colisões globais entre cenas; mantenha uma convenção de
prefixos. Os IDs novos não colidiam com os IDs encontrados no projeto.

## Demonstração e salvamento

Abra scenes/levels/interaction_demo.tscn e execute com F6. Ela utiliza o jogador,
indicador, pausa e UI de diálogo existentes, sem alterar a fase de testes.
Aproxime-se da porta à direita: ela pede a alavanca. Ative a alavanca à esquerda,
volte à porta e abra. A área sólida tem 180 pixels de altura.

Use Esc/Start, Salvar, Menu principal e Continuar: SaveManager restaura a cena
de demonstração e os estados. Nova partida no menu original continua abrindo
a fase original. Para iniciar uma nova partida na demo, configure temporariamente
first_level_path do menu para res://scenes/levels/interaction_demo.tscn, ou chame
SaveManager.new_game() com esse caminho. Nenhuma configuração manual é necessária
para executar a demo por F6. Salvar manualmente usa o slot normal existente.

## Verificação

Na raiz, substitua godot pelo caminho do executável local:

~~~text
godot --headless --editor --path . --import --quit
godot --headless --path . res://tests/interaction_runner.tscn
godot --headless --path . res://tests/runner.tscn
godot --headless --path . --quit-after 10 res://scenes/levels/interaction_demo.tscn
godot --headless --path . --quit-after 10 res://scenes/levels/test_level.tscn
~~~

A suíte nova usa uma instância de SaveManager com arquivos exclusivos em
user://interaction_tests_<processo>_<tempo>/ e remove somente seus próprios
arquivos. A suíte existente também isola seus saves e compara os arquivos reais.
Consulte o log além do código de saída: um erro GDScript pode interromper um
método sem incrementar o contador de falhas.

Cobertura nova: bloqueio e mensagem, ausência de falso sucesso, AND, IDs,
ordem/preflight/idempotência, cache, reentrância, remoção de origem/personagem,
seleção por direção/prioridade/estabilidade, entradas simuladas E/Y, ícones e
fallback, porta/colisão/visual, save em disco, continuar, reset no mesmo frame
e nova partida.

Ainda requer teste manual: sensação de movimento/passagem, posicionamento visual
com diferentes resoluções, controles físicos/hotplug, diálogos e navegação dos
menus. Nintendo utiliza fallback textual porque os arquivos correspondentes não
estão presentes no projeto. NPC e DialogueTrigger mantêm sua ativação independente.

Validação executada em 25/10/2026, Windows, Godot 4.7.2: importação headless
sem erros; suíte nova com 51 verificações e zero falhas, sem erros de script;
suíte existente com 155 verificações e zero falhas (mensagens de erro de save
esperadas nas falhas simuladas). Demo e fase original iniciaram por 10 frames
headless sem erros, saída 0. git diff --check passou; novos scripts usam TABs.

## Próximas extensões

NPCs ainda usam entrada independente; uma integração futura pode reutilizar Interactable.
