import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  ArrowDownLeft, ArrowUpRight, Building2, Check, ChevronRight, CircleDollarSign,
  CreditCard, Eye, EyeOff, FileText, Landmark, LoaderCircle, RefreshCw, Search,
  Send, ShieldAlert, UserRound, WalletCards, X,
} from 'lucide-react'

type Transaction = {
  trans_id: string
  title: string
  amount: number
  trans_type: 'deposit' | 'withdraw'
  receiver: string
  issuer: string
  message: string
  time: number
}

type Account = {
  id: string
  type: string
  name: string
  frozen: boolean | number
  restricted?: boolean
  amount: number
  cash?: number
  transactions: Transaction[]
}

type CreditTransaction = {
  id: string
  type: 'charge' | 'payment' | 'interest' | 'refund'
  amount: number
  merchant: string
  description: string
  createdAt: number
}

type CreditState = {
  score: number
  limit: number
  used: number
  available: number
  totalDue: number
  interest: number
  dueAt?: number
  daysUntilDue?: number
  overdueDays: number
  blocked: boolean
  cycleDays: number
  blockAfterDays: number
  dailyInterestPercent: number
  history: CreditTransaction[]
}

type View = 'overview' | 'statement' | 'credit'
type Action = 'deposit' | 'withdraw' | 'transfer'

const preview = new URLSearchParams(window.location.search).get('preview') === '1'
const money = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 })
const date = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'short', year: 'numeric' })

const mockAccounts: Account[] = [
  { id: 'TH910YTS', type: 'Pessoal', name: 'Lz Dv_', frozen: false, amount: 256490, cash: 8500, transactions: [
    { trans_id: '1', title: 'Salário', amount: 7500, trans_type: 'deposit', receiver: 'Lz Dv_', issuer: 'Obscuria', message: 'Pagamento recebido', time: Math.floor(Date.now() / 1000) - 3600 },
    { trans_id: '2', title: 'Compra', amount: 3200, trans_type: 'withdraw', receiver: 'Loja 24/7', issuer: 'Lz Dv_', message: 'Pagamento realizado', time: Math.floor(Date.now() / 1000) - 86400 },
  ] },
  { id: 'mechanic', type: 'Empresarial', name: 'Automotiva Akuma', frozen: false, amount: 184200, transactions: [] },
]

const mockCredit: CreditState = {
  score: 728, limit: 35000, used: 7850, available: 27150, totalDue: 7850, interest: 250,
  dueAt: Math.floor(Date.now() / 1000) + 259200, daysUntilDue: 3, overdueDays: 0, blocked: false,
  cycleDays: 7, blockAfterDays: 10, dailyInterestPercent: 1,
  history: [
    { id: 'c1', type: 'charge', amount: 4600, merchant: 'Concessionária Central', description: 'Compra no cartão', createdAt: Math.floor(Date.now() / 1000) - 3200 },
    { id: 'c2', type: 'charge', amount: 3000, merchant: 'Loja 24/7', description: 'Compra no cartão', createdAt: Math.floor(Date.now() / 1000) - 86400 },
    { id: 'c3', type: 'interest', amount: 250, merchant: 'Obscuria Bank', description: 'Juros de atraso', createdAt: Math.floor(Date.now() / 1000) - 172800 },
  ],
}

function requestId() {
  return typeof crypto.randomUUID === 'function'
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}-${Math.random().toString(36).slice(2)}`
}

async function nui<T>(action: string, payload: Record<string, unknown> = {}): Promise<T> {
  if (preview) {
    await new Promise((resolve) => setTimeout(resolve, 250))
    if (action === 'creditState') return { ok: true, data: mockCredit } as T
    if (action === 'creditPay') return { ok: true, data: { paid: Number(payload.amount), state: { ...mockCredit, totalDue: 0, used: 0, available: mockCredit.limit } } } as T
    return mockAccounts as T
  }
  const response = await fetch(`https://Renewed-Banking/${action}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(payload),
  })
  return response.json() as Promise<T>
}

function formatMoney(value: number) { return money.format(Math.floor(Number(value) || 0)) }
function formatDate(value?: number) { return value ? date.format(new Date(value * 1000)) : 'Sem vencimento' }

export default function App() {
  const [visible, setVisible] = useState(preview)
  const [loading, setLoading] = useState(!preview)
  const [accounts, setAccounts] = useState<Account[]>(preview ? mockAccounts : [])
  const [selectedId, setSelectedId] = useState(preview ? mockAccounts[0].id : '')
  const [view, setView] = useState<View>('overview')
  const [atm, setAtm] = useState(false)
  const [search, setSearch] = useState('')
  const [action, setAction] = useState<Action | null>(null)
  const [amount, setAmount] = useState('')
  const [comment, setComment] = useState('')
  const [target, setTarget] = useState('')
  const [busy, setBusy] = useState(false)
  const [toast, setToast] = useState('')
  const [credit, setCredit] = useState<CreditState | null>(preview ? mockCredit : null)
  const [creditPayment, setCreditPayment] = useState('')
  const [balanceVisible, setBalanceVisible] = useState(true)

  const selected = accounts.find((account) => account.id === selectedId) || accounts[0]
  const filteredAccounts = accounts.filter((account) => `${account.name} ${account.id}`.toLowerCase().includes(search.toLowerCase()))

  const loadCredit = useCallback(async () => {
    const response = await nui<{ ok: boolean; data?: CreditState; error?: string }>('creditState')
    if (response?.ok && response.data) setCredit(response.data)
    else if (response?.error) setToast(response.error)
  }, [])

  const close = useCallback(() => {
    setVisible(false)
    setAction(null)
    if (!preview) void nui('closeInterface')
  }, [])

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const data = event.data || {}
      if (data.action === 'setVisible') {
        const nextAccounts = Array.isArray(data.accounts) ? data.accounts : []
        setAccounts(nextAccounts)
        setSelectedId(nextAccounts[0]?.id || '')
        setAtm(data.atm === true)
        setLoading(data.loading === true)
        setVisible(data.status === true)
        if (data.status === true) void loadCredit()
      } else if (data.action === 'setLoading') setLoading(data.status === true)
      else if (data.action === 'notify') setToast(String(data.status || 'Operação não concluída.'))
    }
    const onKey = (event: KeyboardEvent) => { if (event.key === 'Escape' && visible) close() }
    window.addEventListener('message', onMessage)
    window.addEventListener('keydown', onKey)
    return () => { window.removeEventListener('message', onMessage); window.removeEventListener('keydown', onKey) }
  }, [close, loadCredit, visible])

  useEffect(() => {
    if (!toast) return
    const timer = window.setTimeout(() => setToast(''), 3800)
    return () => window.clearTimeout(timer)
  }, [toast])

  async function submitAction() {
    if (!selected || !action || busy) return
    const value = Number(amount)
    if (!Number.isInteger(value) || value < 1) return setToast('Informe um valor inteiro válido.')
    if (action === 'transfer' && !target.trim()) return setToast('Informe a conta de destino.')
    setBusy(true)
    const response = await nui<Account[] | false>(action, { fromAccount: selected.id, amount: value, comment: comment.trim(), stateid: target.trim() })
    setBusy(false)
    if (!response || !Array.isArray(response)) return setToast('A operação não foi concluída.')
    setAccounts(response)
    setAction(null)
    setAmount('')
    setComment('')
    setTarget('')
    setToast('Operação realizada com sucesso.')
  }

  async function payInvoice() {
    if (!credit || credit.totalDue < 1 || busy) return
    const value = creditPayment ? Number(creditPayment) : credit.totalDue
    if (!Number.isInteger(value) || value < 1 || value > credit.totalDue) return setToast('Informe um valor válido para a fatura.')
    setBusy(true)
    const response = await nui<{ ok: boolean; data?: { paid: number; state: CreditState }; error?: string }>('creditPay', { amount: value, requestId: requestId() })
    setBusy(false)
    if (!response.ok || !response.data) return setToast(response.error || 'Não foi possível pagar a fatura.')
    setCredit(response.data.state)
    const refreshedAccounts = await nui<Account[] | false>('refreshAccounts')
    if (Array.isArray(refreshedAccounts)) setAccounts(refreshedAccounts)
    setCreditPayment('')
    setToast(`Pagamento de ${formatMoney(response.data.paid)} confirmado.`)
  }

  if (!visible) return null

  return (
    <main className="bank-overlay">
      <section className="bank-shell">
        {loading && <div className="loading"><img src="./eye.png" alt="" /><LoaderCircle className="spin" size={26} /><span>Carregando suas contas</span></div>}
        <aside className="sidebar">
          <header className="brand"><img src="./eye.png" alt="Obscuria" /><div><small>OBSCURIA</small><strong>Bank</strong></div></header>
          <div className="account-search"><Search size={16} /><input value={search} placeholder="Buscar conta" onChange={(event) => setSearch(event.target.value)} /></div>
          <small className="section-label">SUAS CONTAS</small>
          <nav className="account-list">
            {filteredAccounts.map((account) => (
              <button type="button" key={account.id} className={account.id === selected?.id ? 'active' : ''} onClick={() => setSelectedId(account.id)}>
                <span>{account.type.toLowerCase().includes('org') || account.type.toLowerCase().includes('empresa') ? <Building2 size={18} /> : <UserRound size={18} />}</span>
                <div><strong>{account.name}</strong><small>{account.id}</small></div><ChevronRight size={16} />
              </button>
            ))}
          </nav>
          <footer><ShieldAlert size={15} /><span>Movimentações protegidas e auditadas.</span></footer>
        </aside>

        <section className="workspace">
          <header className="topbar">
            <div><small>{atm ? 'CAIXA ELETRÔNICO' : 'AGÊNCIA OBSCURIA'}</small><h1>{selected?.name || 'Sua conta'}</h1></div>
            <nav>
              <button className={view === 'overview' ? 'active' : ''} onClick={() => setView('overview')}><Landmark size={17} /> Visão geral</button>
              <button className={view === 'statement' ? 'active' : ''} onClick={() => setView('statement')}><FileText size={17} /> Extrato</button>
              <button className={view === 'credit' ? 'active' : ''} onClick={() => setView('credit')}><CreditCard size={17} /> Cartão</button>
            </nav>
            <button className="close" title="Fechar" onClick={close}><X size={19} /></button>
          </header>

          {selected && view === 'overview' && <Overview account={selected} atm={atm} visible={balanceVisible} onToggle={() => setBalanceVisible((value) => !value)} onAction={setAction} />}
          {selected && view === 'statement' && <Statement account={selected} />}
          {view === 'credit' && credit && <Credit credit={credit} bankBalance={accounts[0]?.amount || 0} payment={creditPayment} busy={busy} onPayment={setCreditPayment} onPay={payInvoice} onRefresh={loadCredit} />}
          {view === 'credit' && !credit && <div className="empty"><CreditCard size={32} /><strong>Cartão indisponível</strong><span>O serviço de crédito não respondeu.</span><button onClick={loadCredit}>Tentar novamente</button></div>}
        </section>

        {action && selected && (
          <div className="modal-backdrop" onMouseDown={(event) => event.target === event.currentTarget && setAction(null)}>
            <section className="action-modal">
              <button className="modal-close" title="Fechar" onClick={() => setAction(null)}><X size={18} /></button>
              <span className="modal-icon">{action === 'deposit' ? <ArrowDownLeft size={24} /> : action === 'withdraw' ? <ArrowUpRight size={24} /> : <Send size={24} />}</span>
              <small>{selected.name}</small><h2>{action === 'deposit' ? 'Depositar' : action === 'withdraw' ? 'Sacar' : 'Transferir'}</h2>
              <label>Valor<div className="money-field"><span>R$</span><input autoFocus inputMode="numeric" value={amount} placeholder="0" onChange={(event) => setAmount(event.target.value.replace(/\D/g, ''))} /></div></label>
              {action === 'transfer' && <label>Conta de destino<input value={target} placeholder="CitizenID ou conta" onChange={(event) => setTarget(event.target.value)} /></label>}
              <label>Descrição <em>opcional</em><input value={comment} maxLength={100} placeholder="Descrição da movimentação" onChange={(event) => setComment(event.target.value)} /></label>
              <button className="primary" disabled={busy} onClick={submitAction}>{busy ? <LoaderCircle className="spin" size={17} /> : <Check size={17} />} Confirmar</button>
            </section>
          </div>
        )}
        {toast && <div className="toast">{toast}</div>}
      </section>
    </main>
  )
}

function Overview({ account, atm, visible, onToggle, onAction }: { account: Account; atm: boolean; visible: boolean; onToggle: () => void; onAction: (action: Action) => void }) {
  const frozen = account.frozen === true || account.frozen === 1
  const disabled = frozen || account.restricted === true
  return (
    <div className="view overview">
      {account.restricted && <div className="blocked-banner"><ShieldAlert size={20} /><div><strong>Conta bancária bloqueada</strong><span>A fatura está há mais de 10 dias vencida. Depósitos e pagamento da fatura permanecem disponíveis.</span></div></div>}
      <section className="balance-panel">
        <header><span><Landmark size={17} /> Saldo disponível</span><button title={visible ? 'Ocultar saldo' : 'Mostrar saldo'} onClick={onToggle}>{visible ? <Eye size={18} /> : <EyeOff size={18} />}</button></header>
        <strong>{visible ? formatMoney(account.amount) : '••••••••'}</strong>
        <small>Conta {account.id}</small>
      </section>
      <section className="actions">
        {!atm && <button onClick={() => onAction('deposit')}><span><ArrowDownLeft size={20} /></span><b>Depositar</b><small>Adicionar dinheiro à conta</small></button>}
        <button disabled={disabled} onClick={() => onAction('withdraw')}><span><ArrowUpRight size={20} /></span><b>Sacar</b><small>Retirar saldo da conta</small></button>
        <button disabled={disabled} onClick={() => onAction('transfer')}><span><Send size={20} /></span><b>Transferir</b><small>Enviar para outra conta</small></button>
      </section>
      <section className="recent-panel"><header><div><small>ATIVIDADE</small><h2>Últimas movimentações</h2></div><FileText size={19} /></header><TransactionList transactions={account.transactions.slice(0, 6)} /></section>
    </div>
  )
}

function Statement({ account }: { account: Account }) {
  const [filter, setFilter] = useState<'all' | 'deposit' | 'withdraw'>('all')
  const transactions = useMemo(() => filter === 'all' ? account.transactions : account.transactions.filter((item) => item.trans_type === filter), [account.transactions, filter])
  return <div className="view statement"><header className="view-title"><div><small>MOVIMENTAÇÕES</small><h2>Extrato da conta</h2><p>Acompanhe entradas, saídas e identificadores.</p></div><span>{account.id}</span></header><div className="filters"><button className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>Todos</button><button className={filter === 'deposit' ? 'active' : ''} onClick={() => setFilter('deposit')}>Entradas</button><button className={filter === 'withdraw' ? 'active' : ''} onClick={() => setFilter('withdraw')}>Saídas</button></div><section className="statement-panel"><TransactionList transactions={transactions} detailed /></section></div>
}

function TransactionList({ transactions, detailed = false }: { transactions: Transaction[]; detailed?: boolean }) {
  if (!transactions.length) return <div className="empty compact"><FileText size={27} /><strong>Nenhuma movimentação</strong><span>Os lançamentos desta conta aparecerão aqui.</span></div>
  return <div className="transaction-list">{transactions.map((item) => { const incoming = item.trans_type === 'deposit'; return <article key={item.trans_id}><span className={incoming ? 'incoming' : 'outgoing'}>{incoming ? <ArrowDownLeft size={18} /> : <ArrowUpRight size={18} />}</span><div><strong>{item.title}</strong><small>{incoming ? item.issuer : item.receiver} · {formatDate(item.time)}</small>{detailed && <p>{item.message || 'Sem descrição'} · {item.trans_id}</p>}</div><b className={incoming ? 'incoming' : ''}>{incoming ? '+' : '-'} {formatMoney(item.amount)}</b></article> })}</div>
}

function Credit({ credit, bankBalance, payment, busy, onPayment, onPay, onRefresh }: { credit: CreditState; bankBalance: number; payment: string; busy: boolean; onPayment: (value: string) => void; onPay: () => void; onRefresh: () => void }) {
  const usage = credit.limit ? Math.min(100, Math.round(credit.used / credit.limit * 100)) : 0
  return <div className="view credit-view">
    {credit.blocked && <div className="blocked-banner danger"><ShieldAlert size={20} /><div><strong>Conta negativada</strong><span>O atraso ultrapassou {credit.blockAfterDays} dias. Pague a fatura para liberar banco, Pix e cartão.</span></div></div>}
    <div className="credit-grid">
      <section className={`physical-card ${credit.blocked ? 'disabled' : ''}`}><header><img src="./eye.png" alt="" /><span>{credit.blocked ? 'BLOQUEADO' : 'OBSCURIA'}</span></header><small>Limite disponível</small><strong>{formatMoney(credit.available)}</strong><div><i style={{ width: `${usage}%` }} /></div><footer><span>Usado {formatMoney(credit.used)}</span><span>Total {formatMoney(credit.limit)}</span></footer></section>
      <section className="invoice"><header><div><small>FATURA ATUAL</small><strong>{formatMoney(credit.totalDue)}</strong></div><button title="Atualizar" onClick={onRefresh}><RefreshCw size={17} /></button></header><p className={credit.overdueDays > 0 ? 'overdue' : ''}>{credit.dueAt ? credit.overdueDays > 0 ? `Vencida há ${credit.overdueDays} dia(s)` : `Vence ${formatDate(credit.dueAt)}` : 'Sem fatura aberta'}</p>{credit.interest > 0 && <small className="interest">Juros acumulados: {formatMoney(credit.interest)} ({credit.dailyInterestPercent}% ao dia)</small>}{credit.totalDue > 0 ? <div className="pay-box"><label>Valor do pagamento<div><span>R$</span><input inputMode="numeric" value={payment} placeholder={String(credit.totalDue)} onChange={(event) => onPayment(event.target.value.replace(/\D/g, ''))} /></div></label><small>Saldo bancário: {formatMoney(bankBalance)}</small><button className="primary" disabled={busy} onClick={onPay}>{busy ? <LoaderCircle className="spin" size={17} /> : <Check size={17} />} Pagar fatura</button></div> : <div className="paid"><Check size={17} /> Fatura em dia</div>}</section>
    </div>
    <section className="score"><header><div><small>ANÁLISE FINANCEIRA</small><h2>Score e limite</h2></div><strong>{credit.score}<small>/1000</small></strong></header><div><i style={{ width: `${credit.score / 10}%` }} /></div><p>Calculado pelo saldo bancário, volume de movimentações e histórico de pagamento. A fatura vence a cada {credit.cycleDays} dias.</p></section>
    <section className="credit-history"><header><div><small>CARTÃO</small><h2>Lançamentos recentes</h2></div><WalletCards size={19} /></header>{credit.history.length ? credit.history.map((item) => { const paymentItem = item.type === 'payment' || item.type === 'refund'; return <article key={item.id}><span className={paymentItem ? 'payment' : item.type === 'interest' ? 'interest' : ''}>{item.type === 'charge' ? <CreditCard size={17} /> : item.type === 'interest' ? <CircleDollarSign size={17} /> : <ArrowDownLeft size={17} />}</span><div><strong>{item.type === 'payment' ? 'Pagamento de fatura' : item.type === 'interest' ? 'Juros' : item.type === 'refund' ? 'Estorno' : item.merchant}</strong><small>{item.description} · {formatDate(item.createdAt)}</small></div><b className={paymentItem ? 'payment' : ''}>{paymentItem ? '-' : '+'} {formatMoney(item.amount)}</b></article> }) : <div className="empty compact"><CreditCard size={26} /><strong>Nenhum lançamento</strong></div>}</section>
  </div>
}

declare global { interface Window { invokeNative?: (...args: unknown[]) => unknown } }
