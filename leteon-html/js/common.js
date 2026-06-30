'use strict'

// ── Config ──────────────────────────────────────────────────────────────────
const SUPABASE_URL = 'https://ytxrbayjaebiiquprhlx.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0eHJiYXlqYWViaWlxdXByaGx4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3MzIxMjUsImV4cCI6MjA5ODMwODEyNX0.9VZNyaPECXbfi2bnyVb4LIgJhh7DTExDFydS-ahlvHg'
const ADMIN_EMAIL = 'leteon2026@gmail.com'

// ── Supabase Client ──────────────────────────────────────────────────────────
const _sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// ── Utilities ────────────────────────────────────────────────────────────────
function formatPrice(price) {
  return new Intl.NumberFormat('ko-KR', { style: 'currency', currency: 'KRW' }).format(price)
}

function generateSlug(title) {
  const ts = Date.now().toString(36)
  const ascii = title.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '')
  return (ascii.length > 0 ? ascii.slice(0, 40) + '-' : '') + ts
}

function escHtml(str) {
  return String(str ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

function isAdmin() {
  return window._leteonUser?.email === ADMIN_EMAIL
}

function isInAdmin() {
  return window.location.pathname.includes('/admin/')
}

function base() {
  return isInAdmin() ? '../' : ''
}

const CONDITION_LABEL = { new: '새 상품', like_new: '거의 새것', good: '양호', fair: '보통' }
const CATEGORY_LIST = ['MTB', 'eMTB', 'eBike', 'Parts']
const STATUS_LABEL = { draft: '미결제', active: '판매중', sold: '판매완료', deleted: '삭제됨' }
const STATUS_COLOR = { draft: 'text-yellow-400', active: 'text-lime-400', sold: 'text-blue-400', deleted: 'text-zinc-500' }

// ── Auth ─────────────────────────────────────────────────────────────────────
async function getUser() {
  const { data: { user } } = await _sb.auth.getUser()
  return user
}

async function getProfile(userId) {
  if (!userId) return null
  const { data } = await _sb.from('profiles').select('username, avatar_url, phone, bio, heart_count').eq('id', userId).single()
  return data
}

function doSignOut() {
  _sb.auth.signOut().then(() => { window.location.href = base() + 'login.html' })
}

// ── Avatar HTML ───────────────────────────────────────────────────────────────
function avatarHtml(url, name, extraClass = '') {
  const initial = (String(name || '?')[0] || '?').toUpperCase()
  if (url) return `<img src="${escHtml(url)}" alt="${escHtml(name)}" class="w-full h-full object-cover ${extraClass}">`
  return `<div class="w-full h-full flex items-center justify-center text-sm font-bold text-zinc-400 ${extraClass}">${initial}</div>`
}

// ── Listing Card ──────────────────────────────────────────────────────────────
function listingCardHtml(listing) {
  const img = listing.image_urls?.[0]
  const p = listing.profiles || {}
  const b = base()
  return `
    <a href="${b}listing.html?slug=${escHtml(listing.slug)}"
       class="group block glass-card rounded overflow-hidden hover:border-lime-400/30 hover:shadow-lg hover:shadow-lime-400/5 transition-all duration-300 active:scale-[0.98] active:opacity-80">
      <div class="relative aspect-square bg-zinc-900 overflow-hidden">
        ${img
          ? `<img src="${escHtml(img)}" alt="${escHtml(listing.title)}" class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" loading="lazy">`
          : `<div class="absolute inset-0 flex items-center justify-center"><svg class="w-12 h-12 text-zinc-700" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg></div>`
        }
        <div class="absolute top-2 left-2 flex gap-1">
          <span class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold bg-zinc-800/90 text-zinc-200">${escHtml(listing.category)}</span>
          ${listing.condition ? `<span class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold bg-zinc-900/80 text-zinc-400">${escHtml(CONDITION_LABEL[listing.condition] || listing.condition)}</span>` : ''}
        </div>
        ${listing.status === 'sold' ? `<div class="absolute inset-0 bg-black/60 flex items-center justify-center"><span class="text-sm font-bold text-zinc-300 tracking-widest">판매완료</span></div>` : ''}
      </div>
      <div class="p-3.5">
        <h3 class="text-sm font-semibold text-white line-clamp-2 leading-snug group-hover:text-lime-400 transition-colors">${escHtml(listing.title)}</h3>
        ${listing.location ? `<p class="mt-1 text-xs text-zinc-500 flex items-center gap-1"><svg class="w-3 h-3 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/></svg>${escHtml(listing.location)}</p>` : ''}
        ${p.username ? `<p class="mt-1 text-xs text-zinc-500">${escHtml(p.username)}</p>` : ''}
        <p class="mt-2 text-base font-black font-mono text-lime-400">${formatPrice(listing.price)}</p>
      </div>
    </a>`
}

// ── Header ───────────────────────────────────────────────────────────────────
function renderHeader(user, profile) {
  const b = base()
  const displayName = profile?.username || user?.email?.split('@')[0] || '사용자'
  const av = avatarHtml(profile?.avatar_url, displayName)
  const av2 = avatarHtml(profile?.avatar_url, displayName)

  const desktopAuth = user ? `
    <a href="${b}new-listing.html" class="bg-lime-400 text-black text-xs font-bold px-3.5 py-2 rounded hover:bg-lime-300 transition-colors whitespace-nowrap">+ 매물 등록</a>
    <a href="${b}my.html" class="flex items-center gap-2 group">
      <div class="w-8 h-8 rounded-full bg-zinc-800 overflow-hidden border border-white/10 flex-shrink-0">${av}</div>
      <span class="text-sm text-zinc-400 group-hover:text-white transition-colors hidden lg:block">${escHtml(displayName)}</span>
    </a>
    <a href="${b}account.html" class="text-xs text-zinc-600 hover:text-zinc-300 transition-colors px-2 py-1">계정</a>
    <button onclick="doSignOut()" class="text-xs text-zinc-600 hover:text-red-400 transition-colors px-2 py-1">로그아웃</button>
  ` : `
    <a href="${b}signup.html" class="text-sm text-zinc-400 hover:text-lime-400 transition-colors font-medium border border-white/10 hover:border-lime-400/40 px-3.5 py-2 rounded">회원가입</a>
    <a href="${b}login.html" class="text-sm text-black font-bold bg-lime-400 hover:bg-lime-300 transition-colors px-3.5 py-2 rounded">로그인</a>
  `

  const mobileUserInfo = user ? `
    <div class="px-5 py-4 border-b border-white/[0.06] shrink-0">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-zinc-800 overflow-hidden border border-white/10 flex-shrink-0">${av2}</div>
        <div class="min-w-0">
          <p class="text-sm font-semibold text-white truncate">${escHtml(displayName)}</p>
          <p class="text-xs text-zinc-500 truncate">${escHtml(user.email)}</p>
        </div>
      </div>
    </div>` : ''

  const mobileAccountLinks = user ? `
    <div class="mt-4 pt-4 border-t border-white/5">
      <a href="${b}my.html" class="block px-3 py-3 text-sm font-medium text-zinc-300 hover:text-lime-400 hover:bg-zinc-900 rounded transition-colors">내 매물 / 프로필</a>
      <a href="${b}account.html" class="block px-3 py-3 text-sm font-medium text-zinc-300 hover:text-lime-400 hover:bg-zinc-900 rounded transition-colors">계정 설정</a>
    </div>` : ''

  const mobileAuth = user ? `
    <a href="${b}new-listing.html" class="flex items-center justify-center gap-2 w-full bg-lime-400 text-black text-sm font-bold py-3 rounded hover:bg-lime-300 transition-colors">
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4"/></svg>
      매물 등록
    </a>
    <button onclick="doSignOut()" class="w-full text-center text-sm text-zinc-600 hover:text-red-400 py-2.5 rounded transition-colors">로그아웃</button>
  ` : `
    <a href="${b}login.html" class="block w-full text-center bg-lime-400 text-black text-sm font-bold py-3 rounded hover:bg-lime-300 transition-colors">로그인</a>
    <a href="${b}signup.html" class="block w-full text-center border border-white/10 text-zinc-300 hover:text-white text-sm font-medium py-3 rounded hover:border-white/20 transition-colors">회원가입</a>
  `

  return `
    <header style="view-transition-name: site-header" class="sticky top-0 z-40 bg-black/60 backdrop-blur-[20px] border-b border-white/[0.06] shadow-lg shadow-black/20">
      <div class="flex items-center justify-between h-14 px-4 max-w-screen-xl mx-auto">
        <a href="${b}index.html" class="flex items-center gap-2 shrink-0">
          <span class="text-xl font-black text-lime-400 tracking-widest">LETEON</span>
          <span class="hidden sm:block text-xs text-zinc-600 font-medium">레테온</span>
        </a>
        <nav class="hidden md:flex items-center gap-5">
          ${CATEGORY_LIST.map(c => `<a href="${b}listings.html?category=${c}" class="text-sm text-zinc-400 hover:text-lime-400 transition-colors font-medium">${c}</a>`).join('')}
        </nav>
        <div class="hidden md:flex items-center gap-3">${desktopAuth}</div>
        <button id="menu-btn" class="md:hidden w-10 h-10 flex items-center justify-center text-zinc-400 hover:text-white transition-colors" aria-label="메뉴 열기">
          <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16"/></svg>
        </button>
      </div>
    </header>

    <div id="mobile-drawer" class="hidden fixed inset-0 z-50 md:hidden">
      <div id="drawer-bg" class="absolute inset-0 bg-black/60 backdrop-blur-sm"></div>
      <div class="absolute top-0 right-0 bottom-0 w-72 bg-zinc-900/90 backdrop-blur-[40px] border-l border-white/[0.08] flex flex-col shadow-2xl">
        <div class="flex items-center justify-between px-5 h-14 border-b border-white/[0.06] shrink-0">
          <span class="text-base font-black text-lime-400 tracking-widest">LETEON</span>
          <button id="close-btn" class="w-9 h-9 flex items-center justify-center text-zinc-500 hover:text-white rounded transition-colors" aria-label="닫기">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
          </button>
        </div>
        ${mobileUserInfo}
        <nav class="flex-1 overflow-y-auto px-3 py-4">
          <p class="px-3 pb-2 text-[10px] font-semibold text-zinc-600 uppercase tracking-wider">카테고리</p>
          ${CATEGORY_LIST.map(c => `<a href="${b}listings.html?category=${c}" class="block px-3 py-3 text-sm font-medium text-zinc-300 hover:text-lime-400 hover:bg-zinc-900 rounded transition-colors">${c}</a>`).join('')}
          <div class="mt-4 pt-4 border-t border-white/5">
            <a href="${b}listings.html" class="block px-3 py-3 text-sm font-medium text-zinc-300 hover:text-lime-400 hover:bg-zinc-900 rounded transition-colors">전체 매물</a>
          </div>
          ${mobileAccountLinks}
        </nav>
        <div class="shrink-0 px-3 pb-8 pt-3 border-t border-white/[0.06] space-y-2">${mobileAuth}</div>
      </div>
    </div>`
}

// ── Footer ───────────────────────────────────────────────────────────────────
function renderFooter() {
  const b = base()
  const year = new Date().getFullYear()
  return `
    <footer class="bg-black/60 backdrop-blur-[20px] border-t border-white/[0.06] mt-auto">
      <div class="max-w-screen-xl mx-auto px-4 pt-10 pb-6">
        <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-10">
          <div class="shrink-0">
            <span class="text-xl font-black text-lime-400 tracking-widest">LETEON</span>
            <p class="mt-1 text-sm text-zinc-400 font-medium">레테온</p>
            <p class="mt-3 text-sm text-zinc-500 leading-relaxed">MTB · eMTB · eBike · Parts<br>중고 바이크 C2C 직거래 플랫폼</p>
            <p class="mt-3 text-xs text-zinc-600">레테온은 통신판매중개업자로서 거래 당사자가<br>아니며, 회원 간 거래에 대한 책임은 판매자에게 있습니다.</p>
          </div>
          <div class="flex flex-wrap gap-10 sm:gap-16">
            <div>
              <p class="text-xs font-bold text-zinc-500 uppercase tracking-[0.15em] mb-4">카테고리</p>
              <ul class="space-y-2.5">${CATEGORY_LIST.map(c => `<li><a href="${b}listings.html?category=${c}" class="text-sm text-zinc-400 hover:text-lime-400 transition-colors">${c}</a></li>`).join('')}</ul>
            </div>
            <div>
              <p class="text-xs font-bold text-zinc-500 uppercase tracking-[0.15em] mb-4">이용</p>
              <ul class="space-y-2.5">
                <li><a href="${b}listings.html" class="text-sm text-zinc-400 hover:text-lime-400 transition-colors">전체 매물</a></li>
                <li><a href="${b}new-listing.html" class="text-sm text-zinc-400 hover:text-lime-400 transition-colors">매물 등록</a></li>
                <li><a href="${b}my.html" class="text-sm text-zinc-400 hover:text-lime-400 transition-colors">내 계정</a></li>
              </ul>
            </div>
            <div>
              <p class="text-xs font-bold text-zinc-500 uppercase tracking-[0.15em] mb-4">정책</p>
              <ul class="space-y-2.5">
                <li><a href="${b}terms.html" class="text-sm text-zinc-400 hover:text-lime-400 transition-colors">이용약관</a></li>
                <li><a href="${b}privacy.html" class="text-sm text-zinc-400 hover:text-lime-400 transition-colors">개인정보처리방침</a></li>
                <li><a href="mailto:leteon2026@gmail.com" class="text-sm text-zinc-400 hover:text-lime-400 transition-colors">문의하기</a></li>
              </ul>
            </div>
          </div>
        </div>
        <div class="mt-8 pt-6 border-t border-white/[0.06] flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <p class="text-xs text-zinc-600">&copy; ${year} LETEON 레테온. All rights reserved.</p>
          <div class="flex items-center gap-4">
            <a href="${b}terms.html" class="text-xs text-zinc-600 hover:text-zinc-400 transition-colors">이용약관</a>
            <span class="text-zinc-800">·</span>
            <a href="${b}privacy.html" class="text-xs text-zinc-600 hover:text-zinc-400 transition-colors font-semibold">개인정보처리방침</a>
          </div>
        </div>
      </div>
    </footer>`
}

// ── Init ──────────────────────────────────────────────────────────────────────
async function initPage() {
  try {
    const user = await getUser()
    window._leteonUser = user
    let profile = null
    if (user) profile = await getProfile(user.id)
    window._leteonProfile = profile

    const headerEl = document.getElementById('header-placeholder')
    const footerEl = document.getElementById('footer-placeholder')
    if (headerEl) headerEl.innerHTML = renderHeader(user, profile)
    if (footerEl) footerEl.innerHTML = renderFooter()

    const drawer = document.getElementById('mobile-drawer')
    const openDrawer = () => { drawer?.classList.remove('hidden'); document.body.style.overflow = 'hidden' }
    const closeDrawer = () => { drawer?.classList.add('hidden'); document.body.style.overflow = '' }
    document.getElementById('menu-btn')?.addEventListener('click', openDrawer)
    document.getElementById('close-btn')?.addEventListener('click', closeDrawer)
    document.getElementById('drawer-bg')?.addEventListener('click', closeDrawer)

    return { user, profile }
  } catch (e) {
    console.error('initPage error:', e)
    const headerEl = document.getElementById('header-placeholder')
    const footerEl = document.getElementById('footer-placeholder')
    if (headerEl) headerEl.innerHTML = renderHeader(null, null)
    if (footerEl) footerEl.innerHTML = renderFooter()
    return { user: null, profile: null }
  }
}

// ── Shared CSS template ───────────────────────────────────────────────────────
// (injected in each page)
