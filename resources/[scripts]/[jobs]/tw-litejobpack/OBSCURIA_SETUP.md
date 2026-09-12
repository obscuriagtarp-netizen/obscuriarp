# tw-litejobpack na Obscuria

O pacote está configurado para usar a camada de compatibilidade QB do `qbx_core`,
`ox_inventory`, `ox_lib` e `oxmysql`.

## Ordem de inicialização

Use esta ordem no `server.cfg`:

```cfg
setr qbx:enablebridge "true"
setr inventory:framework "qbx"

ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure qbx_vehicles
ensure qbx_vehiclekeys
ensure ox_inventory
ensure tw-litejobpack
```

O `tw-litejobpack-stream` contém os props e modelos próprios dos empregos, mas
não é obrigatório para o recurso iniciar. Ele pode permanecer em `[maps]`, desde
que essa categoria seja iniciada antes de `[scripts]`. Sem o stream, os trabalhos
que dependem de props customizados ficam sem o modelo correspondente.

`qbx_vehicles` e `qbx_vehiclekeys` também são integrações opcionais no manifesto
para não impedirem o `tw-litejobpack` de iniciar. Mantenha ambos antes do pacote
na ordem do `server.cfg`; as chaves automáticas só funcionam quando
`qbx_vehiclekeys` está iniciado.

Os veículos temporários usam diretamente os exports de entidade do
`qbx_vehiclekeys`. A chave é concedida apenas quando o jogador está próximo do
veículo e removida ao encerrar o trabalho; nenhuma busca por placa é utilizada.

## Painel administrativo

O painel usa a permissão ACE `tw-litejobpack.admin`. Libere-a para o grupo de
administração da cidade:

```cfg
add_ace group.admin tw-litejobpack.admin allow
```

Não há identificadores pessoais pré-autorizados na configuração. O comando do
painel é `/jobadmin`.

## Empregos e Qbox

`Config.RealJob` permanece como `none`. Assim, os 27 empregos funcionam como
trabalhos temporários e não substituem o emprego principal do personagem no Qbox.
O progresso e os níveis são persistidos pelo próprio pacote.

## ox_inventory

Os corais, peixes, varas, iscas, itens opcionais do detector de metais e a arma
de trabalho `WEAPON_ACIDPACKAGE` foram registrados. As imagens fornecidas pelo
pacote foram copiadas para `ox_inventory/web/images`.

As varas usam `consume = 0`: podem ser usadas pelo inventário sem desaparecer.
Também foi criado o item de compatibilidade `water_bottle`, usado pelas
recompensas opcionais dos empregos.

Após alterar itens ou armas, reinicie o servidor. Reiniciar somente o job não
recarrega o catálogo já carregado pelo `ox_inventory`.

## Interação por alvo

O alvo continua desativado porque `ox_target` não está nesta cópia da base. O
pacote usa normalmente as interações por tecla. Se o recurso for adicionado:

```cfg
ensure ox_target
```

Depois altere `Config.TargetSystem.enabled` para `true` em `shared/config.lua`.

## Recursos opcionais

- Logs de Discord estão desativados até que webhooks próprios sejam definidos.
- Requisitos por horas jogadas continuam desativados; a tabela padrão do pacote
  aponta para vRP e não deve ser usada no Qbox sem indicar a tabela real da cidade.
- Itens do detector de metais estão cadastrados, mas a entrega como item continua
  desligada em `shared/jobs/metaldetector.lua` para preservar a economia original.
