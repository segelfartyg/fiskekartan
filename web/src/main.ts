import { mount } from 'svelte'
import './app.css'
import App from './App.svelte'
import { initAuth } from './lib/auth.svelte'

const app = mount(App, {
  target: document.getElementById('app')!,
})

// Fire-and-forget: the map/catch list render immediately regardless of
// whether auth has finished initializing.
initAuth()

export default app
