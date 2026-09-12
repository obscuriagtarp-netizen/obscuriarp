# ob_manalimit

Sistema compartilhado de excesso sobrenatural da Obscuria.

## Funcionamento

- O gasto de essencia passa primeiro por uma tolerancia temporaria.
- Usos espacados perdem pressao e praticamente nao geram excesso.
- Sequencias prolongadas de habilidades acumulam excesso persistente.
- A partir de 50%, habilidades com custo relevante podem falhar.
- Nos niveis criticos podem ocorrer refluxo, explosao e dano ao personagem.
- Uma ruptura vampirica tambem consome sangue adicional.

O valor e o cooldown de contencao ficam salvos no metadata do personagem. Nao
e necessario criar tabela SQL.

## Contencao por classe

- Bruxa: ritual de 90 segundos, com cooldown de 30 minutos.
- Curandeira: aterramento vital de 90 segundos, com cooldown de 30 minutos.
- Vampiro: 60 segundos e consumo de um `sangue_puma`, com cooldown de 25 minutos.

Use `/conterexcesso` para iniciar e `/excesso` para consultar o estado atual.

## Testes administrativos

- `/setexcesso ID VALOR`
- `/addexcesso ID VALOR`

Exemplo: `/setexcesso 1 95` coloca o ID 1 diretamente na faixa de ruptura.
As chances continuam aleatorias; cada habilidade com custo igual ou superior a
`minimumCostToRoll` faz uma rolagem, respeitando o intervalo configurado.

Todo o balanceamento fica em `config.lua`.
