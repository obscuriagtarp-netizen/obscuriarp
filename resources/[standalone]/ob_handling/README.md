# ob_handling

Resource client-side para ajustar veiculos originais sem substituir handling.meta.

## Instalacao

Adicione depois dos resources de veiculos:

    ensure ob_handling

Se a pasta [OB] ja for iniciada por grupo, nenhuma linha adicional e necessaria.

## Configuracao

Edite apenas config.lua. Em multiply, 1.10 aumenta o campo original em 10% e
0.90 reduz em 10%. Em set, o numero informado substitui o campo original.

O Prairie e a primeira configuracao. Para adicionar outro veiculo, copie o bloco,
troque a chave pelo spawn name e ajuste os multiplicadores.

Ao parar ou reiniciar a resource, os veiculos ainda existentes recebem seus valores
anteriores. Isso evita acumular multiplicadores durante testes.

## Exports client-side

    exports.ob_handling:ApplyVehicleHandling(vehicle)
    exports.ob_handling:RestoreVehicleHandling(vehicle)
    exports.ob_handling:RefreshVehicleHandling(vehicle)
