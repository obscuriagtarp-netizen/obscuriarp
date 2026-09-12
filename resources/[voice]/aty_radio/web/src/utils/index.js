/* eslint-disable */

export async function fetchNui(action, payload) {
  const options = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  }

  const url = `https://${GetParentResourceName()}/${action}`

  try {
    const response = await fetch(url, options)

    return await response.json()
  } catch (e) {
    console.error(`Failed to fetch NUI: ${e.message} (${action})`)

    return false
  }
}

export function convertValue(value, oldMin, oldMax, newMin, newMax) {
  const oldRange = oldMax - oldMin
  const newRange = newMax - newMin
  const newValue = ((value - oldMin) * newRange) / oldRange + newMin
  return newValue
}
