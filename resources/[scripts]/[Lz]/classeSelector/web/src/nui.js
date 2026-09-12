export function getResourceName() {
  if (typeof GetParentResourceName === 'function') {
    return GetParentResourceName()
  }

  return 'classeSelector'
}

export async function postNui(eventName, payload = {}) {
  if (typeof GetParentResourceName !== 'function') return

  const resourceName = getResourceName()

  try {
    await fetch(`https://${resourceName}/${eventName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8'
      },
      body: JSON.stringify(payload)
    })
  } catch (error) {
    console.warn(`[classeSelector] Falha ao enviar callback NUI: ${eventName}`, error)
  }
}
