import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  ArrowDownLeft,
  ArrowLeft,
  ArrowUpRight,
  Check,
  ChevronRight,
  Clock3,
  CreditCard,
  Eye,
  EyeOff,
  FileText,
  Heart,
  Home,
  LoaderCircle,
  Plus,
  RefreshCw,
  Search,
  Send,
  ShieldAlert,
  Star,
  Trash2,
  UserRound,
  X,
} from 'lucide-react'
import { bankRequest } from './api'
import type { CreditState, Dashboard, Person, Receipt, Transaction } from './types'

type Screen = 'home' | 'pix' | 'statement' | 'favorites' | 'credit'
type StatementFilter = 'all' | 'in' | 'out'

type PhoneState = {
  visible?: boolean
  activeApp?: string
}

type PhoneBridge = {
  onReady: (listener: () => void) => () => void
  onEvent: (listener: (event: string, data?: unknown) => void) => () => void
  getPhoneState: () => Promise<PhoneState>
}

type PhoneBridgeInstance = {
  bridge: { destroy: () => void }
  api: PhoneBridge
}

const money = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
  minimumFractionDigits: 0,
})

function formatMoney(value: number) {
  return money.format(value).replace('R$', '$')
}

function formatDate(timestamp: number, includeTime = false) {
  const date = new Date(timestamp * 1000)
  return new Intl.DateTimeFormat('pt-BR', includeTime
    ? { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }
    : { day: '2-digit', month: 'short' }).format(date)
}

function initials(name: string) {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase() || 'OB'
}

function requestId() {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID()
  return `${Date.now()}-${Math.random().toString(36).slice(2)}-${Math.random().toString(36).slice(2)}`
}

function Avatar({ person, small = false }: { person: Person; small?: boolean }) {
  return <span className={`avatar ${small ? 'avatar-small' : ''}`}>{initials(person.nickname || person.name)}</span>
}

function TransactionRow({ transaction, onClick }: { transaction: Transaction; onClick: () => void }) {
  const incoming = transaction.direction === 'in'
  return (
    <button className="transaction-row" type="button" onClick={onClick}>
      <span className={`transaction-icon ${incoming ? 'incoming' : 'outgoing'}`}>
        {incoming ? <ArrowDownLeft size={18} /> : <ArrowUpRight size={18} />}
      </span>
      <span className="transaction-copy">
        <strong>{transaction.title}</strong>
        <small>{transaction.counterparty} · {formatDate(transaction.createdAt)}</small>
      </span>
      <span className={`transaction-amount ${incoming ? 'positive' : ''}`}>
        {incoming ? '+' : '-'} {formatMoney(transaction.amount)}
      </span>
    </button>
  )
}

export default function App() {
  const [screen, setScreen] = useState<Screen>('home')
  const [dashboard, setDashboard] = useState<Dashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [balanceVisible, setBalanceVisible] = useState(true)
  const [selectedTransaction, setSelectedTransaction] = useState<Transaction | null>(null)
  const [receipt, setReceipt] = useState<Receipt | null>(null)

  const [target, setTarget] = useState('')
  const [recipient, setRecipient] = useState<Person | null>(null)
  const [amount, setAmount] = useState('')
  const [description, setDescription] = useState('')
  const [confirmId, setConfirmId] = useState('')
  const [confirmOpen, setConfirmOpen] = useState(false)

  const [favoriteOpen, setFavoriteOpen] = useState(false)
  const [favoriteTarget, setFavoriteTarget] = useState('')
  const [favoriteNickname, setFavoriteNickname] = useState('')
  const [creditPayment, setCreditPayment] = useState('')
  const refreshInFlight = useRef(false)
  const appActive = useRef(false)

  const loadDashboard = useCallback(async (quiet = false) => {
    if (refreshInFlight.current) return
    refreshInFlight.current = true
    if (!quiet) setLoading(true)

    try {
      const response = await bankRequest<Dashboard>('bootstrap')
      if (response.ok && response.data) {
        setDashboard(response.data)
        setError('')
      } else {
        setError(response.error || 'Não foi possível carregar sua conta.')
      }
    } catch {
      setError('Não foi possível atualizar sua conta agora.')
    } finally {
      setLoading(false)
      refreshInFlight.current = false
    }
  }, [])

  useEffect(() => {
    document.body.style.visibility = 'visible'
    void loadDashboard()

    const refresh = () => void loadDashboard(true)
    const onFocus = () => refresh()
    const onVisibilityChange = () => {
      if (document.visibilityState === 'visible') refresh()
    }
    const bridgeInstance = window.QSPhoneBridge?.create({
      appId: 'ob_bank',
      targetOrigin: 'https://cfx-nui-qs-smartphone',
    })

    const removeReady = bridgeInstance?.api.onReady(() => {
      void bridgeInstance.api.getPhoneState().then((state) => {
        appActive.current = state.visible === true && state.activeApp === 'ob_bank'
        if (appActive.current) refresh()
      }).catch(() => {
        appActive.current = document.hasFocus()
      })
    })
    const removeBridgeEvent = bridgeInstance?.api.onEvent((event) => {
      if (event === 'app:opened') {
        appActive.current = true
        refresh()
      } else if (event === 'app:closed') {
        appActive.current = false
      }
    })
    const refreshTimer = window.setInterval(() => {
      if (appActive.current && document.visibilityState === 'visible') refresh()
    }, 5000)

    window.addEventListener('focus', onFocus)
    document.addEventListener('visibilitychange', onVisibilityChange)

    return () => {
      window.clearInterval(refreshTimer)
      window.removeEventListener('focus', onFocus)
      document.removeEventListener('visibilitychange', onVisibilityChange)
      removeReady?.()
      removeBridgeEvent?.()
      bridgeInstance?.bridge.destroy()
    }
  }, [loadDashboard])

  const chooseRecipient = (person: Person) => {
    setTarget(person.citizenid)
    setRecipient(person)
    setError('')
    setScreen('pix')
  }

  const resolveTarget = async () => {
    if (!target.trim()) return setError('Informe o ID da sessão ou CitizenID.')
    setBusy(true)
    setRecipient(null)
    const response = await bankRequest<{ recipient: Person }>('resolve', { target: target.trim() })
    if (response.ok && response.data) {
      setRecipient(response.data.recipient)
      setTarget(response.data.recipient.citizenid)
      setError('')
    } else {
      setError(response.error || 'Destinatário não encontrado.')
    }
    setBusy(false)
  }

  const prepareTransfer = () => {
    const parsed = Number(amount)
    if (!recipient) return setError('Confira o destinatário antes de continuar.')
    if (!Number.isInteger(parsed) || parsed <= 0) return setError('Informe um valor inteiro válido.')
    if (dashboard?.credit?.blocked) return setError('Sua conta está bloqueada. Quite a fatura antes de enviar Pix.')
    if (dashboard?.transferBlocked) return setError('Existe um Pix anterior em análise.')
    setConfirmId(requestId())
    setConfirmOpen(true)
    setError('')
  }

  const confirmTransfer = async () => {
    if (!recipient || !confirmId || busy) return
    setBusy(true)
    const response = await bankRequest<{ receipt: Receipt }>('transfer', {
      requestId: confirmId,
      target: recipient.citizenid,
      amount: Number(amount),
      description: description.trim(),
    })
    if (response.ok && response.data) {
      setReceipt(response.data.receipt)
      setConfirmOpen(false)
      setAmount('')
      setDescription('')
      setConfirmId('')
      setRecipient(null)
      setTarget('')
      await loadDashboard(true)
    } else {
      setError(response.error || 'Não foi possível concluir o Pix.')
      setConfirmOpen(false)
    }
    setBusy(false)
  }

  const saveFavorite = async () => {
    if (!favoriteTarget.trim()) return setError('Informe um ID da sessão ou CitizenID.')
    setBusy(true)
    const response = await bankRequest<{ favorites: Person[] }>('favorite_save', {
      target: favoriteTarget.trim(),
      nickname: favoriteNickname.trim(),
    })
    if (response.ok && response.data && dashboard) {
      setDashboard({ ...dashboard, favorites: response.data.favorites })
      setFavoriteOpen(false)
      setFavoriteTarget('')
      setFavoriteNickname('')
      setError('')
    } else {
      setError(response.error || 'Não foi possível salvar o favorito.')
    }
    setBusy(false)
  }

  const deleteFavorite = async (citizenid: string) => {
    setBusy(true)
    const response = await bankRequest<{ favorites: Person[] }>('favorite_delete', { citizenid })
    if (response.ok && response.data && dashboard) {
      setDashboard({ ...dashboard, favorites: response.data.favorites })
      setError('')
    } else {
      setError(response.error || 'Não foi possível remover o favorito.')
    }
    setBusy(false)
  }

  const refreshCredit = async () => {
    setBusy(true)
    const response = await bankRequest<CreditState>('credit_state')
    if (response.ok && response.data) {
      setDashboard((current) => current ? { ...current, credit: response.data! } : current)
      setError('')
    } else {
      setError(response.error || 'Não foi possível atualizar o cartão.')
    }
    setBusy(false)
  }

  const payCredit = async () => {
    const total = dashboard?.credit?.totalDue || 0
    const payment = creditPayment ? Number(creditPayment) : total
    if (!Number.isInteger(payment) || payment < 1 || payment > total) return setError('Informe um valor válido para a fatura.')
    setBusy(true)
    const response = await bankRequest<{ paid: number; state: CreditState }>('credit_pay', {
      amount: payment,
      requestId: requestId(),
    })
    if (response.ok && response.data) {
      setCreditPayment('')
      setError('')
      await loadDashboard(true)
    } else {
      setError(response.error || 'Não foi possível pagar a fatura.')
    }
    setBusy(false)
  }

  if (loading || !dashboard) {
    return (
      <main className="loading-screen">
        <img src="./icon.png" alt="Obscuria" />
        <LoaderCircle className="spin" size={26} />
        {error && <p>{error}</p>}
      </main>
    )
  }

  return (
    <main className="app-shell">
      {error && (
        <div className="error-banner" role="alert">
          <span>{error}</span>
          <button type="button" title="Fechar aviso" onClick={() => setError('')}><X size={16} /></button>
        </div>
      )}

      {screen === 'home' && (
        <HomeView
          dashboard={dashboard}
          balanceVisible={balanceVisible}
          onToggleBalance={() => setBalanceVisible((value) => !value)}
          onRefresh={() => void loadDashboard(true)}
          onPix={() => setScreen('pix')}
          onStatement={() => setScreen('statement')}
          onFavorites={() => setScreen('favorites')}
          onCredit={() => setScreen('credit')}
          onRecipient={chooseRecipient}
          onTransaction={setSelectedTransaction}
        />
      )}

      {screen === 'pix' && (
        <PixView
          dashboard={dashboard}
          target={target}
          recipient={recipient}
          amount={amount}
          description={description}
          busy={busy}
          onTarget={(value) => { setTarget(value); setRecipient(null) }}
          onResolve={() => void resolveTarget()}
          onAmount={setAmount}
          onDescription={setDescription}
          onRecipient={chooseRecipient}
          onContinue={prepareTransfer}
          onFavorites={() => setScreen('favorites')}
        />
      )}

      {screen === 'statement' && (
        <StatementView history={dashboard.history} onTransaction={setSelectedTransaction} />
      )}

      {screen === 'favorites' && (
        <FavoritesView
          favorites={dashboard.favorites}
          busy={busy}
          onChoose={chooseRecipient}
          onAdd={() => setFavoriteOpen(true)}
          onDelete={(citizenid) => void deleteFavorite(citizenid)}
        />
      )}

      {screen === 'credit' && dashboard.credit && (
        <CreditView
          credit={dashboard.credit}
          balance={dashboard.account.balance}
          payment={creditPayment}
          busy={busy}
          onPayment={setCreditPayment}
          onPay={() => void payCredit()}
          onRefresh={() => void refreshCredit()}
        />
      )}

      <nav className="bottom-nav" aria-label="Navegação principal">
        <button type="button" className={screen === 'home' ? 'active' : ''} onClick={() => setScreen('home')}><Home size={20} /><span>Início</span></button>
        <button type="button" className={screen === 'pix' ? 'active' : ''} onClick={() => setScreen('pix')}><Send size={20} /><span>Pix</span></button>
        <button type="button" className={screen === 'statement' ? 'active' : ''} onClick={() => setScreen('statement')}><FileText size={20} /><span>Extrato</span></button>
        <button type="button" className={screen === 'credit' ? 'active' : ''} onClick={() => setScreen('credit')}><CreditCard size={20} /><span>Cartão</span></button>
      </nav>

      {confirmOpen && recipient && (
        <div className="modal-backdrop" role="presentation">
          <section className="bottom-sheet" role="dialog" aria-modal="true" aria-label="Confirmar Pix">
            <div className="sheet-handle" />
            <button className="close-button" type="button" title="Fechar" onClick={() => setConfirmOpen(false)}><X size={20} /></button>
            <span className="sheet-icon"><Send size={24} /></span>
            <p className="eyebrow">Você está enviando</p>
            <h2>{formatMoney(Number(amount))}</h2>
            <div className="confirmation-person"><Avatar person={recipient} /><span><strong>{recipient.name}</strong><small>{recipient.citizenid}</small></span></div>
            {description && <p className="confirmation-description">{description}</p>}
            <button className="primary-button" type="button" disabled={busy} onClick={() => void confirmTransfer()}>
              {busy ? <LoaderCircle className="spin" size={18} /> : <Check size={18} />} Confirmar Pix
            </button>
          </section>
        </div>
      )}

      {receipt && (
        <div className="modal-backdrop" role="presentation">
          <section className="receipt-sheet" role="dialog" aria-modal="true" aria-label="Comprovante Pix">
            <span className="success-mark"><Check size={28} /></span>
            <p className="eyebrow">Pix realizado</p>
            <h2>{formatMoney(receipt.amount)}</h2>
            <dl>
              <div><dt>Para</dt><dd>{receipt.recipient.name}</dd></div>
              <div><dt>CitizenID</dt><dd>{receipt.recipient.citizenid}</dd></div>
              <div><dt>Data</dt><dd>{formatDate(receipt.createdAt, true)}</dd></div>
              <div><dt>Identificador</dt><dd>{receipt.id}</dd></div>
              {receipt.description && <div><dt>Descrição</dt><dd>{receipt.description}</dd></div>}
            </dl>
            <button className="primary-button" type="button" onClick={() => { setReceipt(null); setScreen('home') }}>Concluir</button>
          </section>
        </div>
      )}

      {selectedTransaction && (
        <div className="modal-backdrop" role="presentation" onClick={() => setSelectedTransaction(null)}>
          <section className="transaction-sheet" role="dialog" aria-modal="true" onClick={(event) => event.stopPropagation()}>
            <button className="close-button" type="button" title="Fechar" onClick={() => setSelectedTransaction(null)}><X size={20} /></button>
            <span className={`transaction-detail-icon ${selectedTransaction.direction}`}>
              {selectedTransaction.direction === 'in' ? <ArrowDownLeft size={24} /> : <ArrowUpRight size={24} />}
            </span>
            <p className="eyebrow">{selectedTransaction.title}</p>
            <h2>{selectedTransaction.direction === 'in' ? '+' : '-'} {formatMoney(selectedTransaction.amount)}</h2>
            <dl>
              <div><dt>Com</dt><dd>{selectedTransaction.counterparty}</dd></div>
              {selectedTransaction.counterpartyCitizenId && <div><dt>CitizenID</dt><dd>{selectedTransaction.counterpartyCitizenId}</dd></div>}
              <div><dt>Data</dt><dd>{formatDate(selectedTransaction.createdAt, true)}</dd></div>
              {selectedTransaction.description && <div><dt>Descrição</dt><dd>{selectedTransaction.description}</dd></div>}
              <div><dt>Identificador</dt><dd>{selectedTransaction.id}</dd></div>
            </dl>
          </section>
        </div>
      )}

      {favoriteOpen && (
        <div className="modal-backdrop" role="presentation">
          <section className="bottom-sheet favorite-form" role="dialog" aria-modal="true" aria-label="Novo favorito">
            <button className="close-button" type="button" title="Fechar" onClick={() => setFavoriteOpen(false)}><X size={20} /></button>
            <h2>Novo favorito</h2>
            <label>Destinatário<input value={favoriteTarget} maxLength={64} placeholder="ID da sessão ou CitizenID" onChange={(event) => setFavoriteTarget(event.target.value)} /></label>
            <label>Apelido<input value={favoriteNickname} maxLength={40} placeholder="Ex.: Jaspe" onChange={(event) => setFavoriteNickname(event.target.value)} /></label>
            <button className="primary-button" type="button" disabled={busy} onClick={() => void saveFavorite()}>
              {busy ? <LoaderCircle className="spin" size={18} /> : <Star size={18} />} Salvar favorito
            </button>
          </section>
        </div>
      )}
    </main>
  )
}

function HomeView({ dashboard, balanceVisible, onToggleBalance, onRefresh, onPix, onStatement, onFavorites, onCredit, onRecipient, onTransaction }: {
  dashboard: Dashboard
  balanceVisible: boolean
  onToggleBalance: () => void
  onRefresh: () => void
  onPix: () => void
  onStatement: () => void
  onFavorites: () => void
  onCredit: () => void
  onRecipient: (person: Person) => void
  onTransaction: (transaction: Transaction) => void
}) {
  const firstName = dashboard.account.name.split(' ')[0]
  return (
    <div className="screen home-screen">
      <header className="purple-header">
        <div className="brand-row">
          <img src="./icon.png" alt="Obscuria" />
          <button type="button" title="Atualizar saldo" onClick={onRefresh}><RefreshCw size={19} /></button>
        </div>
        <p>Olá, {firstName}</p>
        <div className="balance-label"><span>Saldo disponível</span><button type="button" title={balanceVisible ? 'Ocultar saldo' : 'Mostrar saldo'} onClick={onToggleBalance}>{balanceVisible ? <Eye size={18} /> : <EyeOff size={18} />}</button></div>
        <strong className="balance-value">{balanceVisible ? formatMoney(dashboard.account.balance) : '••••••'}</strong>
        <small>Conta {dashboard.account.citizenid}</small>
      </header>

      <section className="quick-actions" aria-label="Ações rápidas">
        <button type="button" onClick={onPix}><span><Send size={20} /></span><b>Pix</b></button>
        <button type="button" onClick={onStatement}><span><FileText size={20} /></span><b>Extrato</b></button>
        <button type="button" onClick={onFavorites}><span><Heart size={20} /></span><b>Favoritos</b></button>
        <button type="button" onClick={onCredit}><span><CreditCard size={20} /></span><b>Cartão</b></button>
      </section>

      {dashboard.credit?.blocked
        ? <div className="review-alert blocked"><ShieldAlert size={18} /><span>Conta bloqueada por atraso. Pague a fatura para regularizar.</span></div>
        : dashboard.transferBlocked && <div className="review-alert"><Clock3 size={18} /><span>Há um Pix em análise. Novos envios estão temporariamente bloqueados.</span></div>}

      {dashboard.credit && (
        <button className="credit-summary" type="button" onClick={onCredit}>
          <span><small>Fatura atual</small><strong>{formatMoney(dashboard.credit.totalDue)}</strong></span>
          <span><small>Limite disponível</small><strong>{formatMoney(dashboard.credit.available)}</strong></span>
          <ChevronRight size={18} />
        </button>
      )}

      <section className="content-section">
        <div className="section-title"><h2>Pix recentes</h2><button type="button" onClick={onPix}>Ver todos</button></div>
        {dashboard.recent.length > 0 ? (
          <div className="people-strip">
            {dashboard.recent.map((person) => <button type="button" key={person.citizenid} onClick={() => onRecipient(person)}><Avatar person={person} /><span>{person.name.split(' ')[0]}</span></button>)}
          </div>
        ) : <p className="empty-inline">Seus últimos destinatários aparecerão aqui.</p>}
      </section>

      <section className="content-section transactions-section">
        <div className="section-title"><h2>Movimentações</h2><button type="button" onClick={onStatement}>Extrato</button></div>
        <div className="transaction-list">
          {dashboard.history.slice(0, 5).map((item) => <TransactionRow key={item.id} transaction={item} onClick={() => onTransaction(item)} />)}
          {dashboard.history.length === 0 && <p className="empty-inline">Nenhuma movimentação encontrada.</p>}
        </div>
      </section>
    </div>
  )
}

function PixView({ dashboard, target, recipient, amount, description, busy, onTarget, onResolve, onAmount, onDescription, onRecipient, onContinue, onFavorites }: {
  dashboard: Dashboard
  target: string
  recipient: Person | null
  amount: string
  description: string
  busy: boolean
  onTarget: (value: string) => void
  onResolve: () => void
  onAmount: (value: string) => void
  onDescription: (value: string) => void
  onRecipient: (person: Person) => void
  onContinue: () => void
  onFavorites: () => void
}) {
  return (
    <div className="screen inner-screen">
      <header className="inner-header"><span className="page-icon"><Send size={22} /></span><div><small>Área Pix</small><h1>Enviar Pix</h1></div></header>
      <section className="form-section">
        <label>Destinatário</label>
        <div className="search-field"><UserRound size={18} /><input value={target} maxLength={64} placeholder="ID da sessão ou CitizenID" onChange={(event) => onTarget(event.target.value)} /><button type="button" title="Buscar destinatário" disabled={busy} onClick={onResolve}>{busy ? <LoaderCircle className="spin" size={18} /> : <Search size={18} />}</button></div>
        {recipient && <div className="resolved-person"><Avatar person={recipient} /><span><strong>{recipient.name}</strong><small>{recipient.citizenid}{recipient.online ? ' · Online' : ''}</small></span><Check size={19} /></div>}
      </section>

      <section className="content-section compact-section">
        <div className="section-title"><h2>Favoritos</h2><button type="button" onClick={onFavorites}>Gerenciar</button></div>
        <div className="favorite-chips">
          {dashboard.favorites.slice(0, 4).map((person) => <button type="button" key={person.citizenid} onClick={() => onRecipient(person)}><Avatar person={person} small /><span>{person.nickname || person.name.split(' ')[0]}</span></button>)}
          {dashboard.favorites.length === 0 && <span className="empty-chip">Nenhum favorito</span>}
        </div>
      </section>

      <section className="form-section transfer-form">
        <label htmlFor="amount">Valor</label>
        <div className="money-input"><span>$</span><input id="amount" inputMode="numeric" pattern="[0-9]*" value={amount} placeholder="0" onChange={(event) => onAmount(event.target.value.replace(/\D/g, ''))} /></div>
        <label htmlFor="description">Descrição <small>opcional</small></label>
        <input id="description" className="text-input" value={description} maxLength={80} placeholder="Motivo do Pix" onChange={(event) => onDescription(event.target.value)} />
      </section>

      <button className="primary-button page-action" type="button" disabled={!recipient || !amount || dashboard.transferBlocked} onClick={onContinue}><Send size={18} /> Continuar</button>
    </div>
  )
}

function CreditView({ credit, balance, payment, busy, onPayment, onPay, onRefresh }: {
  credit: CreditState
  balance: number
  payment: string
  busy: boolean
  onPayment: (value: string) => void
  onPay: () => void
  onRefresh: () => void
}) {
  const usage = credit.limit > 0 ? Math.min(100, Math.round((credit.used / credit.limit) * 100)) : 0
  const paymentValue = payment ? Number(payment) : credit.totalDue
  const dueCopy = credit.dueAt
    ? credit.overdueDays > 0 ? `Vencida há ${credit.overdueDays} dia(s)` : `Vence em ${Math.max(0, credit.daysUntilDue || 0)} dia(s)`
    : 'Sem fatura aberta'

  return (
    <div className="screen inner-screen credit-screen">
      <header className="inner-header">
        <span className="page-icon"><CreditCard size={22} /></span>
        <div><small>Obscuria Bank</small><h1>Cartão de crédito</h1></div>
        <button className="header-action" type="button" title="Atualizar cartão" disabled={busy} onClick={onRefresh}><RefreshCw className={busy ? 'spin' : ''} size={19} /></button>
      </header>

      <section className={`credit-card-panel ${credit.blocked ? 'blocked' : ''}`}>
        <div className="credit-card-brand"><img src="./icon.png" alt="" /><span>{credit.blocked ? 'CONTA BLOQUEADA' : 'OBSCURIA'}</span></div>
        <small>Limite disponível</small>
        <strong>{formatMoney(credit.available)}</strong>
        <div className="credit-usage"><i style={{ width: `${usage}%` }} /></div>
        <footer><span>Usado {formatMoney(credit.used)}</span><span>Limite {formatMoney(credit.limit)}</span></footer>
      </section>

      {credit.blocked && (
        <div className="credit-blocked-alert"><ShieldAlert size={21} /><span><strong>Conta negativada</strong><small>O atraso passou de {credit.blockAfterDays} dias. Pix, saques e pagamentos bancários voltam após a regularização.</small></span></div>
      )}

      <section className="invoice-panel">
        <header><div><small>Fatura atual</small><strong>{formatMoney(credit.totalDue)}</strong></div><span className={credit.overdueDays > 0 ? 'overdue' : ''}>{dueCopy}</span></header>
        {credit.dueAt && <p>Vencimento em {formatDate(credit.dueAt, false)} · ciclo de {credit.cycleDays} dias</p>}
        {credit.interest > 0 && <p className="interest-copy">Inclui {formatMoney(credit.interest)} de juros. Taxa: {credit.dailyInterestPercent}% ao dia.</p>}
        {credit.totalDue > 0 ? (
          <div className="invoice-payment">
            <label htmlFor="credit-payment">Valor do pagamento</label>
            <div><span>$</span><input id="credit-payment" inputMode="numeric" value={payment} placeholder={String(credit.totalDue)} onChange={(event) => onPayment(event.target.value.replace(/\D/g, ''))} /></div>
            <small>Saldo bancário: {formatMoney(balance)}</small>
            <button type="button" disabled={busy || paymentValue < 1 || paymentValue > credit.totalDue} onClick={onPay}>
              {busy ? <LoaderCircle className="spin" size={17} /> : <Check size={17} />} Pagar fatura
            </button>
          </div>
        ) : <div className="invoice-clear"><Check size={18} /><span>Sua fatura está em dia.</span></div>}
      </section>

      <section className="score-panel">
        <header><span>Score financeiro</span><strong>{credit.score}</strong></header>
        <div><i style={{ width: `${credit.score / 10}%` }} /></div>
        <p>O limite considera saldo bancário, volume de movimentações e histórico de pagamento.</p>
      </section>

      <section className="content-section credit-history">
        <div className="section-title"><h2>Lançamentos do cartão</h2></div>
        {credit.history.map((item) => {
          const positive = item.type === 'payment' || item.type === 'refund'
          const label = item.type === 'payment' ? 'Pagamento de fatura' : item.type === 'interest' ? 'Juros' : item.type === 'refund' ? 'Estorno' : item.merchant
          return (
            <div className="credit-history-row" key={item.id}>
              <span className={positive ? 'positive' : item.type === 'interest' ? 'interest' : ''}>{positive ? <ArrowDownLeft size={17} /> : <CreditCard size={17} />}</span>
              <div><strong>{label}</strong><small>{item.description} · {formatDate(item.createdAt)}</small></div>
              <b className={positive ? 'positive' : ''}>{positive ? '-' : '+'} {formatMoney(item.amount)}</b>
            </div>
          )
        })}
        {credit.history.length === 0 && <p className="empty-inline">Nenhum lançamento no cartão.</p>}
      </section>
    </div>
  )
}

function StatementView({ history, onTransaction }: { history: Transaction[]; onTransaction: (transaction: Transaction) => void }) {
  const [filter, setFilter] = useState<StatementFilter>('all')
  const filtered = useMemo(() => filter === 'all' ? history : history.filter((item) => item.direction === filter), [filter, history])
  return (
    <div className="screen inner-screen statement-screen">
      <header className="inner-header"><span className="page-icon"><FileText size={22} /></span><div><small>Sua conta</small><h1>Extrato</h1></div></header>
      <div className="segmented-control">
        <button type="button" className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>Todos</button>
        <button type="button" className={filter === 'in' ? 'active' : ''} onClick={() => setFilter('in')}>Entradas</button>
        <button type="button" className={filter === 'out' ? 'active' : ''} onClick={() => setFilter('out')}>Saídas</button>
      </div>
      <section className="statement-list">
        {filtered.map((item) => <TransactionRow key={item.id} transaction={item} onClick={() => onTransaction(item)} />)}
        {filtered.length === 0 && <div className="empty-state"><FileText size={28} /><strong>Nenhuma movimentação</strong><span>Não encontramos lançamentos neste filtro.</span></div>}
      </section>
    </div>
  )
}

function FavoritesView({ favorites, busy, onChoose, onAdd, onDelete }: { favorites: Person[]; busy: boolean; onChoose: (person: Person) => void; onAdd: () => void; onDelete: (citizenid: string) => void }) {
  return (
    <div className="screen inner-screen favorites-screen">
      <header className="inner-header"><span className="page-icon"><Heart size={22} /></span><div><small>Pix</small><h1>Favoritos</h1></div><button className="header-action" type="button" title="Adicionar favorito" onClick={onAdd}><Plus size={20} /></button></header>
      <section className="favorites-list">
        {favorites.map((person) => (
          <div className="favorite-row" key={person.citizenid}>
            <button type="button" className="favorite-person" onClick={() => onChoose(person)}><Avatar person={person} /><span><strong>{person.nickname || person.name}</strong><small>{person.nickname ? person.name : person.citizenid}</small></span><ChevronRight size={18} /></button>
            <button type="button" className="delete-button" title="Remover favorito" disabled={busy} onClick={() => onDelete(person.citizenid)}><Trash2 size={17} /></button>
          </div>
        ))}
        {favorites.length === 0 && <div className="empty-state"><Star size={28} /><strong>Nenhum favorito</strong><span>Salve pessoas para encontrá-las mais rápido.</span><button type="button" onClick={onAdd}><Plus size={17} /> Adicionar</button></div>}
      </section>
    </div>
  )
}
