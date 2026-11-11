// ==UserScript==
// @name         VSCloudPhone — Auto Trial Provisioner v2.2
// @namespace    https://vscloudphone.com/
// @version      2.2.0
// @description  Tự động lấy trial VSCloudPhone: tạo mail tạm → đăng ký → OTP → đăng nhập → chờ pod
// @match        *://*.vscloudphone.com/*
// @match        *://*.vsphone.com/*
// @match        *://cloud.vsphone.com/*
// @noframes
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_xmlhttpRequest
// @grant        GM_setClipboard
// @connect      api.mail.tm
// @connect      api.mail.gw
// ==/UserScript==

(function () {
  'use strict';

  // ─────────────────────────────────────────────
  //  CONFIG
  // ─────────────────────────────────────────────
  const CFG = {
    defaultPass : 'Shop@TeddyIsLazy',
    adminLink   : 'https://discord.com/users/1548238180526981171',
    cloudUrl    : 'https://cloud.vsphone.com/?channel=web',
    otpTimeout  : 300_000,   
    captchaHardTimeout: 60_000, 
    podReadyTimeout: 60_000,
    stepDelay   : 600,
    otpBtnRetry : 20,        
  };

  // ─────────────────────────────────────────────
  //  STATE
  // ─────────────────────────────────────────────
  let running   = false;
  let runId     = 0;
  let mailApi   = 'mail.tm';
  let tempEmail = '';
  let mailToken = '';
  let currentPass = CFG.defaultPass;
  let accWatcherInterval = null; // Fix memory leak

  const isMKPage = /^(www\.)?vsphone\.com$/i.test(location.hostname);

  // ─────────────────────────────────────────────
  //  UTILS & CLICK LOGIC
  // ─────────────────────────────────────────────
  const sl  = ms => new Promise(r => setTimeout(r, ms));
  const nz  = s  => (s || '').normalize('NFC').replace(/\s+/g,' ').trim().toLowerCase();

  const vis = el => {
    if (!el || !el.isConnected) return false;
    const s = getComputedStyle(el);
    if (s.display === 'none' || s.visibility === 'hidden' || s.opacity === '0') return false;
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  };

  // TreeWalker Text-based Finder (Từ script mẫu)
  const fT = (arr, ex = false) => {
    const w = document.createTreeWalker(document.body, 4); // SHOW_TEXT
    let n;
    while ((n = w.nextNode())) {
      const v = n.nodeValue;
      if (!v || v.length > 120) continue;
      const p = n.parentElement;
      if (!p || p.closest('#vscp-panel') || /^(SCRIPT|STYLE|NOSCRIPT)$/.test(p.tagName)) continue;
      const t = nz(v).replace(/ ?\/ ?/g, '/');
      const hit = ex ? arr.includes(t) : arr.some(a => t.includes(a) && t.length <= a.length + 30);
      if (hit && vis(p)) return p;
    }
    return null;
  };

  // Closest Clickable (Từ script mẫu)
  const clk = el => el.closest('button,a,[role="button"]') || el;

  // TouchEvent Click Logic (Từ script mẫu - Fix lỗi React/Vue)
  const tC = async (el) => {
    try { el.scrollIntoView({ behavior: "smooth", block: "center" }); } catch (e) {}
    await sl(300);
    try {
      const r = el.getBoundingClientRect();
      const t = new Touch({ 
        identifier: Date.now(), 
        target: el, 
        clientX: r.left + r.width / 2, 
        clientY: r.top + r.height / 2, 
        radiusX: 2.5, 
        radiusY: 2.5, 
        rotationAngle: 10, 
        force: 1 
      });
      el.dispatchEvent(new TouchEvent('touchstart', { cancelable: true, bubbles: true, touches: [t], targetTouches: [t], changedTouches: [t] }));
      el.dispatchEvent(new TouchEvent('touchend', { cancelable: true, bubbles: true, touches: [], targetTouches: [], changedTouches: [t] }));
    } catch (e) {}
    if (el.click) el.click();
  };

  const setVal = (el, v) => {
    try { el.focus(); } catch (_) {}
    try {
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(el, v);
    } catch (_) { el.value = v; }
    el.dispatchEvent(new Event('input',  { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    el.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
  };

  const isEnabled = el =>
    el.isConnected &&
    !el.disabled &&
    el.getAttribute('aria-disabled') !== 'true' &&
    getComputedStyle(el).pointerEvents !== 'none';

  // ─────────────────────────────────────────────
  //  DOM FINDERS
  // ─────────────────────────────────────────────
  const LOGIN_TEXTS   = ['đăng nhập/đăng ký','đăng nhập','sign in','login','log in'];
  const OTP_TEXTS     = ['nhận mã xác minh','nhận mã xác nhận','gửi mã xác minh','gửi mã xác nhận','get verification code','send verification code','send code','get code','get otp','send otp'];
  const REG_TEXTS     = ['đăng ký và đăng nhập','đăng ký','register','create account','sign up'];
  const CONFIRM_TEXTS = ['xác nhận','đăng nhập','confirm','submit'];

  const findLoginBtn   = () => fT(LOGIN_TEXTS, true) ? clk(fT(LOGIN_TEXTS, true)) : null;
  const findOtpBtn     = () => fT(OTP_TEXTS) ? clk(fT(OTP_TEXTS)) : null;
  const findRegBtn     = () => fT(REG_TEXTS) ? clk(fT(REG_TEXTS)) : (fT(CONFIRM_TEXTS, true) ? clk(fT(CONFIRM_TEXTS, true)) : null);

  // Fix lỗi 2 ô Email (Email + Confirm Email)
  const findEmailInputs = () => {
    return Array.from(document.querySelectorAll(
      'input[type="email"], input[name*="email" i], input[placeholder*="mail" i], input[placeholder*="email" i], input[placeholder*="thư" i]'
    )).filter(vis);
  };

  const findPasswordFields = () => {
    const all = Array.from(document.querySelectorAll('input[type="password"]')).filter(vis);
    if (all.length === 0) return { pass: null, confirm: null };
    if (all.length === 1) return { pass: all[0], confirm: null };
    const confirmField = all.find(el => {
      const h = (el.placeholder + el.name + el.id + (el.getAttribute('aria-label') || '')).toLowerCase();
      return /confirm|re.?enter|nhập lại|repeat|verify/i.test(h);
    });
    if (confirmField) {
      return { pass: all.find(el => el !== confirmField), confirm: confirmField };
    }
    return { pass: all[0], confirm: all[1] };
  };

  // Fix lỗi tick nhầm Checkbox
  const findTermsCheckbox = () => {
    const all = Array.from(document.querySelectorAll('input[type="checkbox"]')).filter(vis);
    return all.find(el => {
      const label = document.querySelector(`label[for="${el.id}"]`) || el.closest('label') || el.parentElement;
      if (!label) return false;
      const t = nz(label.innerText || label.textContent || '');
      return /terms|agreement|điều khoản|chính sách|privacy|policy|agree/i.test(t);
    }) || null;
  };

  // Fix Regex bắt OTP (Ưu tiên chuỗi 6 số nằm gần chữ "mã", "code")
  const extractOtp = text => {
    const matches = [...text.matchAll(/(?<!\d)(\d{6})(?!\d)/g)].map(m => m[1]);
    // Lọc năm (19xx, 20xx) trừ khi có chữ "mã" sát bên
    const valid = matches.filter(n => !/^(19|20)\d{2}$/.test(n));
    return valid.length > 0 ? valid[0] : (matches.length > 0 ? matches[0] : null);
  };

  const CAPTCHA_SEL = [
    'iframe[src*="captcha" i]','iframe[src*="cloudflare" i]','iframe[src*="geetest" i]',
    'iframe[src*="hcaptcha" i]','iframe[src*="recaptcha" i]',
    '.cf-turnstile','#challenge-form','#cf-challenge-running',
    '[class*="geetest" i]','[class*="turnstile" i]','[class*="recaptcha" i]'
  ].join(',');

  const hasCaptcha = () => {
    try {
      return Array.from(document.querySelectorAll(CAPTCHA_SEL)).some(el => {
        if (el.closest('#vscp-panel') || !vis(el)) return false;
        const r = el.getBoundingClientRect();
        return r.bottom > 0 && r.right > 0 && r.top < window.innerHeight && r.left < window.innerWidth;
      });
    } catch (_) { return false; }
  };

  const findOtpInput = () => {
    const inputs = Array.from(document.querySelectorAll('input')).filter(
      i => vis(i) && !['password','checkbox','radio','hidden','submit','button','email'].includes(i.type)
    );
    return inputs.find(i => /mã xác|xác nhận|xác minh|otp|verif|code/i.test(i.placeholder + i.name + i.id)) || inputs.find(i => i.maxLength >= 4 && i.maxLength <= 8) || null;
  };

  const isLoggedIn = () =>
    !!(document.querySelector('[class*="podList" i],[class*="dashboard" i],[class*="myDevice" i],[class*="device-card" i]')) 
    || (!findLoginBtn() && findEmailInputs().length === 0);

  const waitForNoLogin = async (timeout = 3000) => {
    const t0 = Date.now();
    while (Date.now() - t0 < timeout) {
      if (!findLoginBtn() && findEmailInputs().length === 0) return true;
      await sl(400);
    }
    return false;
  };

  const submitForm = async el => {
    const form = el.closest('form');
    if (form && typeof form.requestSubmit === 'function') {
      try { form.requestSubmit(); return; } catch (_) {}
    }
    const submitBtn = form ? form.querySelector('button[type="submit"], input[type="submit"]') : null;
    if (submitBtn && vis(submitBtn)) { await tC(submitBtn); return; }
    await tC(el);
  };

  // ─────────────────────────────────────────────
  //  HTTP & MAIL
  // ─────────────────────────────────────────────
  const req = (url, method = 'GET', data = null, token = null) =>
    new Promise((res, rej) => {
      const headers = { 'Content-Type': 'application/json' };
      if (token) headers['Authorization'] = 'Bearer ' + token;
      GM_xmlhttpRequest({
        method, url, headers,
        data: data ? JSON.stringify(data) : null,
        timeout: 20_000,
        onload    : r => { try { res(JSON.parse(r.responseText)); } catch (_) { res(r.responseText); } },
        onerror   : () => rej(new Error('Lỗi mạng - thử bật VPN')),
        ontimeout : () => rej(new Error('Request timeout - thử bật VPN')),
      });
    });

  const createTempMail = async () => {
    log('Lấy domain mail...', 'info');
    let domains;
    try {
      domains = await req('https://api.mail.tm/domains');
      mailApi = 'mail.tm';
    } catch (_) {
      domains = await req('https://api.mail.gw/domains');
      mailApi = 'mail.gw';
    }
    if (!domains?.['hydra:member']?.length) throw new Error('Không lấy được domain mail');

    const domain = domains['hydra:member'][0].domain;
    const user   = `vscp_${Math.random().toString(36).slice(2, 11)}`;
    tempEmail    = `${user}@${domain}`;

    await req(`https://api.${mailApi}/accounts`, 'POST', { address: tempEmail, password: currentPass });
    const tokenRes = await req(`https://api.${mailApi}/token`, 'POST', { address: tempEmail, password: currentPass });
    if (!tokenRes?.token) throw new Error('Không lấy được token mail');
    mailToken = tokenRes.token;
    log(`Email tạm: ${tempEmail}`, 'ok');
  };

  // Fix Bug Token hết hạn
  const refreshMailToken = async () => {
    try {
      const tokenRes = await req(`https://api.${mailApi}/token`, 'POST', { address: tempEmail, password: currentPass });
      if (tokenRes?.token) {
        mailToken = tokenRes.token;
        log('Đã làm mới token mail.', 'info');
      }
    } catch (_) {}
  };

  const pollOtp = async () => {
    try {
      const msgs = await req(`https://api.${mailApi}/messages`, 'GET', null, mailToken);
      if (msgs && msgs['hydra:member']) {
        const list = msgs['hydra:member'];
        if (!list.length) return null;
        const full = await req(`https://api.${mailApi}/messages/${list[0].id}`, 'GET', null, mailToken);
        const html = Array.isArray(full.html) ? full.html.join(' ') : (full.html || '');
        const text = (full.text || '') + ' ' + html.replace(/<(style|script)[\s\S]*?<\/\1>/gi, ' ').replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ');
        return extractOtp(text);
      }
    } catch (e) {
      // Nếu lỗi (vd: 401), thử làm mới token
      await refreshMailToken();
    }
    return null;
  };

  // ─────────────────────────────────────────────
  //  PROVISIONING FLOW
  // ─────────────────────────────────────────────
  const runFlow = async (id) => {
    const ck = () => { if (!running || runId !== id) throw new Error('STOP'); };
    const wt = async ms => { await sl(ms); ck(); };

    log('Tìm ô nhập email...', 'info');
    let emailInputs = findEmailInputs();
    if (emailInputs.length === 0) {
      const btn = findLoginBtn();
      if (btn) { await tC(btn); await wt(2000); }
      emailInputs = findEmailInputs();
      if (emailInputs.length === 0) throw new Error('Không tìm thấy ô nhập email');
    }
    
    // Fix Bug 2 ô Email
    for (const inp of emailInputs) {
      setVal(inp, tempEmail);
    }
    log(`Điền email: ${tempEmail}`, 'ok');
    await wt(CFG.stepDelay);

    const cb = findTermsCheckbox();
    if (cb && !cb.checked) {
      // Fix double toggle: click thẳng vào thẻ input
      await tC(cb);
      await wt(300);
      log('Đã tick checkbox điều khoản', 'ok');
    }

    if (!findOtpBtn()) {
      const submitBtn = Array.from(document.querySelectorAll('button[type="submit"]')).find(vis) || findLoginBtn();
      if (submitBtn) { await submitForm(submitBtn); await wt(2000); }
    }

    log('Tìm nút Nhận mã xác minh...', 'info');
    let otpBtn = null;
    let otpClicked = false;

    for (let i = 0; i < CFG.otpBtnRetry; i++) {
      const p = findOtpBtn();
      if (p) {
        otpBtn = p;
        if (!isEnabled(otpBtn)) {
          log(`Nút OTP disabled, chờ... (${i+1}/${CFG.otpBtnRetry})`, 'info');
          await wt(500);
          continue;
        }
        await tC(otpBtn); // Dùng TouchEvent
        log(`Đã click nút OTP (lần ${i+1})`, 'ok');
        otpClicked = true;
        break;
      }
      log(`Chưa thấy nút OTP (${i+1}/${CFG.otpBtnRetry})...`, 'info');
      await wt(500);
    }
    if (!otpClicked) throw new Error('Không tìm thấy / không click được nút Nhận mã xác minh');

    log('Chờ OTP trong mail...', 'info');
    let otp = null;
    let captchaShown = false;
    let captchaStart = 0;
    let hintShown = false;
    const tOtp = Date.now();

    while (Date.now() - tOtp < CFG.otpTimeout) {
      await wt(2000);
      ck();

      const cap = hasCaptcha(); 
      if (cap && !captchaShown) {
        captchaShown = true;
        captchaStart = Date.now();
        log('⚠️ CAPTCHA! Giải tay rồi bot tự điền OTP...', 'warn');
        setStatus('⚠️ Đang chờ bạn giải CAPTCHA...');
        minimizeToIcon(true);
      } else if (!cap && captchaShown) {
        captchaShown = false;
        minimizeToIcon(false);
        log('✔ CAPTCHA xong — đang poll mail...', 'ok');
        setStatus('Đang chờ OTP...');
      }

      if (captchaShown && Date.now() - captchaStart > CFG.captchaHardTimeout) {
        log('CAPTCHA quá 60s — thử click lại nút OTP...', 'warn');
        minimizeToIcon(false);
        captchaShown = false;
        const retryBtn = findOtpBtn();
        if (retryBtn && isEnabled(retryBtn)) { await tC(retryBtn); }
        captchaStart = Date.now();
      }

      try { otp = await pollOtp(); } catch (_) {}
      if (otp) break;

      if (!hintShown && !captchaShown && Date.now() - tOtp > 25_000) {
        hintShown = true;
        log('Chưa thấy mail OTP — bấm tay nút Nhận mã, bot vẫn tự điền.', 'info');
      }
    }

    minimizeToIcon(false);
    if (!otp) throw new Error('Không lấy được OTP (timeout)');
    log(`OTP: ${otp}`, 'ok');

    const otpInput = findOtpInput();
    if (otpInput) {
      setVal(otpInput, otp);
    } else {
      const boxes = Array.from(document.querySelectorAll('input')).filter(
        i => vis(i) && i.maxLength === 1 && !['password','checkbox','radio','hidden'].includes(i.type)
      );
      if (boxes.length >= otp.length) {
        for (let j = 0; j < boxes.length && j < otp.length; j++) {
          setVal(boxes[j], otp[j]);
          await wt(80);
        }
      } else {
        const all = Array.from(document.querySelectorAll('input')).filter(
          i => vis(i) && !['password','checkbox','radio','hidden','email','submit','button'].includes(i.type)
        );
        const fallback = all.find(i => i !== emailInputs[0]);
        if (!fallback) throw new Error('Không tìm thấy ô nhập OTP');
        setVal(fallback, otp);
      }
    }

    const { pass: passField, confirm: confirmField } = findPasswordFields();
    if (passField)    setVal(passField, currentPass);
    if (confirmField) setVal(confirmField, currentPass);
    await wt(CFG.stepDelay);

    const regBtn = findRegBtn();
    if (!regBtn) throw new Error('Không tìm thấy nút Đăng ký & Đăng nhập');

    saveAcc(tempEmail, currentPass);
    await submitForm(regBtn); 
    log('Đã bấm đăng ký/đăng nhập', 'ok');

    log('Chờ pod provisioning...', 'info');
    setStatus('Đang chờ pod khởi tạo...');
    let podReady = false;
    const tPod = Date.now();
    while (Date.now() - tPod < CFG.podReadyTimeout) {
      await wt(1000); ck();
      if (await waitForNoLogin(1000)) { podReady = true; break; }
      if (document.querySelector('[class*="podReady" i],[class*="connected" i],[class*="streaming" i]')) {
        podReady = true; break;
      }
    }
    if (!podReady) {
      removeAcc(tempEmail);
      throw new Error('Pod không sẵn sàng hoặc đăng nhập thất bại');
    }

    return { email: tempEmail, password: currentPass };
  };

  // ─────────────────────────────────────────────
  //  ACC STORAGE
  // ─────────────────────────────────────────────
  const saveAcc = (email, pass) => {
    const list = GM_getValue('vscp_accounts', []);
    if (!list.find(a => a.email === email)) {
      list.push({ email, password: pass, ts: Date.now() });
      GM_setValue('vscp_accounts', list);
    }
    renderAccList();
  };

  const removeAcc = email => {
    GM_setValue('vscp_accounts', GM_getValue('vscp_accounts', []).filter(a => a.email !== email));
    renderAccList();
  };

  const renderAccList = () => {
    const el = document.getElementById('vscp-acc-list');
    if (!el) return;
    const list = GM_getValue('vscp_accounts', []);
    if (!list.length) { el.innerHTML = '<span class="vscp-empty">Chưa có acc nào</span>'; return; }
    el.innerHTML = list.map((a, i) => `
      <div class="vscp-acc-row">
        <span class="vscp-acc-num">${i + 1}</span>
        <span class="vscp-acc-email" title="${a.email}">${a.email}</span>
        <span class="vscp-acc-copy" data-val="${a.email}">📋</span>
        <span class="vscp-acc-del"  data-email="${a.email}">🗑</span>
      </div>`).join('');
    el.querySelectorAll('.vscp-acc-copy').forEach(b => {
      b.onclick = e => { e.stopPropagation(); GM_setClipboard(b.dataset.val); log('Copied: ' + b.dataset.val, 'ok'); };
    });
    el.querySelectorAll('.vscp-acc-del').forEach(b => {
      b.onclick = e => { e.stopPropagation(); removeAcc(b.dataset.email); };
    });
  };

  // ─────────────────────────────────────────────
  //  ENTRY
  // ─────────────────────────────────────────────
  const start = async () => {
    if (running) return;

    const passInput = document.getElementById('vscp-pass-input');
    currentPass = (passInput?.value?.trim()) || CFG.defaultPass;

    running = true;
    const id = ++runId;
    document.getElementById('vscp-start-btn').style.display = 'none';
    document.getElementById('vscp-stop-btn').style.display  = 'block';
    setStatus('Đang chạy...');

    try {
      if (isMKPage && !findLoginBtn() && findEmailInputs().length === 0) {
        log('Không thấy login UI — chuyển cloud...', 'info');
        location.replace(CFG.cloudUrl); return;
      }
      if (isLoggedIn()) {
        log('Đã đăng nhập rồi!', 'ok');
        setStatus('Đã đăng nhập!');
        stop(); return;
      }

      await createTempMail();
      const acc = await runFlow(id);

      log(`✅ Done! Email: ${acc.email}`, 'ok');
      setStatus('Thành công! Pod đang khởi tạo...');
    } catch (e) {
      if (runId !== id) return;
      log('Lỗi: ' + (e.message || String(e)), 'err');
      setStatus('Lỗi — xem log');
    } finally {
      stop();
    }
  };

  const stop = () => {
    running = false; runId++;
    minimizeToIcon(false);
    const sb = document.getElementById('vscp-start-btn');
    const xb = document.getElementById('vscp-stop-btn');
    if (sb) sb.style.display = 'block';
    if (xb) xb.style.display = 'none';
  };

  // ─────────────────────────────────────────────
  //  UI
  // ─────────────────────────────────────────────
  let _minimized = false;
  let _autoMin   = false;

  const minimizeToIcon = force => {
    if (force) { _autoMin = true;  applyMin(true);  }
    else if (_autoMin) { _autoMin = false; applyMin(false); }
  };

  const applyMin = m => {
    _minimized = m;
    const panel  = document.getElementById('vscp-panel');
    const body   = document.getElementById('vscp-body');
    const hdr    = document.getElementById('vscp-header');
    const title  = hdr?.querySelector('.vscp-title');
    const minBtn = document.getElementById('vscp-min');
    const closeBtn = document.getElementById('vscp-close');
    if (!panel) return;
    if (m) {
      body.style.display    = 'none';
      if (title)  title.style.display = 'none';
      closeBtn.style.display = 'none';
      Object.assign(panel.style, { width:'52px', height:'52px', borderRadius:'50%',
        overflow:'hidden', background:'linear-gradient(135deg,#00e5ff,#7c3aed)',
        boxShadow:'0 0 24px rgba(0,229,255,.7)' });
      Object.assign(hdr.style, { height:'100%', borderRadius:'50%', padding:'0',
        justifyContent:'center', border:'none', background:'transparent', cursor:'pointer' });
      minBtn.textContent = '⚡';
      Object.assign(minBtn.style, { fontSize:'26px', color:'#fff', pointerEvents:'none' });
    } else {
      body.style.display    = 'block';
      if (title)  title.style.display = 'block';
      closeBtn.style.display = 'block';
      Object.assign(panel.style, { width:'340px', height:'auto', borderRadius:'14px',
        overflow:'visible', background:'rgba(8,6,20,.97)',
        boxShadow:'0 0 20px rgba(0,229,255,.3),0 4px 32px rgba(0,0,0,.8)' });
      hdr.style.cssText = `padding:11px 14px;background:rgba(0,229,255,.07);
        border-bottom:1px solid rgba(0,229,255,.25);border-radius:14px 14px 0 0;
        display:flex;justify-content:space-between;align-items:center;
        cursor:move;touch-action:none;`;
      minBtn.textContent = '—';
      Object.assign(minBtn.style, { fontSize:'16px', color:'#00e5ff', pointerEvents:'auto' });
    }
  };

  const log = (msg, type = 'info') => {
    const el = document.getElementById('vscp-log');
    if (!el) return;
    const cls = type === 'ok' ? 'vscp-ok' : type === 'err' ? 'vscp-err' : type === 'warn' ? 'vscp-warn' : 'vscp-info';
    el.innerHTML += `<div class="${cls}">[${new Date().toLocaleTimeString('vi-VN')}] ${msg}</div>`;
    el.scrollTop = el.scrollHeight;
  };

  const setStatus = msg => {
    const el = document.getElementById('vscp-status');
    if (!el) return;
    el.style.display = msg ? 'block' : 'none';
    el.textContent = msg || '';
  };

  const buildUI = () => {
    const panel = document.createElement('div');
    panel.id = 'vscp-panel';
    panel.innerHTML = `
<style>
#vscp-panel{position:fixed;top:18px;right:18px;width:340px;background:rgba(8,6,20,.97);
  border:1.5px solid rgba(0,229,255,.35);border-radius:14px;z-index:2147483647;
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif;
  box-shadow:0 0 20px rgba(0,229,255,.3),0 4px 32px rgba(0,0,0,.8);
  color:#e8e8f0;user-select:none;transition:width .25s,height .25s,border-radius .25s}
#vscp-header{padding:11px 14px;background:rgba(0,229,255,.07);
  border-bottom:1px solid rgba(0,229,255,.25);border-radius:14px 14px 0 0;
  display:flex;justify-content:space-between;align-items:center;cursor:move;touch-action:none}
.vscp-title{font-size:13px;font-weight:700;letter-spacing:.4px;
  background:linear-gradient(90deg,#00e5ff,#a78bfa);
  -webkit-background-clip:text;-webkit-text-fill-color:transparent}
.vscp-hbtn{cursor:pointer;font-size:15px;padding:0 4px;margin-left:6px;
  color:rgba(255,255,255,.55);transition:color .15s;touch-action:manipulation}
.vscp-hbtn:hover{color:#fff}#vscp-close:hover{color:#ff4444}
#vscp-body{padding:12px}
#vscp-status{font-size:11px;font-weight:600;text-align:center;color:#fbbf24;
  padding:5px 8px;margin-bottom:8px;background:rgba(251,191,36,.08);border-radius:6px;display:none}
.vscp-btn{width:100%;padding:10px;border:none;border-radius:8px;font-weight:700;
  font-size:13px;cursor:pointer;color:#fff;margin-bottom:8px;letter-spacing:.3px;transition:opacity .15s}
.vscp-btn:active{opacity:.8}
#vscp-start-btn{background:linear-gradient(90deg,#00b4d8,#7c3aed)}
#vscp-stop-btn{background:#dc2626}
#vscp-cfg-row{display:grid;grid-template-columns:1fr;gap:6px;margin-bottom:10px}
.vscp-cfg-label{font-size:10px;color:rgba(255,255,255,.4);margin-bottom:2px;letter-spacing:.3px}
.vscp-input-group{display:flex;gap:5px}
.vscp-input{width:100%;background:rgba(255,255,255,.05);border:1px solid rgba(0,229,255,.2);
  border-radius:6px;color:#e8e8f0;font-size:11px;padding:5px 7px;
  box-sizing:border-box;outline:none;transition:border-color .15s}
.vscp-input:focus{border-color:rgba(0,229,255,.6)}
.vscp-copy-btn{background:#00e5ff;color:#000;border:none;border-radius:6px;
  padding:0 10px;cursor:pointer;font-weight:bold;font-size:14px;transition:opacity .15s}
.vscp-copy-btn:hover{opacity:.8}
#vscp-log{height:140px;overflow-y:auto;background:rgba(0,0,0,.4);
  border:1px solid rgba(255,255,255,.07);border-radius:8px;padding:7px 9px;
  font-size:10.5px;font-family:'Cascadia Code','Fira Code',monospace;
  color:rgba(255,255,255,.5);margin-bottom:9px;scroll-behavior:smooth}
#vscp-log div{line-height:1.6}
.vscp-ok{color:#34d399}.vscp-err{color:#f87171}.vscp-warn{color:#fbbf24}.vscp-info{color:#60a5fa}
.vscp-divider{display:flex;align-items:center;gap:7px;margin-bottom:7px}
.vscp-divider span:not(.vscp-dl){flex:1;height:1px;background:rgba(255,255,255,.08)}
.vscp-dl{font-size:10px;color:rgba(255,255,255,.3);white-space:nowrap}
#vscp-acc-list{max-height:90px;overflow-y:auto;background:rgba(0,0,0,.3);
  border:1px solid rgba(255,255,255,.07);border-radius:8px;padding:6px 8px;font-size:10.5px}
.vscp-empty{color:rgba(255,255,255,.25)}
.vscp-acc-row{display:flex;align-items:center;gap:5px;padding:2px 0;
  border-bottom:1px solid rgba(255,255,255,.04)}
.vscp-acc-row:last-child{border-bottom:none}
.vscp-acc-num{color:rgba(255,255,255,.25);min-width:14px;font-size:10px}
.vscp-acc-email{flex:1;color:#a5f3fc;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.vscp-acc-copy,.vscp-acc-del{cursor:pointer;opacity:.6;transition:opacity .15s;font-size:11px}
.vscp-acc-copy:hover,.vscp-acc-del:hover{opacity:1}
.vscp-acc-toolbar{display:flex;justify-content:space-between;align-items:center;margin-bottom:4px}
.vscp-acc-toolbar span:first-child{font-size:10px;color:rgba(255,255,255,.3)}
.vscp-clear-btn{font-size:10px;color:#f87171;cursor:pointer}
#vscp-panel ::-webkit-scrollbar{width:4px}
#vscp-panel ::-webkit-scrollbar-thumb{background:rgba(0,229,255,.2);border-radius:4px}
</style>
<div id="vscp-header">
  <span class="vscp-title">⚡ VSCloudPhone Auto</span>
  <div style="display:flex;align-items:center;">
    <span id="vscp-min"   class="vscp-hbtn" title="Thu nhỏ">—</span>
    <span id="vscp-close" class="vscp-hbtn" title="Đóng">✕</span>
  </div>
</div>
<div id="vscp-body">
  <div id="vscp-status"></div>
  <div id="vscp-cfg-row">
    <div>
      <div class="vscp-cfg-label">PASSWORD</div>
      <input id="vscp-pass-input" class="vscp-input" type="text"
        placeholder="${CFG.defaultPass}" value="${CFG.defaultPass}" />
    </div>
    <div>
      <div class="vscp-cfg-label">ADMIN CONTACT</div>
      <div class="vscp-input-group">
        <input id="vscp-admin-input" class="vscp-input" type="text" readonly
          value="${CFG.adminLink}" style="color: #a5f3fc;" />
        <button id="vscp-copy-admin" class="vscp-copy-btn" title="Copy Link">📋</button>
      </div>
    </div>
  </div>
  <button id="vscp-start-btn" class="vscp-btn">▶ BẮT ĐẦU</button>
  <button id="vscp-stop-btn"  class="vscp-btn" style="display:none">■ DỪNG</button>
  <div id="vscp-log"></div>
  <div class="vscp-divider"><span></span><span class="vscp-dl">Danh sách Acc</span><span></span></div>
  <div class="vscp-acc-toolbar">
    <span>Tổng: <span id="vscp-acc-count">0</span></span>
    <span class="vscp-clear-btn" id="vscp-clear-btn">🗑 Xóa hết</span>
  </div>
  <div id="vscp-acc-list"><span class="vscp-empty">Chưa có acc nào</span></div>
</div>`;

    document.body.appendChild(panel);

    // ── Drag ────────────────────────────────────
    let drag = false, dX = 0, dY = 0, sX = 0, sY = 0;
    const hdr = document.getElementById('vscp-header');
    hdr.addEventListener('pointerdown', e => {
      if (e.target.closest('.vscp-hbtn')) return;
      drag = true; dX = e.clientX - panel.getBoundingClientRect().left;
      dY = e.clientY - panel.getBoundingClientRect().top; sX = e.clientX; sY = e.clientY;
      hdr.setPointerCapture(e.pointerId);
    });
    hdr.addEventListener('pointermove', e => {
      if (!drag) return;
      panel.style.left = (e.clientX - dX) + 'px';
      panel.style.top  = (e.clientY - dY) + 'px';
      panel.style.right = 'auto';
    });
    hdr.addEventListener('pointerup', e => {
      if (!drag) return; drag = false;
      if (_minimized && Math.hypot(e.clientX - sX, e.clientY - sY) < 6) {
        applyMin(false); _autoMin = false; return;
      }
      const r = panel.getBoundingClientRect();
      panel.style.left = Math.max(0, Math.min(r.left, innerWidth  - r.width))  + 'px';
      panel.style.top  = Math.max(0, Math.min(r.top,  innerHeight - r.height)) + 'px';
    });

    // ── Button Events ───────────────────────────
    document.getElementById('vscp-min').onclick   = e => { e.stopPropagation(); applyMin(true); };
    
    // Fix Memory Leak: clearInterval khi đóng
    document.getElementById('vscp-close').onclick  = () => { 
      running = false; runId++; 
      if (accWatcherInterval) clearInterval(accWatcherInterval);
      panel.remove(); 
    };
    
    document.getElementById('vscp-start-btn').onclick = start;
    document.getElementById('vscp-stop-btn').onclick  = stop;
    
    // Fix Copy Button
    document.getElementById('vscp-copy-admin').onclick = () => {
      GM_setClipboard(CFG.adminLink);
      log('Đã copy link Admin!', 'ok');
    };

    document.getElementById('vscp-clear-btn').onclick = () => {
      if (confirm('Xóa toàn bộ danh sách acc?')) {
        GM_setValue('vscp_accounts', []); renderAccList();
        log('Đã xóa toàn bộ acc', 'warn');
      }
    };

    accWatcherInterval = setInterval(() => {
      const c = document.getElementById('vscp-acc-count');
      if (c) c.textContent = GM_getValue('vscp_accounts', []).length;
    }, 2000);

    renderAccList();
  };

  // ─────────────────────────────────────────────
  //  BOOT
  // ─────────────────────────────────────────────
  const boot = () => {
    buildUI();
    
    // Status watcher
    setInterval(() => {
      if (running) return;
      if (findLoginBtn() || findEmailInputs().length > 0) setStatus('Sẵn sàng. Bấm BẮT ĐẦU.');
      else if (isLoggedIn()) setStatus('Đã đăng nhập!');
      else if (isMKPage) setStatus('Không thấy login UI — bấm BẮT ĐẦU để chuyển cloud.');
    }, 2500);

    if (isMKPage) {
      setStatus('Đang quét trang...');
      setTimeout(async () => {
        if (!findLoginBtn() && findEmailInputs().length === 0) {
          setStatus('Chuyển sang cloud.vsphone.com...');
          await sl(600);
          const last = +(GM_getValue('vscp_redirect_ts', 0) || 0);
          if (Date.now() - last > 20000) {
            GM_setValue('vscp_redirect_ts', Date.now());
            location.replace(CFG.cloudUrl);
          }
        }
      }, 1500);
    } else {
      log('Trang cloud phát hiện.', 'info'); 
      setStatus('Sẵn sàng. Bấm BẮT ĐẦU.');
    }
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else setTimeout(boot, 1200);

})();