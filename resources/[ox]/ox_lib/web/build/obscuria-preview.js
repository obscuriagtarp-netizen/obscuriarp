(function () {
  if (window.invokeNative) return;

  const preview = new URLSearchParams(window.location.search).get('preview');
  if (!preview) return;

  const dispatch = (action, data) => {
    window.postMessage({ action, data }, '*');
  };

  window.addEventListener('load', () => {
    window.setTimeout(() => {
      dispatch('setLocale', {
        language: 'pt-BR',
        ui: {
          cancel: 'Cancelar',
          close: 'Fechar',
          confirm: 'Confirmar',
          more: 'Mais',
        },
      });

      if (preview === 'input') {
        dispatch('openDialog', {
          heading: 'Registro de personagem',
          rows: [
            {
              type: 'input',
              label: 'Nome conhecido',
              description: 'Como deseja ser reconhecido em Obscuria.',
              placeholder: 'Digite um nome',
              icon: 'user',
              required: true,
            },
            {
              type: 'select',
              label: 'Natureza',
              description: 'Escolha a afinidade principal.',
              icon: 'wand-sparkles',
              options: [
                { value: 'witch', label: 'Bruxa' },
                { value: 'healer', label: 'Curandeira' },
                { value: 'human', label: 'Humano' },
              ],
            },
            {
              type: 'checkbox',
              label: 'Confirmo que os dados estão corretos',
              checked: true,
            },
          ],
          options: { size: 'sm' },
        });
        return;
      }

      if (preview === 'alert') {
        dispatch('sendAlert', {
          header: 'Confirmar manifestação',
          content: 'Deseja vincular esta essência ao seu personagem? Esta escolha ficará registrada.',
          centered: true,
          cancel: true,
          labels: { cancel: 'Voltar', confirm: 'Confirmar' },
        });
        return;
      }

      if (preview === 'context') {
        dispatch('showContext', {
          title: 'Serviços de Obscuria',
          options: {
            appearance: {
              title: 'Aparência',
              description: 'Ajuste os detalhes do seu personagem.',
              icon: 'wand-sparkles',
            },
            garage: {
              title: 'Garagem',
              description: 'Consulte e retire seus veículos.',
              icon: 'car',
              metadata: [
                { label: 'Disponíveis', value: '3 veículos' },
                { label: 'Estado', value: 'Acesso liberado' },
              ],
            },
            collection: {
              title: 'Coleções',
              description: 'Conteúdo ainda não descoberto.',
              icon: 'lock',
              disabled: true,
            },
          },
        });
        return;
      }

      if (preview === 'menu') {
        dispatch('setMenu', {
          title: 'Preferências',
          position: 'top-left',
          items: [
            { label: 'Volume ambiente', description: 'Intensidade dos sons da cidade.', values: ['Baixo', 'Médio', 'Alto'], defaultIndex: 2 },
            { label: 'Efeitos mágicos', description: 'Exibe partículas e manifestações.', checked: true },
            { label: 'Interface compacta', description: 'Reduz o tamanho dos elementos da HUD.', checked: false },
            { label: 'Restaurar preferências', description: 'Volta às configurações recomendadas.' },
          ],
        });
        return;
      }

      if (preview === 'textui') {
        dispatch('textUi', {
          text: '**[E]**  Acessar garagem',
          position: 'left-center',
          icon: 'car',
        });
        return;
      }

      if (preview === 'skill') {
        dispatch('startSkillCheck', {
          difficulty: { areaSize: 42, speedMultiplier: 0.18 },
          inputs: ['e'],
        });
        return;
      }

      if (preview === 'notify') {
        dispatch('notify', {
          title: 'Obscuria',
          description: 'Sua presença foi reconhecida pela cidade.',
          duration: 30000,
          position: 'top-left',
          type: 'success',
        });
        return;
      }

      if (preview === 'progress') {
        dispatch('progress', {
          label: 'Preparando manifestação',
          duration: 30000,
        });
        return;
      }

      if (preview === 'circle') {
        dispatch('circleProgress', {
          label: 'Canalizando essência',
          duration: 30000,
          position: 'middle',
        });
        return;
      }

      dispatch('openRadialMenu', {
        items: [
          { icon: 'wand-sparkles', label: 'Poderes' },
          { icon: 'car', label: 'Veículos' },
          { icon: 'briefcase', label: 'Trabalho' },
          { icon: 'shirt', label: 'Aparência' },
          { icon: 'person-walking', label: 'Animações' },
          { icon: 'gear', label: 'Opções' },
        ],
        sub: false,
      });
    }, 500);
  });
})();
