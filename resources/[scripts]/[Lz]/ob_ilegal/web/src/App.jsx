import React, { useEffect } from 'react';
import { loadLegacyRuntime } from './legacyLoader.js';

const GameFrame = ({ id, className, canvasId, label, instruction, progress, secondary, secondaryId, children }) => (
    <div id={`${id}-game`} className={`game game-${className}`}>
        <div className={`stage-shell ${className}-shell`}>
            <div id={`${id}-stage`} className={`canvas-stage ${className}-stage`}>
                <canvas id={canvasId} aria-label={label} />
                {children}
            </div>
        </div>
        <div className="ritual-instruction">
            <span className="mouse-symbol" />
            <span id={`${id}-instruction`}>{instruction}</span>
        </div>
        <div className="game-status">
            <span id={`${id}-progress`}>{progress}</span>
            <span id={secondaryId}>{secondary}</span>
        </div>
    </div>
);

function VaultLocks() {
    return (
        <div id="vault-locks" className="vault-locks" aria-label="Três fechaduras do cofre">
            {[0, 1, 2].map((index) => (
                <div className="vault-lock" data-vault-lock={index} key={index}>
                    <span className="vault-lock-number">{index + 1}</span>
                </div>
            ))}
        </div>
    );
}

export default function App() {
    useEffect(() => {
        loadLegacyRuntime().catch((error) => console.error('[ob_ilegal] NUI runtime:', error));
    }, []);

    return (
        <main id="ritual-app" className="ritual-app is-hidden" aria-hidden="true" style={{ display: 'none' }}>
            <div className="screen-shade" />

            <section id="ritual-panel" className="ritual-panel" aria-label="Ritual de violação">
                <header className="ritual-header">
                    <span id="ritual-eyebrow" className="ritual-eyebrow">RITUAL</span>
                    <h1 id="ritual-title">Corrupção Rúnica</h1>
                    <div className="header-rule"><i /></div>
                </header>

                <GameFrame id="witch" className="witch" canvasId="witch-canvas" label="Área para traçar runas" instruction="SEGURE E TRACE O SÍMBOLO" progress="RUNA 1 / 3" secondary="TRAMA ESTÁVEL" secondaryId="witch-errors" />
                <GameFrame id="vampire" className="vampire" canvasId="vampire-canvas" label="Circuito hemático" instruction="CONDUZA O SANGUE PELOS CONTATOS" progress="0 / 6 CONTATOS" secondary="PRESSÃO ESTÁVEL" secondaryId="vampire-errors" />
                <GameFrame id="healer" className="healer" canvasId="healer-canvas" label="Trama de vinhas" instruction="DESPERTE OS BROTOS LUMINOSOS" progress="0 / 3 VINHAS" secondary="RAÍZES ADORMECIDAS" secondaryId="healer-errors" />
                <GameFrame id="lock" className="lock" canvasId="lock-canvas" label="Mecanismo de fechadura" instruction="SEGURE PARA ERGUER / SOLTE NA LINHA DE CORTE" progress="PINO 1 / 5" secondary="GAZUA INTACTA" secondaryId="lock-errors" />
                <GameFrame id="vault" className="vault" canvasId="vault-canvas" label="Disco do cofre" instruction="GIRE DEVAGAR / ESCUTE O NÚMERO CORRETO" progress="FECHADURA 1 / 3" secondary="ENCONTRE O NÚMERO" secondaryId="vault-target">
                    <VaultLocks />
                </GameFrame>

                <footer className="ritual-footer">
                    <span id="ritual-timer">00:24</span>
                    <span id="ritual-state">AGUARDE O SINAL</span>
                </footer>
            </section>
        </main>
    );
}
