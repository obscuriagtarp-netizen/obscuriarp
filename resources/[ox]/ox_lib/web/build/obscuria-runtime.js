(function () {
  const findText = (text) => {
    const expected = typeof text === 'string' ? text.trim() : '';
    const nodes = document.querySelectorAll('#root .mantine-Text-root');

    if (expected) {
      for (const node of nodes) {
        if (node.textContent.trim() === expected) return node;
      }
    }

    return nodes.length ? nodes[nodes.length - 1] : null;
  };

  const retry = (callback, attempts) => {
    window.requestAnimationFrame(() => {
      if (!callback() && attempts > 1) retry(callback, attempts - 1);
    });
  };

  const markLinearProgress = (data) => retry(() => {
    const label = findText(data && data.label);
    const fill = label && label.parentElement;
    const track = fill && fill.parentElement;
    const wrapper = track && track.parentElement;

    if (!label || !fill || !track || !wrapper) return false;

    label.classList.add('obscuria-progress-linear-label');
    fill.classList.add('obscuria-progress-linear-fill');
    track.classList.add('obscuria-progress-linear-track');
    wrapper.classList.add('obscuria-progress-linear-wrapper');
    return true;
  }, 8);

  const markCircleProgress = (data) => retry(() => {
    const label = findText(data && data.label);
    const wrapper = label && label.parentElement;
    const ring = wrapper && wrapper.querySelector('.mantine-RingProgress-root');
    const value = ring && ring.querySelector('.mantine-Text-root');

    if (!label || !wrapper || !ring || !value) return false;

    wrapper.classList.add('obscuria-progress-circle-wrapper');
    ring.classList.add('obscuria-progress-circle-ring');
    value.classList.add('obscuria-progress-circle-value');
    label.classList.add('obscuria-progress-circle-label');
    return true;
  }, 8);

  window.addEventListener('message', (event) => {
    const message = event.data;

    if (!message || typeof message !== 'object') return;
    if (message.action === 'progress') markLinearProgress(message.data);
    if (message.action === 'circleProgress') markCircleProgress(message.data);
  });
})();
