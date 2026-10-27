# Organização e construção de fases

A organização segue responsabilidades, com cenas e scripts específicos juntos.
Ela permite trabalhar por componente sem separar artificialmente todos os scripts
de todas as cenas. Use nomes em inglês e snake_case para arquivos novos.

## Onde encontrar cada parte

```text
res://
├── assets/                  # Arte e ícones; pacotes mantêm suas licenças
├── gameplay/
│   ├── player/              # player.tscn e player.gd
│   ├── camera/              # camera.tscn e camera.gd
│   ├── npc/
│   │   └── dialogues/       # Conteúdo de diálogo específico do NPC
│   └── objects/
│       ├── door/
│       ├── lever/
│       ├── collectible/     # Somente script por enquanto
│       └── dialogue_trigger/
├── scenes/
│   ├── levels/              # Fases completas, inclusive a demo de interação
│   └── prototypes/          # Exemplos de interação e cena de introdução vazia
├── systems/
│   ├── progress/            # GameState
│   ├── save/                # SaveManager
│   ├── input/               # Dispositivo ativo e ícones do Input Map
│   ├── dialogue/
│   │   └── data/            # Classes DialogueData e DialogueLine
│   └── interaction/
│       ├── requirements/   # Condições reutilizáveis
│       └── effects/        # Consequências reutilizáveis
├── ui/
│   ├── main_menu/
│   ├── pause_menu/
│   ├── dialogue/
│   └── interaction_prompt/
├── tests/
└── docs/
```

As imagens soltas do jogador e do NPC ficam em assets/sprites/player e
assets/sprites/npc. Os pacotes existentes de sprites e tiles mantêm a estrutura
do autor e os arquivos de licença. O ícone geral continua na raiz do projeto.

## Como montar uma fase

1. Para uma fase nova, crie scenes/levels/level_01/level_01.tscn com raiz Node2D.
   Guarde os recursos exclusivos dessa fase na mesma pasta, em subpastas apenas
   quando houver conteúdo que justifique a divisão.
2. Instancie gameplay/player/player.tscn e gameplay/camera/camera.tscn. Mantenha
   somente um jogador no grupo Player. A câmera existente encontra esse grupo.
3. Monte o terreno usando TileMapLayer e colisões. Posicione o jogador em um
   ponto livre, sem sobreposição com a colisão do cenário.
4. Instancie objetos de gameplay/objects conforme o puzzle. As cenas de porta e
   alavanca já têm área de interação e PromptAnchor; o jogador já tem Interactor
   e InteractionPrompt.
5. Instancie ui/pause_menu/pause_menu.tscn. Para fases com conversas, adicione
   ui/dialogue/dialogue_ui.tscn e configure os diálogos do NPC ou gatilho.
6. Execute a fase com F6. Para iniciar por ela usando F5 e o menu, configure
   first_level_path no Inspector de ui/main_menu/main_menu.tscn com o caminho
   res:// da nova cena. F5 continua iniciando pelo menu principal.

As fases test_level.tscn e interaction_demo.tscn continuam diretamente em
scenes/levels. Seus caminhos foram preservados porque os saves armazenam o
caminho da cena. Não mova ou renomeie uma fase já distribuída sem planejar a
compatibilidade dos saves antigos.

## Onde colocar arquivos novos

| Conteúdo | Destino |
|---|---|
| Objeto utilizado em várias fases | gameplay/objects/nome_do_objeto/ |
| Cena e script de um personagem | gameplay/nome_do_personagem/ |
| Conteúdo específico de um NPC | Dentro da pasta do NPC; diálogos em dialogues/ |
| Conteúdo exclusivo de uma fase | Dentro da pasta dessa fase |
| Regra compartilhada de gameplay | systems/, no sistema correspondente |
| Condição ou consequência de interação | systems/interaction/requirements ou effects |
| Tela ou elemento de interface | ui/nome_do_componente/ |
| Arte, fonte ou som compartilhado | assets/, em uma pasta criada quando necessário |
| Experimento que ainda não é uma fase | scenes/prototypes/ |
| Teste automatizado | tests/ |

Evite criar pastas vazias antecipadamente ou uma nova camada de gerenciadores
somente para organizar arquivos. Quando um componente passa a ser usado em
várias fases, mova-o para gameplay em vez de manter cópias independentes.

## Interações e persistência

Em um Interactable, configure requirements e effects no Inspector. Todos os
requisitos precisam passar; failure_message informa o motivo do bloqueio.
show_when_locked controla se um objeto bloqueado ainda oferece indicador.

Na porta e na alavanca, persistent_id identifica a instância e state_flag aponta
para seu estado persistente. O SetFlagEffect deve escrever essa mesma state_flag.
Cada instância independente precisa de ID próprio. Use IDs estáveis como
level_01/door_001; não derive IDs do nome, posição ou caminho do nó.

Consulte [interações](interacoes.md) para portas com chave e alavancas, e
[salvamento](salvamento.md) para restauração, rollback e testes isolados.

## Ao mover arquivos

Prefira mover pelo painel FileSystem da Godot, que atualiza dependências.
Mantenha os arquivos .gd.uid junto dos scripts e preserve as configurações de
importação das imagens. Revise caminhos literais em load/preload, autoloads,
testes e documentação mesmo quando a cena possui um UID.

A reorganização atual preservou classes, UIDs, hierarquias das cenas, IDs de
progresso e dados de save. Os autoloads e o menu usam caminhos res:// explícitos
para que a inicialização não dependa de um cache de UIDs de outra máquina.

## Como verificar

Na raiz do projeto, com Godot 4.7.2:

```text
godot --headless --editor --path . --import --quit
godot --headless --path . res://tests/runner.tscn
godot --headless --path . res://tests/interaction_runner.tscn
godot --headless --path . --quit-after 10
godot --headless --path . --quit-after 10 res://scenes/levels/test_level.tscn
godot --headless --path . --quit-after 10 res://scenes/levels/interaction_demo.tscn
```

Os testes usam saves isolados; testes manuais pelo menu Salvar usam o slot normal
do jogo. Não apague saves para verificar a organização de pastas.

Validação desta reorganização em 25/10/2026, Windows, Godot 4.7.2:
importação final sem erros ou avisos; suíte de interação com 51 verificações e
zero falhas; suíte de salvamento com 159 verificações e zero falhas, incluindo
caminhos das fases existentes em saves v1 e v2. Menu, fase original e demo
iniciaram em headless por 10 frames com saída 0. As mensagens [SAVE] de erro
da suíte são esperadas nas falhas simuladas. Controles físicos, navegação visual
e montagem manual no editor continuam exigindo verificação manual.
