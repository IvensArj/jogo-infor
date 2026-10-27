# Organização do projeto

Cenas e scripts específicos ficam juntos em gameplay/ e ui/. Sistemas compartilhados
ficam em systems/. Fases permanecem em scenes/levels e protótipos em scenes/prototypes.
Arte do jogador e NPC fica em assets/sprites/player e assets/sprites/npc.
Autoloads e recursos usam os caminhos atuais; UIDs dos scripts são preservados.
Não mova fases distribuídas sem migração dos caminhos armazenados nos saves.

Validação: importação headless, tests/runner.tscn e inicialização da fase existente.
