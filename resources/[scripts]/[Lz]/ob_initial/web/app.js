const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'ob_initial';

const app = document.getElementById('app');
const background = document.getElementById('background');
const content = document.getElementById('content');
const character = document.getElementById('character');
const pageSheet = document.getElementById('pageSheet');
const eyebrow = document.getElementById('eyebrow');
const title = document.getElementById('title');
const dialogue = document.getElementById('dialogue');
const speaker = document.getElementById('speaker');
const slideModule = document.getElementById('slideModule');
const choices = document.getElementById('choices');
const previousButton = document.getElementById('previousButton');
const nextButton = document.getElementById('nextButton');
const closeButton = document.getElementById('closeButton');
const progressDots = document.getElementById('progressDots');
const modeLabel = document.getElementById('modeLabel');

const state = {
    open: false,
    mode: 'tutorial',
    slides: [],
    totalPages: 0,
    index: 0,
    selections: {},
    transitioning: false,
};

let transitionTimer;

const previewSlides = [
    {
        id: 'welcome',
        type: 'welcome',
        eyebrow: 'ANTES DE COMEÇARMOS',
        title: 'Seja bem-vindo à Obscuria',
        text: 'Eu sou Lucien. Antes de você cruzar estas portas, preciso lhe mostrar como este mundo respira.',
        speaker: 'Lucien',
        background: 'assets/backgrounds/academy-entry.png',
        character: 'assets/characters/vampire-guide.png',
        characterSide: 'left',
        topics: [
            { title: 'Classes', text: 'Bruxas, Vampiros, Curandeiras e Humanos encontram caminhos diferentes dentro da mesma cidade.' },
            { title: 'Lideranças', text: 'Cada grupo possui vozes, regras e responsabilidades próprias. Reconhecê-las faz parte da sua história.' },
            { title: 'Poderes', text: 'Habilidades sobrenaturais têm propósito, custo e consequência. Saber quando não usá-las também é poder.' },
        ],
        noteTitle: 'Sobre os Humanos',
        note: 'Humanos não possuem poderes sobrenaturais. Ainda assim, preparo, tecnologia, alianças e versatilidade fazem deles uma escolha longe de ser inferior.',
    },
    {
        id: 'classes',
        type: 'classes',
        eyebrow: 'LIÇÃO I',
        title: 'Escolha o seu caminho',
        text: 'As três naturezas sobrenaturais oferecem forças muito diferentes, e nenhuma delas existe sem consequência.',
        speaker: 'Lucien',
        background: 'assets/backgrounds/academy-entry.png',
        characterSide: 'left',
        classTabs: [
            {
                id: 'vampire', label: 'Vampiro', color: '#b83a4e',
                tabImage: 'assets/characters/lucien-present.png', character: 'assets/characters/lucien-present.png',
                epithet: 'Predadores entre luz e escuridão',
                summary: 'Imortais moldados pela magia, Vampiros unem força, velocidade e domínio mental. Sua conexão com as trevas permite controlar sombras, mudar de forma e sobreviver onde outros cairiam.',
                strengths: ['Força e velocidade sobre-humanas', 'Metamorfose e mobilidade aérea', 'Controle mental e drenagem vital'],
                weaknessTitle: 'A Fome Eterna',
                weakness: 'Todo esse poder exige essência vital. Sem se alimentar, o Vampiro perde força, controle e lucidez; quanto mais cede à fome, mais difícil se torna satisfazê-la sem ser consumido por ela.',
            },
            {
                id: 'healer', label: 'Curandeira', color: '#4f9f72',
                tabImage: 'assets/characters/class-healer.png', character: 'assets/characters/class-healer.png',
                epithet: 'Guardiãs do equilíbrio vital',
                summary: 'Curandeiras restauram corpo e espírito, interrompem ferimentos e preservam a tênue fronteira entre vida e morte. Seu poder floresce quando elas e o ambiente permanecem em harmonia.',
                strengths: ['Cura e regeneração profundas', 'Suporte, serenidade e voo', 'Proteção da vida e do equilíbrio'],
                weaknessTitle: 'O Custo da Cura',
                weakness: 'Curar em excesso cobra a vitalidade da própria Curandeira. Exaustão emocional, esforço contínuo e ambientes corrompidos enfraquecem seus dons e podem fazê-la adoecer ou envelhecer antes do tempo.',
            },
            {
                id: 'witch', label: 'Bruxa', color: '#8662b7',
                tabImage: 'assets/characters/class-witch.png', character: 'assets/characters/class-witch.png',
                epithet: 'Mestras do conhecimento arcano',
                summary: 'Bruxas dominam feitiços, encantamentos e forças elementais. Sua maior vantagem é a versatilidade: conhecimento e preparo permitem alterar circunstâncias que pareciam inevitáveis.',
                strengths: ['Feitiçaria e encantamentos versáteis', 'Manipulação de forças elementais', 'Percepção e vínculos arcanos'],
                weaknessTitle: 'Os Ecos da Magia',
                weakness: 'Todo feitiço deixa um eco na alma e no mundo. Magias intensas ampliam o desgaste físico e mental, podem escapar ao controle e ainda deixam rastros perceptíveis para quem sabe caçá-los.',
            },
        ],
    },
    {
        id: 'essences',
        type: 'essence',
        eyebrow: 'LIÇÃO II',
        title: 'A energia de cada classe',
        text: 'A essência é a reserva que sustenta manifestações sobrenaturais. Cada natureza possui uma cor, um ritmo e um propósito.',
        speaker: 'Lucien',
        background: 'assets/backgrounds/academy-entry.png',
        character: 'assets/characters/lucien-book.png',
        characterSide: 'right',
        humanNote: 'Humanos não geram nem consomem essência sobrenatural.',
        classTabs: [
            {
                id: 'vampire', label: 'Vampiro', essence: 'Essência Carmesim', color: '#b83a4e', image: 'assets/essence/vampire.png',
                purpose: 'Impulso, metamorfose e domínio',
                description: 'A essência dos Vampiros é intensa e predatória. Ela sustenta movimentos sobre-humanos, mudanças de forma e habilidades de influência.',
                guidance: 'Administrá-la significa escolher entre velocidade, sobrevivência e controle do alvo.',
            },
            {
                id: 'healer', label: 'Curandeira', essence: 'Essência Vital', color: '#4f9f72', image: 'assets/essence/healer.png',
                purpose: 'Cuidado, equilíbrio e mobilidade',
                description: 'A energia das Curandeiras acompanha a vida. Ela alimenta curas, alívio de condições e o voo por meio de asas etéreas.',
                guidance: 'Seu valor está na constância: preservar alguém pode mudar toda uma história.',
            },
            {
                id: 'witch', label: 'Bruxa', essence: 'Essência Arcana', color: '#8662b7', image: 'assets/essence/witch.png',
                purpose: 'Percepção, vínculo e feitiçaria',
                description: 'A essência das Bruxas responde ao conhecimento e à intenção. Ela sustenta dons naturais e a magia canalizada pelo grimório e pela varinha.',
                guidance: 'Usar magia deixa resquícios. Outra Bruxa atenta pode encontrar o caminho que você percorreu.',
            },
        ],
    },
    {
        id: 'powers',
        type: 'powers',
        eyebrow: 'LIÇÃO III',
        title: 'Poderes de classe',
        text: 'Cada habilidade ocupa um papel específico. Passe o cursor sobre um poder para conhecer sua função antes de depender dele.',
        speaker: 'Lucien',
        background: 'assets/backgrounds/academy-entry.png',
        character: 'assets/characters/lucien-present.png',
        characterSide: 'left',
        classTabs: [
            {
                id: 'vampire', label: 'Vampiro', color: '#b83a4e', image: 'assets/essence/vampire.png',
                tabImage: 'assets/characters/lucien-present.png', character: 'assets/characters/lucien-present.png',
                powers: [
                    { label: 'Passo Sombrio', icon: 'assets/powers/vampire/icons/passo-sombrio.png', description: 'Velocidade sobre-humana, salto ampliado e deslocamento envolto em sombras.' },
                    { label: 'Forma de Morcego', icon: 'assets/powers/vampire/icons/forma-morcego.png', description: 'Assume uma forma alada pequena para voar e escapar sem atacar.' },
                    { label: 'Hipnose', icon: 'assets/powers/vampire/icons/hipnose.png', description: 'Projeta uma onda mental que paralisa e confunde o primeiro alvo atingido.' },
                    { label: 'Abraço da Noite', icon: 'assets/powers/vampire/icons/abraco-da-noite.png', description: 'Drena a energia vital de um alvo próximo para restaurar vida e essência.' },
                ],
            },
            {
                id: 'healer', label: 'Curandeira', color: '#4f9f72', image: 'assets/essence/healer.png',
                tabImage: 'assets/characters/class-healer.png', character: 'assets/characters/class-healer.png',
                powers: [
                    { label: 'Voo', icon: 'assets/powers/healer/icons/voo.png', description: 'Manifesta asas etéreas e permite explorar os céus livremente.' },
                    { label: 'Cura Vital', icon: 'assets/powers/healer/icons/cura-vital.png', description: 'Restaura gradualmente os próprios ferimentos ou os de outro ser.' },
                    { label: 'Serenidade', icon: 'assets/powers/healer/icons/serenidade.png', description: 'Dissipa estresse, medo, ansiedade e exaustão do alvo.' },
                    { label: 'Estancar Sangramento', icon: 'assets/powers/healer/icons/estancar-sangramento.png', description: 'Interrompe hemorragias por meio de regeneração acelerada.' },
                ],
            },
            {
                id: 'witch', label: 'Bruxa', color: '#8662b7', image: 'assets/essence/witch.png',
                tabImage: 'assets/characters/class-witch.png', character: 'assets/characters/class-witch.png',
                powers: [
                    { label: 'Familiar', icon: 'assets/powers/witch/icons/familiar.png', description: 'Assume a forma de um gato preto, pequena, discreta e incapaz de combater.' },
                    { label: 'Sentido Arcano', icon: 'assets/powers/witch/icons/sentido-arcano.png', description: 'Revela resquícios de essência e sinais recentes de atividade sobrenatural.' },
                    { label: 'Elo Arcano', icon: 'assets/powers/witch/icons/elo-arcano.png', description: 'Canaliza energia para recuperar a própria essência ou a de um aliado.' },
                    { label: 'Névoa das Bruxas', icon: 'assets/powers/witch/icons/nevoa-das-bruxas.png', description: 'Invoca uma névoa densa para ocultar fugas e o uso de feitiços.' },
                ],
            },
        ],
    },
    {
        id: 'society', type: 'society', eyebrow: 'LIÇÃO IV', title: 'Viver entre os outros',
        text: 'Obscuria não é formada apenas por poderes. Reputação, alianças e respeito às lideranças determinam quais portas permanecerão abertas para você.',
        speaker: 'Lucien', background: 'assets/backgrounds/academy-entry.png',
        character: 'assets/characters/lucien-present.png', characterSide: 'right',
        representatives: [
            { label: 'Vampiros', role: 'Casas, pactos e domínio', color: '#b83a4e', image: 'assets/characters/lucien-present.png' },
            { label: 'Curandeiras', role: 'Cuidado e equilíbrio', color: '#4f9f72', image: 'assets/characters/class-healer.png' },
            { label: 'Bruxas', role: 'Tradição e conhecimento', color: '#8662b7', image: 'assets/characters/class-witch.png' },
            { label: 'Humanos', role: 'Ofícios e instituições', color: '#9a7848', image: 'assets/characters/class-human.png' },
        ],
        principles: [
            { index: '01', title: 'Reconheça as lideranças', text: 'Cada grupo possui representantes, regras internas e responsabilidades. Ouvir antes de agir evita conflitos desnecessários.' },
            { index: '02', title: 'Construa alianças', text: 'Nenhuma classe resolve tudo sozinha. Relações bem cuidadas abrem acesso a informação, proteção e oportunidades.' },
            { index: '03', title: 'Aceite as consequências', text: 'Favores, crimes e traições deixam memória. Sua reputação muda a forma como a cidade responde à sua presença.' },
        ],
        noteTitle: 'A cidade observa',
        note: 'Poder impõe presença; postura constrói influência. Escolha com cuidado quem saberá o seu nome.',
    },
    {
        id: 'human_path', type: 'human', eyebrow: 'LIÇÃO V', title: 'O valor de ser Humano',
        text: 'Humanos não canalizam essência e não conjuram poderes. Em troca, seguem um caminho livre de fome, ecos mágicos e custos sobrenaturais.',
        speaker: 'Lucien', background: 'assets/backgrounds/academy-entry.png',
        character: 'assets/characters/class-human.png', characterSide: 'left',
        paths: [
            { index: '01', title: 'Investigação', text: 'Observe padrões, reúna provas e descubra fraquezas antes de enfrentar aquilo que não compreende.' },
            { index: '02', title: 'Tecnologia', text: 'Ferramentas, veículos, sistemas de segurança e equipamentos especiais substituem a força sobrenatural.' },
            { index: '03', title: 'Versatilidade', text: 'Profissões, alianças e preparo permitem ocupar funções que nenhuma criatura consegue manter sem levantar suspeitas.' },
        ],
        advantageTitle: 'Sem essência. Não sem recursos.',
        advantage: 'O Humano vence pela informação, planejamento e liberdade para escolher sua função. É uma classe especialmente forte para investigação, negócios, segurança e histórias de superação.',
        warning: 'Você não terá uma habilidade sobrenatural para corrigir uma decisão ruim. Em compensação, também não carregará a fraqueza que acompanha cada dom.',
    },
    {
        id: 'progression', type: 'progression', eyebrow: 'LIÇÃO VI', title: 'Construa o seu caminho',
        text: 'Seu personagem não nasce pronto. Conhecimento, equipamentos e relações transformam potencial em domínio.',
        speaker: 'Lucien', background: 'assets/backgrounds/academy-entry.png',
        character: 'assets/characters/lucien-book.png', characterSide: 'right',
        steps: [
            { index: '01', title: 'Descubra', text: 'Explore a cidade, conheça pessoas e encontre oportunidades que não aparecem no mapa.' },
            { index: '02', title: 'Aprenda', text: 'Livros de aprendizado liberam feitiços do grimório. Poder sem estudo continuará inacessível.' },
            { index: '03', title: 'Equipe', text: 'Varinhas, acessórios e itens de classe ampliam possibilidades e preparam você para situações específicas.' },
            { index: '04', title: 'Domine', text: 'Pratique, administre recursos e escolha quando revelar suas capacidades. Experiência vale mais que pressa.' },
        ],
        essentials: [
            { label: 'Livros', text: 'Desbloqueiam novos conhecimentos.' },
            { label: 'Grimório', text: 'Organiza os feitiços da Bruxa.' },
            { label: 'Equipamentos', text: 'Alteram preparo e possibilidades.' },
            { label: 'Reputação', text: 'Muda oportunidades e relações.' },
        ],
    },
    {
        id: 'first_steps', type: 'journey', eyebrow: 'LIÇÃO VII', title: 'Seu primeiro passo',
        text: 'Trabalhos constroem sua vida; atividades ilegais colocam tudo em risco. Em Obscuria, até o mesmo roubo se transforma conforme a natureza de quem o executa.',
        speaker: 'Lucien', background: 'assets/backgrounds/academy-entry.png', characterSide: 'left',
        classTabs: [
            {
                id: 'vampire', label: 'Vampiro', color: '#b83a4e', tabImage: 'assets/characters/lucien-present.png',
                role: 'Velocidade, influência e atuação noturna', legalTitle: 'Onde pode prosperar',
                legal: 'Segurança, transporte, investigações noturnas e trabalhos que recompensam presença, mobilidade e resistência.',
                illegalTitle: 'Como viola um sistema',
                illegal: 'Segue circuitos como veias, conduzindo uma linha de sangue até o ponto que força máquinas e cofres a expulsarem o conteúdo.',
                phases: [{ title: 'Acesso', text: 'Percebe o pulso correto da fechadura.' }, { title: 'Cofre', text: 'Conecta os canais de sangue do mecanismo.' }, { title: 'Retirada', text: 'Drena a proteção e libera o dinheiro.' }],
            },
            {
                id: 'healer', label: 'Curandeira', color: '#4f9f72', tabImage: 'assets/characters/class-healer.png',
                role: 'Cuidado, natureza e sustentação do grupo', legalTitle: 'Onde pode prosperar',
                legal: 'Medicina, resgate, botânica e suporte a grupos que dependem de estabilidade, recuperação e deslocamento aéreo.',
                illegalTitle: 'Como viola um sistema',
                illegal: 'Faz raízes percorrerem frestas e mecanismos. Vinhas pressionam travas, envolvem compartimentos e puxam o dinheiro para fora.',
                phases: [{ title: 'Acesso', text: 'Cultiva o trajeto correto entre as travas.' }, { title: 'Cofre', text: 'Memoriza e harmoniza os núcleos vitais.' }, { title: 'Retirada', text: 'Comanda vinhas para recolher o conteúdo.' }],
            },
            {
                id: 'witch', label: 'Bruxa', color: '#8662b7', tabImage: 'assets/characters/class-witch.png',
                role: 'Runas, conhecimento e corrupção arcana', legalTitle: 'Onde pode prosperar',
                legal: 'Pesquisa, investigação sobrenatural, criação de itens e trabalhos que exigem leitura de resíduos mágicos.',
                illegalTitle: 'Como viola um sistema',
                illegal: 'Escreve runas para corromper a segurança. Depois do ritual, canaliza magia à distância para romper o compartimento.',
                phases: [{ title: 'Acesso', text: 'Traça a runa sem abandonar o desenho.' }, { title: 'Cofre', text: 'Escuta e alinha ressonâncias arcanas.' }, { title: 'Retirada', text: 'Rompe o núcleo e espalha o dinheiro.' }],
            },
            {
                id: 'human', label: 'Humano', color: '#9a7848', tabImage: 'assets/characters/class-human.png',
                role: 'Ferramentas, estratégia e discrição', legalTitle: 'Onde pode prosperar',
                legal: 'Pode seguir qualquer profissão comum: mecânica, polícia, negócios, transporte, tecnologia ou investigação.',
                illegalTitle: 'Como viola um sistema',
                illegal: 'Compensa a ausência de magia com hacking, ferramentas de precisão e planejamento. Não consome essência, mas depende do equipamento certo.',
                phases: [{ title: 'Acesso', text: 'Manipula a fechadura com ferramentas.' }, { title: 'Cofre', text: 'Decifra a segurança eletrônica e mecânica.' }, { title: 'Retirada', text: 'Organiza a coleta sem deixar evidências.' }],
            },
        ],
        warning: 'Falhar não encerra necessariamente a tentativa, mas pode consumir recursos, deixar rastros e alertar a polícia. Quanto maior o roubo, mais etapas e consequências existirão.',
        choices: [
            { id: 'review_classes', label: 'Rever as classes', action: 'goto', target: 2 },
            { id: 'begin', label: 'Começar minha jornada', action: 'complete', primary: true },
        ],
    },
];

const previewGuideSlides = [
    {
        id: 'guide_welcome', type: 'guide', eyebrow: 'HOTEL RAVENWOOD', title: 'Em que posso ajudá-lo(a)?',
        text: 'Bem-vindo(a) ao Hotel Ravenwood. Espero que sua viagem até Obscuria tenha sido tranquila.',
        paragraphs: [
            'Meu nome é Edward. Trabalho aqui auxiliando os recém-chegados a encontrarem seu lugar na cidade.',
            'Obscuria pode parecer um pouco diferente à primeira vista, mas garanto que logo você se acostuma.',
        ],
        speaker: 'Edward · Concierge do Hotel Ravenwood', character: 'assets/characters/edward-guide.png', characterSide: 'left',
        choices: [
            { id: 'city', label: 'Quero conhecer a cidade', action: 'goto', target: 2 },
            { id: 'job', label: 'Preciso de um emprego', action: 'goto', target: 3 },
            { id: 'vehicle', label: 'Onde consigo um veículo?', action: 'goto', target: 4 },
            { id: 'tips', label: 'Tem alguma dica para iniciantes?', action: 'goto', target: 5 },
            { id: 'obscuria', label: 'O que é Obscuria?', action: 'goto', target: 6 },
            { id: 'leave', label: 'Nada, obrigado', action: 'goto', target: 7 },
        ],
    },
    {
        id: 'guide_city', type: 'guide', eyebrow: 'ORIENTAÇÃO · A CIDADE', title: 'Conheça Obscuria',
        text: 'Obscuria tem muito a oferecer, e você não vai precisar andar sem rumo.',
        paragraphs: [
            'No seu mapa estão marcados praticamente todos os locais importantes da cidade: comércios, empregos, lojas, oficinas mecânicas, hospital, salões de beleza e diversos outros serviços essenciais.',
            'Além disso, a cidade recebe eventos especiais todas as semanas. Sempre que um evento estiver acontecendo, ele aparecerá destacado no mapa com uma marcação diferente, facilitando encontrá-lo.',
            'Aliás, hoje você chegou em um ótimo dia. Está acontecendo a inauguração do Parque de Diversões. Se ainda não sabe por onde começar sua aventura, eu diria para passar por lá. Além de conhecer outros moradores, você pode aproveitar o evento e sentir como é a vida em Obscuria.',
            'Há mais alguma coisa que gostaria de saber?',
        ],
        speaker: 'Edward', character: 'assets/characters/edward-guide.png', characterSide: 'left',
        choices: [{ id: 'back', label: 'Voltar às opções', action: 'goto', target: 1, primary: true }, { id: 'leave', label: 'Encerrar conversa', action: 'goto', target: 7 }],
    },
    {
        id: 'guide_job', type: 'guide', eyebrow: 'ORIENTAÇÃO · TRABALHO', title: 'Seu primeiro emprego',
        text: 'Todo mundo começa de algum lugar. Se pretende construir uma boa vida em Obscuria, o trabalho é sempre o primeiro passo.',
        paragraphs: [
            'Você pode procurar uma oportunidade na Central de Empregos, que está marcada no seu mapa. Lá encontrará mais de 25 profissões diferentes, cada uma com suas próprias funções e remunerações.',
            'Muitos estabelecimentos também contratam diretamente. Visite o local e converse com o gerente; nunca se sabe quando alguém estará precisando de uma boa pessoa para integrar a equipe.',
            'Com dedicação, logo você estará construindo sua própria história por aqui.',
        ],
        calloutTitle: 'Central de Empregos', callout: 'Consulte o mapa para encontrar as vagas públicas. Estabelecimentos particulares podem contratar diretamente.',
        speaker: 'Edward', character: 'assets/characters/edward-guide.png', characterSide: 'left',
        choices: [{ id: 'back', label: 'Voltar às opções', action: 'goto', target: 1, primary: true }, { id: 'leave', label: 'Encerrar conversa', action: 'goto', target: 7 }],
    },
    {
        id: 'guide_vehicle', type: 'guide', eyebrow: 'ORIENTAÇÃO · TRANSPORTE', title: 'Um começo sobre rodas',
        text: 'Um dos meus papéis aqui no Hotel é garantir que todo recém-chegado tenha como dar seus primeiros passos pela cidade.',
        paragraphs: ['Tenho um veículo reservado em seu nome, pronto para ser retirado.', 'Gostaria de retirar seu primeiro veículo agora?'],
        calloutTitle: 'Veículo de boas-vindas', callout: 'O veículo será registrado em seu nome e enviado à garagem configurada. A retirada é permitida somente uma vez.',
        speaker: 'Edward', character: 'assets/characters/edward-guide.png', characterSide: 'left',
        choices: [{ id: 'claim_vehicle', label: 'Sim, registrar meu veículo', action: 'starterVehicle', target: 8, primary: true }, { id: 'later', label: 'Não, depois eu volto', action: 'goto', target: 1 }],
    },
    {
        id: 'guide_tips', type: 'guide', eyebrow: 'ORIENTAÇÃO · PRIMEIROS PASSOS', title: 'Alguns conselhos', text: 'Algumas, na verdade.',
        bullets: ['Converse com as pessoas.', 'Não tenha medo de fazer perguntas.', 'Trabalhe antes de gastar.', 'Respeite as leis da cidade.', 'Aproveite sua história. Obscuria recompensa quem cria boas memórias.'],
        speaker: 'Edward', character: 'assets/characters/edward-guide.png', characterSide: 'left',
        choices: [{ id: 'back', label: 'Voltar às opções', action: 'goto', target: 1, primary: true }, { id: 'leave', label: 'Encerrar conversa', action: 'goto', target: 7 }],
    },
    {
        id: 'guide_obscuria', type: 'guide', eyebrow: 'ORIENTAÇÃO · A VERDADE', title: 'O que é Obscuria?',
        text: 'Uma cidade como qualquer outra... pelo menos é o que muitos acreditam.',
        paragraphs: ['Alguns moradores juram que coisas impossíveis acontecem por aqui. Outros dizem que são apenas lendas.', 'Seja qual for a verdade, Obscuria sempre muda aqueles que escolhem permanecer.'],
        speaker: 'Edward', character: 'assets/characters/edward-guide.png', characterSide: 'left',
        choices: [{ id: 'back', label: 'Voltar às opções', action: 'goto', target: 1, primary: true }, { id: 'leave', label: 'Encerrar conversa', action: 'goto', target: 7 }],
    },
    {
        id: 'guide_farewell', type: 'guide', eyebrow: 'HOTEL RAVENWOOD', title: 'Até breve',
        text: 'Foi um prazer ajudá-lo(a). As portas do Hotel Ravenwood estarão sempre abertas para você.',
        paragraphs: ['Sempre que acordar e passar por aqui, venha conversar comigo. Posso mantê-lo(a) atualizado(a) sobre o que aconteceu em Obscuria enquanto esteve ausente e avisar sobre novas oportunidades.', 'Tenha um ótimo dia, e seja bem-vindo(a) à sua nova vida em Obscuria.'],
        speaker: 'Edward', character: 'assets/characters/edward-guide.png', characterSide: 'left',
        choices: [{ id: 'close', label: 'Encerrar conversa', action: 'close', primary: true }],
    },
    {
        id: 'guide_vehicle_ready', type: 'guide', eyebrow: 'VEÍCULO REGISTRADO', title: 'As chaves são suas',
        text: 'Pronto. Seu veículo foi registrado e já está aguardando na garagem.',
        paragraphs: ['Cuide bem dele. Uma cidade nova parece bem menor quando você tem como atravessá-la por conta própria.'],
        speaker: 'Edward', character: 'assets/characters/edward-guide.png', characterSide: 'left',
        choices: [{ id: 'back', label: 'Voltar às opções', action: 'goto', target: 1, primary: true }, { id: 'leave', label: 'Encerrar conversa', action: 'goto', target: 7 }],
    },
];

async function post(endpoint, payload = {}) {
    if (typeof GetParentResourceName !== 'function') return { ok: true };

    try {
        const response = await fetch(`https://${resourceName}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload),
        });
        return await response.json();
    } catch (_) {
        return { ok: false };
    }
}

let focusClaimPending = false;
let focusClaimGeneration = 0;

async function claimFocus(generation = focusClaimGeneration) {
    if (!state.open || typeof GetParentResourceName !== 'function' || focusClaimPending) return;
    if (generation !== focusClaimGeneration) return;

    focusClaimPending = true;
    window.focus();
    await post('claimFocus');
    focusClaimPending = false;
}

function scheduleFocusClaims() {
    const generation = ++focusClaimGeneration;
    [0, 80, 250, 700, 1400].forEach((delay) => {
        window.setTimeout(() => claimFocus(generation), delay);
    });
}

function setVisible(visible) {
    state.open = visible;
    app.hidden = !visible;
    app.classList.toggle('is-hidden', !visible);
    app.setAttribute('aria-hidden', visible ? 'false' : 'true');

    if (!visible) {
        focusClaimGeneration += 1;
        window.clearTimeout(transitionTimer);
        state.transitioning = false;
        content.classList.remove('is-changing');
    } else {
        scheduleFocusClaims();
    }
}

let audioContext;

function playUiTone(kind = 'page') {
    try {
        audioContext ||= new (window.AudioContext || window.webkitAudioContext)();
        const now = audioContext.currentTime;
        const oscillator = audioContext.createOscillator();
        const gain = audioContext.createGain();
        const tones = {
            page: [410, 520, 0.09],
            select: [560, 680, 0.07],
            confirm: [440, 760, 0.14],
        };
        const [start, end, duration] = tones[kind] || tones.page;

        oscillator.type = 'sine';
        oscillator.frequency.setValueAtTime(start, now);
        oscillator.frequency.exponentialRampToValueAtTime(end, now + duration);
        gain.gain.setValueAtTime(0.0001, now);
        gain.gain.exponentialRampToValueAtTime(0.022, now + 0.012);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
        oscillator.connect(gain);
        gain.connect(audioContext.destination);
        oscillator.start(now);
        oscillator.stop(now + duration + 0.01);
    } catch (_) {

    }
}

function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function selectedClass(slide) {
    const tabs = Array.isArray(slide.classTabs) ? slide.classTabs : [];
    const selectedId = state.selections[slide.id] || tabs[0]?.id;
    return tabs.find((entry) => entry.id === selectedId) || tabs[0];
}

function renderClassTabs(slide, activeClass) {
    const tabs = element('div', 'class-tabs');
    tabs.classList.toggle('has-four', slide.classTabs.length === 4);

    slide.classTabs.forEach((entry) => {
        const button = element('button', `class-tab${entry.id === activeClass.id ? ' is-active' : ''}`);
        button.type = 'button';
        button.style.setProperty('--tab-color', entry.color || '#7f2f40');
        button.setAttribute('aria-pressed', entry.id === activeClass.id ? 'true' : 'false');

        const label = element('span', '', entry.label);
        const imagePath = entry.tabImage || entry.image;
        if (imagePath) {
            const image = element('img', entry.tabImage ? 'class-tab-portrait' : '');
            image.src = imagePath;
            image.alt = '';
            button.append(image);
        }
        button.append(label);

        button.addEventListener('click', () => {
            state.selections[slide.id] = entry.id;
            playUiTone('select');
            renderSlideModule(slide);
        });
        tabs.appendChild(button);
    });

    slideModule.appendChild(tabs);
}

function renderClasses(slide) {
    const activeClass = selectedClass(slide);
    if (!activeClass) return;

    renderClassTabs(slide, activeClass);

    const detail = element('section', 'class-showcase-detail');
    detail.style.setProperty('--class-color', activeClass.color || '#7f2f40');

    const portraitStage = element('figure', 'class-portrait-stage');
    const portrait = element('img', 'class-portrait');
    portrait.src = activeClass.character;
    portrait.alt = `Representante da classe ${activeClass.label}`;
    portraitStage.appendChild(portrait);

    const copy = element('div', 'class-showcase-copy');
    const heading = element('header', 'class-showcase-heading');
    heading.append(
        element('p', 'class-epithet', activeClass.epithet),
        element('h2', '', activeClass.label),
        element('p', 'class-summary', activeClass.summary),
    );

    const strengths = element('section', 'class-strengths');
    strengths.appendChild(element('h3', '', 'Pontos fortes'));
    const strengthsList = element('ul');
    (activeClass.strengths || []).forEach((strength) => strengthsList.appendChild(element('li', '', strength)));
    strengths.appendChild(strengthsList);

    const weakness = element('section', 'class-weakness');
    weakness.append(
        element('p', 'class-weakness-label', 'Vulnerabilidade'),
        element('h3', '', activeClass.weaknessTitle),
        element('p', '', activeClass.weakness),
    );

    copy.append(heading, strengths, weakness);
    detail.append(portraitStage, copy);
    slideModule.appendChild(detail);
}

function renderWelcome(slide) {
    const topics = element('div', 'intro-topics');
    (slide.topics || []).forEach((topic) => {
        const card = element('section', 'intro-topic');
        card.append(element('h2', '', topic.title), element('p', '', topic.text));
        topics.appendChild(card);
    });
    slideModule.appendChild(topics);

    if (slide.note) {
        const note = element('aside', 'human-note');
        note.append(element('strong', '', slide.noteTitle || 'Nota'), element('span', '', slide.note));
        slideModule.appendChild(note);
    }
}

function renderEssence(slide) {
    const activeClass = selectedClass(slide);
    if (!activeClass) return;

    renderClassTabs(slide, activeClass);

    const detail = element('section', 'essence-detail');
    detail.style.setProperty('--class-color', activeClass.color || '#7f2f40');

    const visual = element('div', 'essence-visual');
    const orb = element('img', 'essence-orb');
    orb.src = activeClass.image;
    orb.alt = activeClass.essence;
    visual.appendChild(orb);

    const copy = element('div', 'essence-copy');
    copy.append(
        element('h2', '', activeClass.essence),
        element('p', 'essence-purpose', activeClass.purpose),
        element('p', 'essence-description', activeClass.description),
        element('p', 'essence-guidance', activeClass.guidance),
    );

    detail.append(visual, copy);
    slideModule.appendChild(detail);
    if (slide.humanNote) slideModule.appendChild(element('p', 'module-footnote', slide.humanNote));
}

function renderPowers(slide) {
    const activeClass = selectedClass(slide);
    if (!activeClass) return;

    renderClassTabs(slide, activeClass);
    const layout = element('div', 'powers-showcase');
    const guide = element('aside', 'power-class-guide');
    guide.style.setProperty('--class-color', activeClass.color || '#7f2f40');

    const guideImage = element('img');
    guideImage.src = activeClass.character || activeClass.tabImage || '';
    guideImage.alt = `Representante da classe ${activeClass.label}`;
    const guideCopy = element('div');
    guideCopy.append(element('span', '', 'Habilidades de'), element('strong', '', activeClass.label));
    guide.append(guideImage, guideCopy);

    const grid = element('div', 'powers-grid');

    (activeClass.powers || []).forEach((power) => {
        const card = element('article', 'power-card');
        card.tabIndex = 0;
        card.style.setProperty('--class-color', activeClass.color || '#7f2f40');
        card.setAttribute('aria-label', `${power.label}: ${power.description}`);

        const frame = element('div', 'power-icon-frame');
        const image = element('img');
        image.src = power.icon;
        image.alt = '';
        frame.appendChild(image);

        const hover = element('div', 'power-hover');
        hover.append(element('strong', '', power.label), element('span', '', power.description));
        card.append(frame, element('h3', '', power.label), hover);
        grid.appendChild(card);
    });

    layout.append(guide, grid);
    slideModule.appendChild(layout);
}

function renderSociety(slide) {
    const representatives = element('div', 'society-representatives');
    (slide.representatives || []).forEach((entry) => {
        const item = element('article', 'society-representative');
        item.style.setProperty('--group-color', entry.color || '#7f2f40');
        const image = element('img');
        image.src = entry.image;
        image.alt = `Representante de ${entry.label}`;
        const copy = element('div');
        copy.append(element('strong', '', entry.label), element('span', '', entry.role));
        item.append(image, copy);
        representatives.appendChild(item);
    });

    const principles = element('div', 'society-principles');
    (slide.principles || []).forEach((entry) => {
        const item = element('article', 'society-principle');
        item.append(
            element('span', 'society-index', entry.index),
            element('h2', '', entry.title),
            element('p', '', entry.text),
        );
        principles.appendChild(item);
    });

    const note = element('aside', 'society-note');
    note.append(element('strong', '', slide.noteTitle), element('span', '', slide.note));
    slideModule.append(representatives, principles, note);
}

function renderHuman(slide) {
    const paths = element('div', 'human-paths');
    (slide.paths || []).forEach((entry) => {
        const item = element('article', 'human-path');
        item.append(
            element('span', 'human-path-index', entry.index),
            element('h2', '', entry.title),
            element('p', '', entry.text),
        );
        paths.appendChild(item);
    });

    const advantage = element('section', 'human-advantage');
    advantage.append(element('h2', '', slide.advantageTitle), element('p', '', slide.advantage));
    const warning = element('p', 'human-warning', slide.warning);
    slideModule.append(paths, advantage, warning);
}

function renderProgression(slide) {
    const timeline = element('ol', 'progression-timeline');
    (slide.steps || []).forEach((entry) => {
        const item = element('li', 'progression-step');
        const index = element('span', 'progression-index');
        index.appendChild(element('span', '', entry.index));
        item.append(
            index,
            element('h2', '', entry.title),
            element('p', '', entry.text),
        );
        timeline.appendChild(item);
    });

    const essentials = element('div', 'progression-essentials');
    (slide.essentials || []).forEach((entry) => {
        const item = element('article', 'progression-essential');
        item.append(element('strong', '', entry.label), element('span', '', entry.text));
        essentials.appendChild(item);
    });
    slideModule.append(timeline, essentials);
}

function renderJourney(slide) {
    const activeClass = selectedClass(slide);
    if (!activeClass) return;

    renderClassTabs(slide, activeClass);
    const detail = element('section', 'journey-detail');
    detail.style.setProperty('--class-color', activeClass.color || '#7f2f40');

    const identity = element('header', 'journey-identity');
    const portrait = element('img');
    portrait.src = activeClass.tabImage;
    portrait.alt = `Representante da classe ${activeClass.label}`;
    const identityCopy = element('div');
    identityCopy.append(element('span', '', 'Perspectiva de'), element('h2', '', activeClass.label), element('p', '', activeClass.role));
    identity.append(portrait, identityCopy);

    const paths = element('div', 'journey-paths');
    const legal = element('article', 'journey-path legal');
    legal.append(element('span', 'journey-path-label', 'Trabalho'), element('h3', '', activeClass.legalTitle), element('p', '', activeClass.legal));
    const illegal = element('article', 'journey-path illegal');
    illegal.append(element('span', 'journey-path-label', 'Ilegal'), element('h3', '', activeClass.illegalTitle), element('p', '', activeClass.illegal));
    paths.append(legal, illegal);

    const phases = element('div', 'robbery-phases');
    (activeClass.phases || []).forEach((phase, index) => {
        const item = element('article', 'robbery-phase');
        item.append(element('span', '', String(index + 1).padStart(2, '0')), element('strong', '', phase.title), element('p', '', phase.text));
        phases.appendChild(item);
    });

    detail.append(identity, paths, phases);
    slideModule.append(detail, element('p', 'journey-warning', slide.warning));
}

function renderGuide(slide) {
    const body = element('div', 'guide-dialogue');

    (slide.paragraphs || []).forEach((paragraph) => {
        body.appendChild(element('p', 'guide-paragraph', paragraph));
    });

    if (Array.isArray(slide.bullets) && slide.bullets.length) {
        const list = element('ul', 'guide-list');
        slide.bullets.forEach((item) => list.appendChild(element('li', '', item)));
        body.appendChild(list);
    }

    if (slide.callout) {
        const callout = element('aside', 'guide-callout');
        if (slide.calloutTitle) callout.appendChild(element('strong', '', slide.calloutTitle));
        callout.appendChild(element('p', '', slide.callout));
        body.appendChild(callout);
    }

    slideModule.appendChild(body);
}

function renderSlideModule(slide) {
    slideModule.replaceChildren();
    if (slide.type === 'welcome') renderWelcome(slide);
    if (slide.type === 'classes') renderClasses(slide);
    if (slide.type === 'essence') renderEssence(slide);
    if (slide.type === 'powers') renderPowers(slide);
    if (slide.type === 'society') renderSociety(slide);
    if (slide.type === 'human') renderHuman(slide);
    if (slide.type === 'progression') renderProgression(slide);
    if (slide.type === 'journey') renderJourney(slide);
    if (slide.type === 'guide') renderGuide(slide);
}

function createChoiceButton(slide, choice) {
    const button = element('button', `choice-button${choice.primary ? ' primary' : ''}`, choice.label || 'Continuar');
    button.type = 'button';
    button.addEventListener('click', async () => {
        await post('choice', { id: choice.id, slideId: slide.id });

        if (choice.action !== 'goto' && choice.action !== 'restart') playUiTone('confirm');
        if (choice.action === 'restart') goTo(0);
        else if (choice.action === 'goto') goTo(Math.max(0, Number(choice.target || 1) - 1));
        else if (choice.action === 'starterVehicle') {
            const buttons = [...choices.querySelectorAll('button')];
            buttons.forEach((entry) => { entry.disabled = true; });
            const originalLabel = button.textContent;
            button.textContent = 'Registrando...';
            const result = await post('starterVehicle');

            if (result?.ok) {
                goTo(Math.max(0, Number(choice.target || 1) - 1));
            } else {
                button.textContent = result?.message || 'Não foi possível registrar agora';
                button.classList.add('is-error');
                window.setTimeout(() => {
                    button.textContent = originalLabel;
                    button.classList.remove('is-error');
                    buttons.forEach((entry) => { entry.disabled = false; });
                }, 3200);
            }
        }
        else if (choice.action === 'openTutorial') await post('openTutorial');
        else if (choice.action === 'close') await closeUi();
        else if (choice.action === 'next') goTo(state.index + 1);
        else {
            const result = await post('complete');
            if (result?.ok === false) return;
            setVisible(false);
        }
    });
    return button;
}

function renderProgress() {
    progressDots.replaceChildren();
    const total = Math.max(state.slides.length, state.totalPages || 0);

    for (let index = 0; index < total; index += 1) {
        const available = index < state.slides.length;
        const dot = element('button', `progress-dot ${available ? 'is-available' : 'is-pending'}${index === state.index ? ' active' : ''}`);
        dot.type = 'button';
        dot.disabled = !available;
        dot.setAttribute('aria-label', available ? `Ir para a aba ${index + 1}` : `Aba ${index + 1} ainda não disponível`);
        if (available) dot.addEventListener('click', () => goTo(index));
        progressDots.appendChild(dot);
    }
}

function renderSlide() {
    const slide = state.slides[state.index];
    if (!slide) return;

    app.dataset.mode = state.mode;
    background.style.backgroundImage = slide.background ? `url("${slide.background}")` : 'none';
    content.classList.toggle('character-right', slide.characterSide === 'right');
    content.classList.toggle('character-left', slide.characterSide !== 'right');
    content.dataset.pageType = slide.type || 'dialogue';

    character.hidden = !slide.character;
    if (slide.character) character.src = slide.character;
    else character.removeAttribute('src');
    character.alt = slide.speaker ? `Retrato de ${slide.speaker}` : 'Guia de Obscuria';
    character.onerror = () => { character.hidden = true; };

    eyebrow.textContent = slide.eyebrow || '';
    title.textContent = slide.title || '';
    dialogue.textContent = slide.text || '';
    speaker.textContent = slide.speaker || '';
    modeLabel.textContent = state.mode === 'guide' ? 'CONVERSA' : 'GUIA INICIAL';

    renderSlideModule(slide);

    choices.replaceChildren();
    const slideChoices = Array.isArray(slide.choices) ? slide.choices : [];
    slideChoices.forEach((choice) => choices.appendChild(createChoiceButton(slide, choice)));

    const guideMode = state.mode === 'guide';
    previousButton.hidden = guideMode;
    previousButton.disabled = state.index === 0;
    nextButton.hidden = guideMode || state.index >= state.slides.length - 1 || slideChoices.length > 0;
    if (guideMode) progressDots.replaceChildren();
    else renderProgress();
}

function goTo(index) {
    if (index < 0 || index >= state.slides.length || index === state.index || state.transitioning) return;
    state.transitioning = true;
    content.classList.add('is-changing');
    playUiTone('page');

    transitionTimer = window.setTimeout(() => {
        state.index = index;

        try {
            renderSlide();
        } catch (error) {
            console.error('[ob_initial] Falha ao renderizar página:', error);
            setVisible(false);
            post('close');
            return;
        }

        window.requestAnimationFrame(() => {
            window.requestAnimationFrame(() => {
                content.classList.remove('is-changing');
                state.transitioning = false;
            });
        });
    }, 110);
}

async function closeUi() {
    await post('close');
    setVisible(false);
}

previousButton.addEventListener('click', () => goTo(state.index - 1));
nextButton.addEventListener('click', () => goTo(state.index + 1));
closeButton.addEventListener('click', closeUi);

window.addEventListener('keydown', (event) => {
    if (!state.open) return;
    if (state.mode !== 'guide' && event.key === 'ArrowLeft') goTo(state.index - 1);
    if (state.mode !== 'guide' && event.key === 'ArrowRight' && !nextButton.hidden) goTo(state.index + 1);
    if (event.key === 'Escape') closeUi();
});

window.addEventListener('pageshow', () => {
    if (state.open) scheduleFocusClaims();
});

document.addEventListener('visibilitychange', () => {
    if (!document.hidden && state.open) scheduleFocusClaims();
});

window.addEventListener('pointerdown', () => {
    if (state.open) claimFocus();
}, { passive: true });

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'close') {
        setVisible(false);
        return;
    }

    if (data.action !== 'open' || !Array.isArray(data.slides) || data.slides.length === 0) return;

    state.mode = data.mode === 'guide' ? 'guide' : 'tutorial';
    state.slides = data.slides;
    state.totalPages = Number(data.totalPages) || data.slides.length;
    state.index = Math.max(0, Math.min(state.slides.length - 1, Number(data.startIndex || 1) - 1));
    state.selections = {};

    try {
        renderSlide();
        setVisible(true);
    } catch (error) {
        console.error('[ob_initial] Falha ao abrir a interface:', error);
        setVisible(false);
        post('close');
    }
});

const previewMode = new URLSearchParams(window.location.search).get('preview');
if (previewMode === '1' || previewMode === 'guide') {
    state.mode = previewMode === 'guide' ? 'guide' : 'tutorial';
    state.slides = state.mode === 'guide' ? previewGuideSlides : previewSlides;
    state.totalPages = state.slides.length;
    state.index = 0;
    renderSlide();
    setVisible(true);
} else {
    setVisible(false);
    post('ready');
}
