# Automotiva Akuma

Recurso de mecânica e customização da Obscuria, preparado para Qbox.

## Dependências

- `qbx_core`
- `ox_lib`
- `ox_inventory`
- `oxmysql`
- `qbx_vehicles` para persistir veículos próprios
- `Renewed-Banking` para receber o valor dos serviços na conta da oficina

## Inicialização

Mantenha as dependências acima iniciadas antes deste recurso e use o nome real da pasta no `server.cfg`:

```cfg
ensure ob_mechanic
```

A tabela `ob_mechanic_pending` é criada automaticamente. Não há SQL manual para importar.

## Configuração

As coordenadas, cargo, preços, conta da sociedade, itens e imagens ficam em `shared/config.lua`.

O cargo padrão é `mechanic`, já cadastrado como **Automotiva Akuma** no `qbx_core`. O acesso à oficina exige serviço ativo. Os itens `repairkit` e `tirerepairkit` também já estão cadastrados no `ox_inventory`.

## Teste rápido

1. Defina o cargo `mechanic` no personagem e entre em serviço.
2. Vá até o marcador da Automotiva Akuma dirigindo um veículo.
3. Pressione `E`, escolha uma alteração e confira o orçamento.
4. Conclua o serviço e guarde o veículo para validar a persistência.
5. Danifique um veículo e valide o reparo pelo menu e pelos dois kits.

Os valores recebidos são enviados para a conta `mechanic` do `Renewed-Banking`. Altere `MechanicConfig.Shop.societyBank` caso a conta tenha outro nome.
