# Academia Monitoramento

App do TCC para centralizar alunos, treinos, dietas, avaliações físicas e agenda — agora com
dois tipos de usuário: **personal** (equipe da academia) e **aluno** (acesso próprio e restrito).

## ⚠️ Trade-off importante: envio de WhatsApp

Enviar mensagens automaticamente pelo WhatsApp **sem nenhum toque humano** exige uma conta
comercial aprovada na API oficial (Meta Cloud API ou Twilio) — precisa de CNPJ, verificação do
negócio e aprovação prévia de "template de mensagem", e normalmente é pago. Isso não é viável
configurar num TCC.

O que foi implementado: ao cadastrar um aluno, o app monta a mensagem com e-mail e senha
provisória e **abre o WhatsApp já com o texto pronto** (link `wa.me`) — a personal só precisa
tocar em enviar. Zero configuração externa, funciona hoje.

## Papéis de usuário

### Personal (equipe da academia)
- Acesso completo: todos os alunos, planos, avaliações e agenda são compartilhados entre todos
  os personais (é uma equipe só).
- Aba **Equipe**: lista os personais cadastrados e permite **criar a conta de um(a) novo(a)
  colega** (a senha temporária aparece na tela para você repassar).
- Aba **Perfil**: define os **próprios horários de atendimento** ("Meus horários") — faixas por
  dia da semana, usadas para gerar os horários de 30 em 30 minutos que os alunos veem ao agendar
  — e permite trocar a própria senha (confirmando a atual antes).
- Ao cadastrar um aluno, o app agora também **cria a conta de login dele** (Firebase Auth) com
  uma senha temporária, salva o e-mail no cadastro, e abre o WhatsApp com essas credenciais.

### Aluno
- Login próprio (e-mail + senha temporária recebida por WhatsApp); no primeiro acesso, é
  **obrigado a trocar a senha** antes de usar o app.
- Só enxerga o próprio perfil, as próprias avaliações (gráficos e histórico, somente leitura) e
  os próprios planos (treino/dieta, somente leitura).
- Pode **marcar uma avaliação**: escolhe o personal, uma data (só dias em que aquele personal
  atende) e um horário livre de 30 em 30 minutos (os horários já ocupados não aparecem).
- Não pode editar dados, lançar avaliações ou ver informações de outros alunos — isso é reforçado
  tanto na interface quanto nas regras do Firestore (não é só uma restrição visual).

## Etapa 1: templates reutilizáveis e rastreabilidade (Inteligência de Prescrição)

Primeiro passo para a personal poder avaliar depois a eficiência de cada plano com base nos
resultados reais dos alunos. Em vez de criar uma arquitetura nova do zero, isso foi encaixado na
estrutura que já existe: um `Plan` já é a "atribuição" de um treino/dieta a um aluno (tem
`studentId`, `startDate`, `endDate`) — só ganhou campos novos de rastreabilidade.

**Planos agora nascem sempre de um modelo (fixo)** — não existe mais "criar do zero" na hora de
atribuir a um aluno:

- Nova aba **Modelos**: biblioteca de fichas de treino e dietas reutilizáveis, com objetivo base
  (Hipertrofia, Emagrecimento, etc.) e nível (Iniciante/Intermediário/Avançado). É aqui que a
  personal monta o plano base, sem vincular a nenhum aluno ainda.
- Na tela de atribuir um plano a um aluno (dentro do perfil dele), agora é **obrigatório
  escolher um modelo** da biblioteca primeiro — os exercícios ou o texto da dieta vêm
  pré-preenchidos a partir dele, e a personal ajusta o que for particular daquele aluno
  (repetições, cargas, algum exercício trocado, etc.) antes de salvar. Se não houver nenhum
  modelo daquele tipo ainda, a tela oferece um atalho para criar um na hora.
- Cada plano atribuído a um aluno guarda: `templateId` (de qual modelo veio),
  `objectiveSnapshot` (o objetivo do aluno *no momento* da atribuição, "congelado" mesmo que o
  objetivo dele mude depois) e `initialEvaluationId` (a avaliação física mais próxima da data de
  início — a "foto" inicial). Existe também `closePlanCycle()` no `FirestoreService`, pronto para
  uma próxima etapa preencher o `finalEvaluationId` quando o ciclo terminar.
- Isso ainda **não** calcula nenhuma "eficiência" — é só a modelagem e a captura de dados; a
  lógica de comparar antes/depois fica pra uma próxima etapa, quando tiver dados suficientes
  acumulados pra fazer sentido.

> Nova coleção e regra nova — rode `firebase deploy --only firestore` de novo.

## Estrutura

```
lib/
  models/       Student (+ email/authUid/mustChangePassword), Plan, Evaluation, Appointment
                (+ personalUid), Personal, AvailabilityRange/PersonalAvailability, callbacks.dart
  services/     AuthService, FirestoreService, NotificationService,
                AccountProvisioningService (cria contas sem derrubar a sessão atual),
                WhatsAppService (monta o link wa.me)
  screens/      LoginScreen, HomeShell (personal), StudentsPage, StudentDetailScreen,
                PlanFormScreen, EvaluationFormScreen, AgendaPage, PersonalsPage (Equipe),
                AvailabilityFormScreen, ChangePasswordScreen
  screens/aluno/ AlunoHomeShell, AlunoProfilePage, AlunoEvaluationsPage, AlunoPlansPage,
                AlunoScheduleScreen (agendar avaliação)
  utils/        ..., evaluation_metrics.dart (categorias de gráficos, compartilhado)
firestore.rules   Regras com dois papéis: personal (acesso total) e aluno (só o próprio)
```

> **Atenção:** as regras do Firestore mudaram bastante (papéis personal/aluno). Rode
> `firebase deploy --only firestore` de novo antes de testar.

## Como a criação de contas funciona sem derrubar sua sessão

Se o app chamasse `createUserWithEmailAndPassword` normalmente enquanto você (personal) está
logada, o Firebase trocaria sua sessão pela do usuário recém-criado — te deslogando na hora. Para
evitar isso, `AccountProvisioningService` cria a conta numa **instância secundária e temporária**
do Firebase, que é descartada logo em seguida. Sua sessão principal nunca é tocada.

## Sem autocadastro: como criar a primeira conta (bootstrap)

A tela de login agora só tem **Entrar** — não existe mais cadastro público. Toda conta nova
(personal ou aluno) é criada de dentro do app por quem já está logado. Isso significa que a
**primeira** conta de personal (a "chefe") precisa ser criada manualmente, uma única vez:

1. Firebase Console → **Authentication** → aba Users → **Add user** → informe e-mail e senha.
2. Copie o **UID** gerado para esse usuário.
3. Firebase Console → **Firestore Database** → coleção `personals` → **Add document** → use esse
   UID como ID do documento → adicione os campos `name` (string) e `email` (string, igual ao
   e-mail usado no passo 1).
4. Pronto — essa conta já consegue logar no app como personal e, a partir da aba **Equipe**,
   criar as contas de todos os outros colegas.

## Bug corrigido: aluno travava na troca de senha obrigatória

As regras do Firestore só permitiam que uma **personal** atualizasse o cadastro de um aluno —
inclusive o campo interno `mustChangePassword`. Na prática, quando o aluno trocava a senha, a
gravação que "destrava" essa tela era **rejeitada silenciosamente** pelas regras, e ele voltava
pro loop. Corrigi a regra para permitir que o próprio aluno atualize **somente esse campo** do
próprio cadastro — nada além disso.

> Essa mudança de regras precisa ser publicada de novo: `firebase deploy --only firestore`.

## Aba Perfil (personal) e login simplificado

- **Perfil**: nome/e-mail, link para **Meus horários de atendimento** (antes ficava em Equipe,
  agora só aqui) e **troca de senha** — exige confirmar a senha atual antes da nova
  (reautenticação, exigida pelo Firebase para operações sensíveis).
- **Equipe** ficou só com a lista de personais e o botão de criar um(a) novo(a).
- Login: só "Entrar" + "Esqueci minha senha" (sem cadastro público).

## "Esqueci minha senha" — tela própria (sem "trocar senha" no Perfil)

Removi a troca de senha do Perfil (personal e aluno) e do autocadastro. Agora existe **só um
caminho**: na tela de login, "Esqueci minha senha" abre uma **tela própria** com um campo de
e-mail. Ao enviar, o Firebase manda um e-mail — só chega na caixa de entrada de quem pediu — com
um **link** para definir uma senha nova. Depois de definir lá, a pessoa volta e entra
normalmente com a senha nova.

**Por que um link, e não uma senha pronta no e-mail:** o Firebase (sem um servidor próprio pago)
nunca envia senha em texto puro por e-mail — isso não existe por segurança, em nenhum provedor de
autenticação sério. Gerar uma senha e enviá-la exigiria Cloud Functions com Admin SDK (plano
pago Blaze), o mesmo tipo de limitação do envio automático de WhatsApp. O link de redefinição é o
mecanismo real, gratuito, e alcança o mesmo objetivo final: a pessoa consegue voltar a entrar sem
saber a senha antiga.

### Se o e-mail não estiver chegando, confira nessa ordem:
1. **Caixa de spam/lixo eletrônico** — o mais comum.
2. **Authentication → Sign-in method → Email/Password** precisa estar habilitado no Console.
3. **Project settings → General → Support email** precisa estar preenchido — sem isso o Firebase
   pode falhar ao enviar e-mails de autenticação.
4. **Authentication → Templates → Password reset** — confirme que o template está ativo (vem
   ativo por padrão, mas vale conferir se alguém desativou).
5. O e-mail digitado precisa ser exatamente o mesmo cadastrado na conta (aluno ou personal) — o
   Firebase não avisa se o e-mail não existir (proteção contra descoberta de contas), então a
   tela sempre mostra "e-mail enviado" mesmo se o e-mail não estiver cadastrado. Confirme o
   e-mail certo em Alunos/Equipe antes de testar.

## Corrigido: erro de assertion no dropdown de personal (agendar avaliação)

O `DropdownButtonFormField<Personal>` comparava objetos inteiros — como `Personal` não define
igualdade própria, cada nova emissão do stream criava instâncias "diferentes" mesmo para o mesmo
personal, e o Flutter não achava o item selecionado na lista (erro de assertion). Troquei a
seleção para usar o `uid` (texto) em vez do objeto inteiro, resolvendo de vez.

## Bugs corrigidos (calendário, retroatividade, sino duplicado)

- **Calendário não abria** quando o personal não atendia todos os dias da semana: o
  `showDatePicker` exige que `initialDate` já seja um dia "permitido" pelo `selectableDayPredicate`
  — se hoje não fosse um dia de atendimento, o calendário simplesmente não abria (falha de
  assertion). Agora o app procura automaticamente o primeiro dia válido a partir de hoje.
- **Consultas retroativas**: a Agenda do personal deixava escolher datas de até 1 dia atrás, e
  nem a Agenda nem o agendamento do aluno bloqueavam um horário do dia atual que já tivesse
  passado. Corrigido nos dois lados.
- **Botão "Sair" duplicado**: cada tela de Perfil (personal e aluno) tinha seu próprio botão de
  sair, além do ícone padrão no topo do app. Removi os duplicados — agora "Sair" só existe no
  ícone do AppBar, igual em todas as telas.

## Cancelamento de consultas (personal e aluno) com aviso de 3 horas

Tanto a personal (na Agenda) quanto o aluno (na tela de Agendar, em "Minhas consultas
agendadas") podem cancelar uma avaliação marcada. Cancelamentos com **menos de 3 horas** de
antecedência são bloqueados com um aviso — a ideia é evitar cancelamento de última hora sem
combinar diretamente com a outra pessoa.

## Central de notificações (novo)

Notificação **local** (a que já existia) só funciona no aparelho de quem agendou — não dá pra
"empurrar" um alerta pro celular de outra pessoa sem um servidor push (Firebase Cloud Functions +
FCM, que exige o plano pago Blaze). Isso não é viável configurar aqui.

O que funciona de verdade, sem custo: uma **central de notificações guardada no Firestore**.
Cada personal e cada aluno tem seu próprio sino no topo do app (com contador de não lidas). Nela
aparecem:
- O lembrete de que uma avaliação está próxima (para o aluno e para a personal).
- O lembrete de lançar os dados da avaliação depois (só para a personal).
- O aviso de que uma consulta foi cancelada, e por quem.

Essas notificações são gravadas no momento em que a consulta é marcada/cancelada (com a data em
que "valem" registrada), e aparecem na central assim que esse horário chega — funciona em
qualquer aparelho onde a pessoa logar, diferente da notificação local do sistema.

> Mudança de regras e novo índice — rode `firebase deploy --only firestore` de novo.

## Testando o fluxo novo


1. Crie a conta "chefe" manualmente (passo a passo acima) e faça login com ela.
2. Em **Perfil**, defina seus horários de atendimento.
3. Em **Alunos**, cadastre um aluno com um e-mail válido e um número de WhatsApp de teste — o
   app deve abrir o WhatsApp com a mensagem de acesso pronta.
4. Faça logout e entre com o e-mail/senha temporária do aluno — o app deve pedir para trocar a
   senha e, depois, mostrar a tela do aluno (Perfil/Avaliações/Planos/Agendar).
5. Na aba **Agendar** do aluno, escolha seu personal, uma data válida e um horário — confirme e
   veja o agendamento aparecer na Agenda do personal.

## Configurar o Firestore

1. Console → **Firestore Database** → criar banco (edição Standard, modo produção).
2. Publicar regras:
   ```powershell
   npm install -g firebase-tools
   firebase login
   cd academia-app
   firebase deploy --only firestore
   ```
3. Chaves do app (se ainda não configurou): `flutterfire configure`.

## Notificações locais

`flutter_local_notifications` + `timezone` (fuso `America/Sao_Paulo`). Lembrete 15 min antes de
uma avaliação agendada e outro 45 min depois lembrando de lançar os dados. Funciona de verdade em
Android/iOS; no navegador só dispara com a aba aberta. No Android, já configurei o
`core library desugaring` e as permissões necessárias.

## Executar

```powershell
flutter pub get
flutter run -d chrome        # ou um dispositivo Android/iOS para notificações reais
```

## Próximos passos sugeridos

- Editar/excluir planos e avaliações.
- Aluno poder cancelar a própria consulta futura direto na tela de perfil (hoje só marca).
- Uma central de notificações dentro do próprio app, além dos lembretes do sistema operacional.
- Exportar avaliações em PDF.
