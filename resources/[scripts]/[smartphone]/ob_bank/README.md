# Obscuria Bank

Aplicativo bancário para `qs-smartphone` e motor de cartão de crédito usado pelo servidor.

## Regras do crédito

- A fatura vence sete dias após a abertura do ciclo.
- O juro configurável é aplicado diariamente após o vencimento.
- Com dez dias de atraso, a conta pessoal, o Pix e o cartão são bloqueados.
- Depósitos e pagamento da fatura continuam disponíveis durante o bloqueio.
- O score considera saldo bancário, quantidade e volume de movimentações, faturas pagas e atrasos.
- O limite é recalculado pelas faixas de `Config.Credit.limits`.

As tabelas SQL são criadas automaticamente ao iniciar o resource. O arquivo `sql/install.sql` pode ser usado em instalações manuais.

## Exports de servidor

```lua
local allowed = exports.ob_bank:CanChargeCredit(source, amount)

local charged = exports.ob_bank:ChargeCredit(
    source,
    amount,
    'Nome do estabelecimento',
    'Descrição da compra',
    uniqueTransactionId
)

local response = exports.ob_bank:GetCreditState(source)
local state = response.ok and response.data or nil
local blocked = exports.ob_bank:IsAccountBlocked(source)
local refunded = exports.ob_bank:RefundCredit(source, uniqueTransactionId, 'Motivo do estorno')
```

`uniqueTransactionId` deve identificar uma única tentativa de compra. Reutilizar o mesmo ID torna a cobrança idempotente e evita duplicidade.

## Inicialização

Inicie `ob_bank` depois de `oxmysql`, `qbx_core`, `Renewed-Banking` e `qs-smartphone`. Não há `dependency` no `fxmanifest.lua`, portanto reiniciar o aplicativo não reinicia esses resources.
