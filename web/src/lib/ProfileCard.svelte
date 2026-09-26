<script lang="ts">
  import type { Profile } from './api';

  let {
    profile,
    isMe,
    onEdit,
    onClose,
  }: { profile: Profile; isMe: boolean; onEdit: () => void; onClose: () => void } = $props();
</script>

<section class="card" aria-label={`${profile.username}'s profile`}>
  <button class="close" onclick={onClose} aria-label="Back to everyone's catches">×</button>

  <div class="header">
    {#if profile.avatar}
      <img class="avatar" src={profile.avatar} alt={profile.username} />
    {:else}
      <div class="avatar placeholder" style:background={profile.pin_color}>
        {profile.username.charAt(0).toUpperCase()}
      </div>
    {/if}
    <div class="identity">
      <h2>@{profile.username}</h2>
      {#if profile.location}<p class="location">📍 {profile.location}</p>{/if}
    </div>
  </div>

  {#if profile.description}
    <p class="description">{profile.description}</p>
  {/if}

  <p class="stats">
    {profile.catch_count}
    {profile.catch_count === 1 ? 'catch' : 'catches'} · angler since {new Date(profile.created_at).toLocaleDateString()}
  </p>

  {#if isMe}
    <button type="button" class="edit" onclick={onEdit}>Edit profile</button>
  {/if}
</section>

<style>
  .card {
    position: relative;
    width: min(300px, calc(100vw - 24px));
    background: var(--surface);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    color: var(--surface-fg);
    padding: 16px;
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
    border: 1px solid var(--border-soft);
    display: flex;
    flex-direction: column;
    gap: 10px;
    animation: pop-in 220ms var(--ease);
  }

  @keyframes pop-in {
    from {
      transform: translateY(-6px);
      opacity: 0;
    }
  }

  .close {
    position: absolute;
    top: 10px;
    right: 10px;
    width: 28px;
    height: 28px;
    display: grid;
    place-items: center;
    font-size: 1.1rem;
    line-height: 1;
    background: var(--border-soft);
    border-radius: var(--radius-sm);
    border: none;
    cursor: pointer;
    color: inherit;
    transition: background 150ms var(--ease);
  }

  .close:hover {
    background: rgba(224, 52, 92, 0.18);
    color: var(--color-danger);
  }

  .header {
    display: flex;
    align-items: center;
    gap: 12px;
    padding-right: 28px;
  }

  .avatar {
    width: 56px;
    height: 56px;
    border-radius: var(--radius-sm);
    object-fit: cover;
    flex-shrink: 0;
    box-shadow: var(--shadow-sm);
  }

  .placeholder {
    display: grid;
    place-items: center;
    font-size: 1.4rem;
    font-weight: 800;
    color: white;
    background: linear-gradient(135deg, var(--color-primary-light), var(--color-primary-dark));
  }

  .identity {
    min-width: 0;
  }

  h2 {
    margin: 0;
    font-size: 1.1rem;
    font-weight: 800;
    overflow-wrap: anywhere;
  }

  .location {
    margin: 2px 0 0;
    font-size: 0.85rem;
    opacity: 0.75;
  }

  .description {
    margin: 0;
    font-size: 0.9rem;
    white-space: pre-line;
    overflow-wrap: anywhere;
  }

  .stats {
    margin: 0;
    font-size: 0.8rem;
    opacity: 0.6;
  }

  .edit {
    align-self: flex-start;
    font: inherit;
    font-weight: 600;
    font-size: 0.85rem;
    padding: 6px 14px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-soft);
    background: var(--surface-solid);
    color: inherit;
    cursor: pointer;
  }
</style>
