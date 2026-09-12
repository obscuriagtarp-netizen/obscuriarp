const arcaneVision = document.getElementById('arcaneVision');

window.addEventListener('message', ({ data }) => {
  if (!data || data.action !== 'setArcaneSenseGlow') return;

  const active = data.visible === true;
  arcaneVision.classList.toggle('is-active', active);
  arcaneVision.setAttribute('aria-hidden', active ? 'false' : 'true');
});
