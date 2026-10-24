# 🎮 Consciência Negra | O Jogo

**Uma jornada de conhecimento, cultura e representatividade.**

![Status](https://img.shields.io/badge/Status-Em%20desenvolvimento-yellow)
![Godot](https://img.shields.io/badge/Engine-Godot%204-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/Linguagem-GDScript-478CBF)
![Plataforma](https://img.shields.io/badge/Plataforma-PC-green)

---

## 📖 Sobre o projeto

Este projeto consiste no desenvolvimento colaborativo de um **jogo de plataforma 2D**, criado em comemoração ao **Dia da Consciência Negra, celebrado em 20 de novembro**.

A proposta é unir entretenimento e aprendizado em uma experiência interativa que valorize a história, a cultura, as contribuições e as personalidades negras.

O jogo está sendo desenvolvido por estudantes, utilizando a **Godot Engine**, como uma oportunidade de colocar em prática conhecimentos de programação, game design, arte digital e trabalho em equipe.

> **Mais do que jogar, queremos criar uma experiência que desperte curiosidade, reflexão e conhecimento.**

## 🕹️ Sobre o jogo

O projeto está em fase de desenvolvimento. Sua estrutura inicial é baseada em um jogo de plataforma 2D, com movimentação, exploração e sistemas que permitirão incorporar desafios e elementos narrativos.

A história, os personagens, os objetivos e as fases serão definidos e aprimorados ao longo do desenvolvimento.

### ⚙️ Funcionalidades implementadas

- **Movimentação 2D:** deslocamento horizontal com aceleração, desaceleração e controle aéreo.
- **Sistema de pulo:** mecânicas de salto e ajustes para proporcionar maior fluidez.
- **Câmera dinâmica:** acompanhamento suave do jogador.
- **Gerenciamento de estados:** estrutura para controlar coletáveis, eventos e informações do jogo.
- **Sistema de salvamento:** persistência de dados utilizando JSON.
- **Menu principal:** interface de entrada e navegação.
- **Menu de pausa:** possibilidade de interromper e retomar a partida.

O funcionamento, os testes e as limitações do sistema estão na [documentação de salvamento e restauração](docs/salvamento.md).

### 🚧 Em desenvolvimento

As próximas funcionalidades serão definidas de acordo com o planejamento da equipe. Entre as possibilidades estão:

- Desenvolvimento das fases e dos desafios.
- Integração de diálogos e narrativa.
- Criação de personagens e animações.
- Implementação de elementos históricos e culturais.
- Adição de efeitos sonoros e trilha musical.
- Aprimoramento da interface e da experiência do jogador.

---

## 🛠️ Tecnologias utilizadas

| Tecnologia | Utilização |
|---|---|
| **Godot Engine 4** | Desenvolvimento do jogo |
| **GDScript** | Programação das mecânicas e sistemas |
| **Git** | Controle de versões |
| **GitHub** | Colaboração e gerenciamento do código |
| **JSON** | Armazenamento dos dados de salvamento |

---

## 🚀 Como executar o projeto

### Pré-requisitos

- Godot Engine 4, preferencialmente na mesma versão utilizada pela equipe.
- Git ou GitHub Desktop, caso deseje clonar o repositório.

### Instalação

**1. Clone o repositório**

Utilize o GitHub Desktop ou execute:

```bash
git clone URL_DO_REPOSITORIO
```

**2. Abra a Godot Engine**

No Gerenciador de Projetos, clique em **Importar**.

**3. Selecione o projeto**

Localize a pasta clonada e selecione o arquivo `project.godot`.

**4. Execute o jogo**

Após a importação dos recursos, pressione **F6** para executar a cena atual ou **F5** para iniciar o projeto pela cena principal configurada.

---

## 🤝 Desenvolvimento colaborativo

Este jogo é desenvolvido coletivamente. Para manter a organização, utilizamos Git e GitHub, permitindo que diferentes integrantes trabalhem em funcionalidades independentes.

### Fluxo de contribuição

1. Atualize sua cópia local da branch `main`.
2. Crie uma branch para a funcionalidade que será desenvolvida.
3. Implemente e teste suas alterações na Godot.
4. Registre as modificações por meio de commits.
5. Envie sua branch para o GitHub.
6. Abra um **Pull Request** para revisão e integração.

### 🌿 Padrão de branches

Utilizamos nomes descritivos para identificar o propósito de cada branch:

```text
main
├── feat/player
├── feat/dialogue
├── feat/level-01
├── feat/ui
└── fix/save-system
```

### 📝 Padrão de commits

Adotamos o padrão **Conventional Commits**, com descrições em português brasileiro.

| Prefixo | Finalidade |
|---|---|
| `feat:` | Nova funcionalidade |
| `fix:` | Correção de erros |
| `refactor:` | Reestruturação de código |
| `docs:` | Atualização de documentação |
| `style:` | Alterações de formatação |
| `chore:` | Tarefas de manutenção |

Exemplos:

```text
feat: implementa sistema de diálogos
fix: corrige erro ao carregar posição do jogador
refactor: reorganiza lógica de movimentação
docs: atualiza instruções de instalação
```

**Boas práticas:**

- Evite modificar os mesmos arquivos simultaneamente sem combinar com a equipe.
- Teste suas alterações antes de enviá-las.
- Utilize nomes claros para branches e commits.
- Não envie arquivos temporários ou caches da Godot.
- Mantenha a branch `main` em condições de execução.

---

## 👥 Equipe

Projeto desenvolvido por estudantes da **EEEP Jeová Costa Lima**, com colaboração nas áreas de:

- **Game Design e Roteiro:** planejamento da experiência, narrativa, mecânicas e conteúdos.
- **Programação:** desenvolvimento e integração dos sistemas.
- **Arte e Design:** identidade visual, personagens, cenários e interfaces.
- **Áudio:** trilha sonora e efeitos sonoros.
- **Testes:** identificação de problemas e avaliação da experiência.

A identificação dos integrantes e suas contribuições será adicionada conforme a organização da equipe.

---

## 📌 Estado do projeto

**Em desenvolvimento — versão inicial.**

O projeto ainda está sujeito a mudanças em suas mecânicas, identidade visual, narrativa e estrutura.

Este README será atualizado conforme novas funcionalidades forem implementadas.

---

<p align="center">
  <strong>Desenvolvido com Godot Engine e trabalho em equipe.</strong>
  <br>
  <em>Um jogo para explorar, aprender e valorizar histórias.</em>
</p>
