/* رفيق · راديو — screens, remote keys and wiring between Sources, Player and Nav. */
(function () {
  "use strict";

  var $ = function (id) { return document.getElementById(id); };
  /* view: "stations" or "folder". listDesc/rows/full drive "load more";
     parent remembers the folder (countries or genres) a station list was opened from. */
  var state = { cat: null, view: "stations", list: [], loadingToken: 0, searchText: "",
                listDesc: null, rows: 0, full: false, folderItems: [], parent: null };
  var isTizen = !!(window.tizen && tizen.application);
  var isTvLayout = document.documentElement.classList.contains("tv");

  /* ---------- Tizen remote keys (needs the tv.inputdevice privilege in config.xml) ---------- */
  if (window.tizen && tizen.tvinputdevice) {
    ["ColorF0Red", "ColorF1Green", "ColorF2Yellow", "ColorF3Blue", "ChannelUp", "ChannelDown",
     "MediaPlayPause", "MediaPlay", "MediaPause", "MediaStop",
     "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"].forEach(function (k) {
      try { tizen.tvinputdevice.registerKey(k); } catch (e) { /* key not available on this model */ }
    });
  }

  /* ---------- helpers ---------- */
  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }
  function hue(s) { var h = 0; for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 360; return h; }
  function initial(name) {
    var n = name.replace(/^(إذاعة|راديو|radio)\s+/i, "").replace(/^ال/, "");
    var m = n.match(/[A-Za-z؀-ۿ]/);
    return m ? m[0].toUpperCase() : "♪";
  }
  function paintLogo(box, station) {
    box.textContent = "";
    box.style.background = "hsl(" + hue(station.label || station.name) + ",42%,64%)";
    box.textContent = station.badge || initial(station.label || station.name);
    if (station.logo && /^https:/.test(station.logo)) {
      var img = new Image();
      img.alt = "";
      img.onload = function () { box.textContent = ""; box.style.background = "#fff"; box.appendChild(img); };
      img.src = station.logo;
    }
  }
  function fmt(n) {
    var s = String(n), out = "";
    while (s.length > 3) { out = "," + s.slice(-3) + out; s = s.slice(0, -3); }
    return s + out;
  }
  var toastTimer;
  function toast(msg) {
    var t = $("toast"); t.textContent = msg; t.hidden = false;
    clearTimeout(toastTimer); toastTimer = setTimeout(function () { t.hidden = true; }, 2600);
  }
  function favIndex(id) {
    var f = Store.favorites();
    for (var i = 0; i < f.length; i++) if (f[i].id === id) return i;
    return -1;
  }

  /* ---------- categories ---------- */
  function renderCats() {
    var box = $("cats");
    Sources.categories.forEach(function (c) {
      var b = el("button", "cat");
      b.dataset.cat = c.id;
      b.appendChild(el("span", "ico", c.ico));
      b.appendChild(el("span", "", c.name));
      b.addEventListener("click", function () { openCat(c.id, true); });
      box.appendChild(b);
    });
  }

  function catMeta(id) { return Sources.categories.filter(function (c) { return c.id === id; })[0]; }

  function openCat(id, focusList) {
    state.cat = id;
    state.parent = null;
    showLocalFilter(false);
    var meta = catMeta(id);
    Array.prototype.forEach.call(document.querySelectorAll(".cat"), function (b) {
      b.classList.toggle("active", b.dataset.cat === id);
      /* On a phone the categories are a sideways strip: keep the chosen one in view. */
      if (b.dataset.cat === id && !isTvLayout) { try { b.scrollIntoView({ block: "nearest", inline: "nearest" }); } catch (e) {} }
    });
    $("list-title").textContent = meta.name;
    $("list-sub").textContent = meta.sub || "";
    $("search-row").hidden = id !== "search";
    $("grid").scrollTop = 0;

    if (id === "search") {
      state.view = "stations";
      renderList(state.searchText ? state.list : [], "اكتب اسم المحطة أو نوعها واضغط بحث. البحث في دليل Radio Browser العالمي.");
      if (focusList) Nav.focus($("search-input"));
      return;
    }
    var token = ++state.loadingToken;
    renderList(null);

    if (meta.folder) {
      state.view = "folder";
      Sources.folder(id).then(function (res) {
        if (token !== state.loadingToken) return;
        state.folderItems = res.items;
        renderFolder(res.items);
        if (res.source === "cache") $("list-sub").textContent = meta.sub + " · من آخر تحديث محفوظ";
        if (focusList) focusFirst();
      }, function () {
        if (token !== state.loadingToken) return;
        renderList([], "تعذّر تحميل القائمة الآن. تأكد من الإنترنت وحاول مرة أخرى.");
      });
      return;
    }

    state.view = "stations";
    Sources.load(id).then(function (res) {
      if (token !== state.loadingToken) return;
      var empty = id === "fav"
        ? "لا توجد محطات مفضلة بعد.\nاختر محطة واضغط الزر الأحمر أو «★ للمفضلة» لتظهر هنا وعلى أزرار الأرقام."
        : id === "recent" ? "لم تشغّل أي محطة بعد. المحطات التي تسمعها ستظهر هنا."
        : "تعذّر تحميل المحطات الآن. تأكد من الإنترنت وحاول مرة أخرى.";
      setPaging(res);
      renderList(res.stations, empty);
      if (res.source === "cache") $("list-sub").textContent = (meta.sub ? meta.sub + " · " : "") + "من آخر تحديث محفوظ";
      if (res.source === "seed" && id !== "fav" && id !== "recent") $("list-sub").textContent = "الدليل غير متاح الآن · قائمة أساسية";
      if (focusList) focusFirst();
    });
  }

  function setPaging(res) {
    state.listDesc = res.list && res.list.query != null ? res.list : null;
    state.rows = res.rows || 0;
    state.full = !!(res.full && state.listDesc);
  }

  function focusFirst() { var first = $("grid").querySelector(".st"); if (first) Nav.focus(first); }

  /* ---------- folders (countries, genres) ---------- */
  function renderFolder(items) {
    var grid = $("grid"), empty = $("empty"), lastGroup = null, cat = state.cat;
    grid.textContent = "";
    state.list = [];
    empty.hidden = items.length > 0;
    empty.textContent = "لا توجد عناصر.";
    var titles = cat === "arabic"
      ? { arab: "" }
      : cat === "countries"
      ? { world: "" }
      : { arab: "أنواع المحطات العربية", world: "أنواع من كل العالم" };
    items.forEach(function (it) {
      if (it.group !== lastGroup) {
        lastGroup = it.group;
        var gt = titles[it.group];
        if (gt) grid.appendChild(el("div", "group-title", gt));
      }
      var card = el("button", "st folder");
      card.setAttribute("role", "listitem");
      card.dataset.id = it.id;
      var logo = el("span", "logo" + (it.kind === "country" ? " flag" : ""));
      paintLogo(logo, { label: it.label, logo: it.logo, badge: it.kind === "country" ? it.code : "♫" });
      card.appendChild(logo);
      var meta = el("span", "meta");
      var nm = el("div", "name", it.label);
      /* Arabic genre counts come from a 500-station sample, so they are not shown as totals. */
      var countText = it.group === "arab" && it.kind === "genre" ? "" : fmt(it.count) + " محطة";
      var subText = [countText, it.sub && it.sub !== it.label ? it.sub : ""].filter(Boolean).join(" · ");
      var sub = el("div", "tags", subText);
      nm.dir = "auto"; sub.dir = "auto";
      meta.appendChild(nm); meta.appendChild(sub);
      card.appendChild(meta);
      card.addEventListener("click", function () { openFolderItem(it); });
      grid.appendChild(card);
    });
  }

  function openFolderItem(it) {
    var meta = catMeta(state.cat);
    state.parent = { cat: state.cat, items: state.folderItems, focusId: it.id, scroll: $("grid").scrollTop };
    state.view = "stations";
    $("list-title").textContent = it.label;
    $("list-sub").textContent = meta.name + (it.group === "arab" && it.kind === "genre" ? "" : " · " + fmt(it.count) + " محطة") + " · رجوع للعودة";
    $("grid").scrollTop = 0;
    var token = ++state.loadingToken;
    renderList(null);
    Sources.openFolderItem(it).then(function (res) {
      if (token !== state.loadingToken) return;
      setPaging(res);
      renderList(res.stations, "تعذّر تحميل محطات «" + it.label + "» الآن. تأكد من الإنترنت.");
      if (res.source === "cache") $("list-sub").textContent += " · من آخر تحديث محفوظ";
      focusFirst();
      showLocalFilter(true);
    });
  }

  function backToFolder() {
    showLocalFilter(false);
    var p = state.parent;
    state.parent = null;
    state.view = "folder";
    state.loadingToken++;
    var meta = catMeta(p.cat);
    $("list-title").textContent = meta.name;
    $("list-sub").textContent = meta.sub || "";
    renderFolder(p.items);
    $("grid").scrollTop = p.scroll || 0;
    var card = $("grid").querySelector('.st[data-id="' + p.focusId.replace(/"/g, "") + '"]');
    Nav.focus(card || $("grid").querySelector(".st"));
  }

  /* ---------- station grid ---------- */
  function renderList(stations, emptyText) {
    var grid = $("grid"), empty = $("empty");
    grid.textContent = "";
    if (stations === null) { empty.hidden = false; empty.textContent = "جارِ تحميل المحطات…"; state.list = []; return; }
    state.list = stations;
    empty.hidden = stations.length > 0;
    empty.textContent = emptyText || "";
    var playing = Player.current();
    stations.forEach(function (s) {
      var card = el("button", "st");
      card.setAttribute("role", "listitem");
      card.dataset.id = s.id;
      var logo = el("span", "logo"); paintLogo(logo, s); card.appendChild(logo);
      var meta = el("span", "meta");
      var nm = el("div", "name", s.name), tg = el("div", "tags", s.tags || "");
      nm.dir = "auto"; tg.dir = "auto";
      meta.appendChild(nm); meta.appendChild(tg);
      card.appendChild(meta);
      var fi = favIndex(s.id);
      if (fi >= 0 && fi < 9) card.appendChild(el("span", "fav-num", "★ " + (fi + 1)));
      if (Store.isBroken(s.id)) card.classList.add("broken");
      if (playing && playing.id === s.id) card.classList.add("playing");
      card.addEventListener("click", function () { playStation(s); });
      grid.appendChild(card);
    });
    if (state.full && stations.length) {
      var more = el("button", "st more");
      more.dataset.id = "__more";
      more.appendChild(el("span", "more-ico", "+"));
      var mm = el("span", "meta");
      mm.appendChild(el("div", "name", "تحميل المزيد"));
      mm.appendChild(el("div", "tags", "60 محطة أخرى"));
      more.appendChild(mm);
      more.addEventListener("click", loadMore);
      grid.appendChild(more);
    }
  }

  var loadingMore = false;
  function loadMore() {
    if (loadingMore || !state.full || !state.listDesc) return;
    loadingMore = true;
    var btn = $("grid").querySelector(".st.more");
    if (btn) btn.querySelector(".name").textContent = "جارِ التحميل…";
    var token = state.loadingToken, before = state.list.length;
    Sources.more(state.listDesc, state.rows).then(function (res) {
      loadingMore = false;
      if (token !== state.loadingToken) return;
      state.rows += res.rows || 0;
      state.full = res.full;
      var keepScroll = $("grid").scrollTop;
      renderList(Sources.dedupe(state.list.concat(res.stations)), $("empty").textContent);
      applyLocalFilter();
      $("grid").scrollTop = keepScroll;
      var cards = $("grid").querySelectorAll(".st");
      Nav.focus(cards[Math.min(before, cards.length - 1)]);
      if (state.list.length === before) toast("لا توجد محطات أخرى هنا");
    }, function () {
      loadingMore = false;
      if (btn) btn.querySelector(".name").textContent = "تحميل المزيد";
      toast("تعذّر تحميل المزيد. تأكد من الإنترنت.");
    });
  }

  function markPlayingCard() {
    var p = Player.current();
    Array.prototype.forEach.call(document.querySelectorAll(".st"), function (c) {
      c.classList.toggle("playing", !!p && c.dataset.id === p.id);
    });
  }

  /* ---------- playback ---------- */
  function playStation(s) {
    Store.clearBroken(s.id);
    Store.setLastStation(s);
    Store.addRecent(s);
    Player.play(s);
    Sources.reportClick(s);
    markPlayingCard();
  }

  function stepStation(delta) {
    var list = state.list;
    if (!list.length) list = Store.favorites();
    if (!list.length) list = Store.recent();
    if (!list.length) return;
    var cur = Player.current(), i = -1;
    list.forEach(function (s, n) { if (cur && s.id === cur.id) i = n; });
    var n = (i + delta + list.length) % list.length;
    playStation(list[n]);
    var card = $("grid").querySelector('.st[data-id="' + list[n].id.replace(/"/g, "") + '"]');
    if (card) Nav.focus(card);
  }

  function playFavorite(n) {
    var f = Store.favorites()[n - 1];
    if (f) { playStation(f); toast("★ " + n + " · " + f.name); }
    else toast("لا توجد محطة مفضلة على الرقم " + n);
  }

  function toggleFavorite() {
    var target = null, foc = Nav.current();
    if (foc && foc.classList.contains("st")) {
      state.list.forEach(function (s) { if (s.id === foc.dataset.id) target = s; });
    }
    target = target || Player.current();
    if (!target) { toast("اختر محطة أولاً"); return; }
    var added = Store.toggleFavorite(target), fi = favIndex(target.id);
    toast(added ? "أُضيفت للمفضلة" + (fi < 9 ? " على الرقم " + (fi + 1) : "") : "حُذفت من المفضلة");
    var keepId = foc && foc.dataset && foc.dataset.id;
    if (state.cat === "fav" && !state.parent) openCat("fav", false); else renderList(state.list, $("empty").textContent);
    if (keepId) { var c = $("grid").querySelector('.st[data-id="' + keepId.replace(/"/g, "") + '"]'); if (c) Nav.focus(c); }
    updateFavButton();
  }

  function updateFavButton() {
    var cur = Player.current(), b = $("btn-fav");
    var on = !!cur && Store.isFavorite(cur.id);
    b.textContent = on ? "★ في المفضلة" : "☆ للمفضلة";
    b.classList.toggle("on", on);
  }

  Player.on(function (st, info) {
    var s = info.station, status = $("now-status");
    if (st === "sleep") { updateSleep(info); refreshControls(); return; }
    document.body.classList.toggle("playing-on", st === "playing");
    status.classList.toggle("err", st === "error" || st === "blocked");
    if (s) {
      $("now-name").textContent = s.name;
      $("so-name").textContent = s.name;
      paintLogo($("now-art"), s);
    }
    if (st === "connecting") status.textContent = info.of > 1 ? "جارِ الاتصال… (رابط " + info.attempt + " من " + info.of + ")" : "جارِ الاتصال…";
    if (st === "playing") { status.textContent = "يعمل الآن · " + (s.tags || ""); Store.clearBroken(s.id); startNowPlayingPoll(s); }
    if (st === "buffering") status.textContent = "الإشارة ضعيفة… جارِ التحميل";
    if (st === "paused") { status.textContent = "متوقف مؤقتاً · اضغط تشغيل"; stopNowPlayingPoll(); }
    if (st === "stopped") { status.textContent = "متوقف"; stopNowPlayingPoll(); }
    if (st === "blocked") status.textContent = "المتصفح منع التشغيل التلقائي. اضغط تشغيل.";
    if (st === "connecting") stopNowPlayingPoll();
    if (st === "playing") { updateMediaSession(s, "playing"); }
    if (st === "paused" || st === "stopped") { if (navigator.mediaSession) { try { navigator.mediaSession.playbackState = "paused"; } catch(e){} } }
    if (st === "error") {
      status.textContent = "هذه المحطة لا تعمل الآن. جرّب محطة أخرى.";
      Store.markBroken(s.id);
      var card = $("grid").querySelector('.st[data-id="' + s.id.replace(/"/g, "") + '"]');
      if (card) card.classList.add("broken");
    }
    lastState = st;
    refreshControls();
  });

  var lastState = "idle";
  function refreshControls() {
    var active = lastState === "playing" || lastState === "connecting" || lastState === "buffering";
    $("btn-toggle").textContent = active ? "إيقاف" : "تشغيل";
    updateFavButton();
    markPlayingCard();
  }

  /* ---------- sleep timer ---------- */
  var SLEEP_STEPS = [0, 15, 30, 60, 90, 120, 180], sleepStep = 0, sleepTick;
  function cycleSleep() {
    sleepStep = (sleepStep + 1) % SLEEP_STEPS.length;
    var m = SLEEP_STEPS[sleepStep];
    Player.setSleep(m);
    toast(m ? "سيتوقف الراديو بعد " + m + " دقيقة" : "تم إلغاء مؤقت النوم");
  }
  function updateSleep(info) {
    var badge = $("sleep-badge"), btn = $("btn-sleep");
    clearInterval(sleepTick);
    if (!info.minutes) {
      badge.hidden = true; btn.textContent = "مؤقت النوم"; btn.classList.remove("on"); sleepStep = 0;
      if (info.fired) toast("انتهى مؤقت النوم · تصبح على خير");
      return;
    }
    btn.classList.add("on");
    function tick() {
      var mins = Math.ceil(Player.sleepRemaining() / 60e3);
      badge.hidden = false; badge.textContent = "⏾ " + mins + " د";
      btn.textContent = "مؤقت النوم · " + mins + " د";
    }
    tick(); sleepTick = setInterval(tick, 15000);
  }

  /* ---------- screen off (protects OLED, keeps audio) ---------- */
  var soTimer;
  function screenOff(on) {
    var so = $("screen-off");
    so.hidden = !on;
    clearInterval(soTimer);
    if (!on) return;
    function drift() {
      var c = $("so-clock"), d = new Date();
      c.textContent = pad(d.getHours()) + ":" + pad(d.getMinutes());
      c.style.top = (10 + Math.random() * 70) + "%";
      c.style.left = (10 + Math.random() * 70) + "%";
    }
    drift(); soTimer = setInterval(drift, 60000);
  }

  /* ---------- clock & text size ---------- */
  function pad(n) { return (n < 10 ? "0" : "") + n; }
  var lastCheckedMinute = -1;
  function clock() {
    var d = new Date();
    $("clock").textContent = pad(d.getHours()) + ":" + pad(d.getMinutes());
    var currentMinute = d.getHours() * 60 + d.getMinutes();
    if (currentMinute !== lastCheckedMinute) {
      lastCheckedMinute = currentMinute;
      Alarm.check(fireAlarm);
      updatePrayerDisplay();
    }
  }
  function applyTextSize(big) {
    document.documentElement.classList.toggle("big", big);
    $("btn-textsize").textContent = big ? "خط عادي" : "تكبير الخط";
  }

  /* ---------- local filter (folder station lists) ---------- */
  function applyLocalFilter() {
    var row = $("local-filter-row");
    if (row.hidden) return;
    var q = ($("local-filter").value || "").trim().toLowerCase();
    var cards = $("grid").querySelectorAll(".st:not(.more)");
    var visible = 0;
    Array.prototype.forEach.call(cards, function (c) {
      var id = c.dataset.id, s = null;
      for (var i = 0; i < state.list.length; i++) { if (state.list[i].id === id) { s = state.list[i]; break; } }
      var match = !q || !s || (s.name + " " + (s.tags || "")).toLowerCase().indexOf(q) >= 0;
      c.style.display = match ? "" : "none";
      if (match) visible++;
    });
    var empty = $("empty");
    if (!visible && q) { empty.hidden = false; empty.textContent = "لا توجد نتائج لـ «" + $("local-filter").value + "»"; }
    else if (visible) { empty.hidden = true; }
  }

  function showLocalFilter(show) {
    var row = $("local-filter-row");
    row.hidden = !show;
    if (!show) {
      $("local-filter").value = "";
      Array.prototype.forEach.call($("grid").querySelectorAll(".st"), function (c) { c.style.display = ""; });
    }
  }

  $("local-filter").addEventListener("input", function () {
    $("local-filter-clear").hidden = !$("local-filter").value;
    applyLocalFilter();
  });
  $("search-input").addEventListener("input", function () {
    $("search-clear").hidden = !$("search-input").value;
  });

  /* ---------- alarm ---------- */
  function updateAlarmBadge() {
    var badge = $("alarm-badge");
    var text = Alarm.badge();
    if (text) { badge.textContent = text; badge.hidden = false; }
    else { badge.hidden = true; }
  }

  function fireAlarm(stationId) {
    toast("\u23F0 \u0648\u0642\u062a \u0627\u0644\u0645\u0646\u0628\u0647!");
    if (stationId === "quran") {
      openCat("quran", false);
      /* Play first station in quran list once it loads — wait briefly for Sources.load */
      setTimeout(function () {
        var first = $("grid").querySelector(".st");
        if (first) first.click();
      }, 1800);
    } else {
      var last = Store.lastStation();
      if (last) playStation(last);
    }
    updateAlarmBadge();
  }

  /* ---------- prayer ---------- */
  function toArabicNum(n) {
    return String(n).replace(/\d/g, function (d) { return "\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669"[d]; });
  }

  function updatePrayerDisplay() {
    var cityId = Prayer.currentCityId();
    var btn = $("btn-prayer"), next = $("prayer-next");
    if (!cityId) {
      btn.textContent = "\u0627\u062e\u062a\u0631 \u0645\u062f\u064a\u0646\u0629 \u0644\u0644\u0635\u0644\u0627\u0629";
      btn.hidden = false;
      next.hidden = true;
      return;
    }
    btn.hidden = true;
    var info = Prayer.getNext(cityId);
    if (!info) { next.hidden = true; return; }
    /* Format: "العصر ١٥:٣٢ · ٤٥ د" */
    var parts = info.time.split(":");
    var timeAr = toArabicNum(parts[0]) + ":" + toArabicNum(parts[1]);
    var minsAr = toArabicNum(info.minutes);
    next.textContent = info.name + " " + timeAr + " \u00B7 " + minsAr + " \u062f";
    next.hidden = false;

    /* Prayer pause: if minutes === 0, pause player */
    var pauseChecked = Store.get("prayer_pause", false);
    if (pauseChecked && info.minutes === 0) {
      Player.pause();
      toast(info.name + " \u2013 \u062a\u0648\u0642\u0641 \u0639\u0646\u062f \u0627\u0644\u0623\u0630\u0627\u0646");
    }
  }

  function populatePrayerCitySelect() {
    var sel = $("prayer-city");
    if (sel.options.length > 0) return; /* already populated */
    Prayer.CITIES.forEach(function (c) {
      var opt = document.createElement("option");
      opt.value = c.id;
      opt.textContent = c.name;
      sel.appendChild(opt);
    });
  }

  /* ---------- actions ---------- */
  function doAction(name) {
    if (name === "toggle") { if (Player.current()) Player.toggle(); else toast("اختر محطة أولاً"); }
    if (name === "fav-current") toggleFavorite();
    if (name === "sleep") cycleSleep();
    if (name === "screen-off") screenOff(true);
    if (name === "textsize") { var big = !document.documentElement.classList.contains("big"); Store.set("big", big); applyTextSize(big); }
    if (name === "do-search") runSearch();
    if (name === "search-clear") {
      $("search-input").value = "";
      $("search-clear").hidden = true;
      $("search-input").focus();
    }
    if (name === "local-filter-clear") {
      $("local-filter").value = "";
      $("local-filter-clear").hidden = true;
      applyLocalFilter();
      $("local-filter").focus();
    }
    if (name === "share") {
      var sh = Player.current();
      if (!sh) { toast("اختر محطة أولاً"); return; }
      var shUrl = location.origin + location.pathname + "#s=" + encodeURIComponent(sh.id);
      var shText = sh.name + (sh.tags ? " · " + sh.tags : "");
      if (navigator.share) {
        navigator.share({ title: sh.name, text: shText, url: shUrl }).catch(function () {});
      } else if (navigator.clipboard) {
        navigator.clipboard.writeText(shUrl).then(function () { toast("نُسخ رابط المحطة"); }, function () { toast("تعذّر النسخ"); });
      } else { toast("المشاركة غير مدعومة"); }
    }
    if (name === "report-broken") {
      var rb = Player.current();
      if (!rb) { toast("اختر محطة أولاً"); return; }
      Store.markBroken(rb.id);
      var rbc = $("grid").querySelector('.st[data-id="' + rb.id.replace(/"/g, "") + '"]');
      if (rbc) rbc.classList.add("broken");
      toast("تم الإبلاغ عن «" + rb.name + "» كمحطة لا تعمل");
    }
    if (name === "alarm-toggle") {
      var panel = $("alarm-panel");
      var wasHidden = panel.hidden;
      panel.hidden = !wasHidden;
      $("prayer-panel").hidden = true;
      if (wasHidden) {
        var existing = Alarm.get();
        if (existing && existing.time) $("alarm-time").value = existing.time;
      }
    }
    if (name === "alarm-set") {
      var timeVal = $("alarm-time").value;
      if (!timeVal) { toast("اختر وقت المنبه أولاً"); return; }
      var stVal = $("alarm-station").value;
      Alarm.set(timeVal, stVal);
      $("alarm-panel").hidden = true;
      updateAlarmBadge();
      var parts = timeVal.split(":");
      toast("\u23F0 \u062a\u0645 \u062a\u0639\u064a\u064a\u0646 \u0627\u0644\u0645\u0646\u0628\u0647 \u0639\u0644\u0649 " + toArabicNum(parts[0]) + ":" + toArabicNum(parts[1]));
    }
    if (name === "alarm-cancel") {
      Alarm.cancel();
      $("alarm-panel").hidden = true;
      updateAlarmBadge();
      toast("\u062a\u0645 \u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u0645\u0646\u0628\u0647");
    }
    if (name === "prayer-toggle") {
      var pPanel = $("prayer-panel");
      var pWasHidden = pPanel.hidden;
      pPanel.hidden = !pWasHidden;
      $("alarm-panel").hidden = true;
      if (pWasHidden) {
        populatePrayerCitySelect();
        var cityId = Prayer.currentCityId();
        if (cityId) $("prayer-city").value = cityId;
      }
    }
    if (name === "prayer-close") {
      var selCity = $("prayer-city").value;
      if (selCity) Prayer.setCity(selCity);
      $("prayer-panel").hidden = true;
      updatePrayerDisplay();
    }
  }
  document.addEventListener("click", function (e) {
    var b = e.target.closest("[data-action]");
    if (b) { Nav.focus(b); doAction(b.dataset.action); }
  });
  document.addEventListener("mouseover", function (e) {
    var t = e.target.closest(".st, .cat, .focusable");
    if (t && t !== Nav.current() && t.tagName !== "INPUT") Nav.focus(t);
  });

  function runSearch() {
    var text = $("search-input").value;
    state.searchText = text;
    if (!text.trim()) { toast("اكتب اسم المحطة أولاً"); return; }
    renderList(null);
    var token = ++state.loadingToken;
    Sources.search(text).then(function (res) {
      if (token !== state.loadingToken) return;
      setPaging(res);
      renderList(res.stations, "لا توجد نتائج لـ «" + text + "». جرّب اسماً آخر أو بالإنجليزية.");
      $("list-sub").textContent = res.stations.length + (res.full ? "+" : "") + " نتيجة";
      var first = $("grid").querySelector(".st"); if (first) Nav.focus(first);
    }, function () {
      renderList([], "البحث غير متاح الآن. تأكد من الإنترنت.");
    });
  }

  /* ---------- remote / keyboard ---------- */
  var exitArmed = 0;
  function back() {
    var foc = Nav.current();
    if (!$("screen-off").hidden) { screenOff(false); return; }
    if (state.parent && foc && !foc.classList.contains("cat")) { backToFolder(); return; }
    if (foc && !foc.classList.contains("cat")) {
      Nav.focus(document.querySelector(".cat.active") || document.querySelector(".cat"));
      return;
    }
    if (Date.now() - exitArmed < 2500) {
      if (isTizen) { try { tizen.application.getCurrentApplication().exit(); } catch (e) {} }
      else toast("على التلفزيون: هنا يُغلق التطبيق");
      return;
    }
    exitArmed = Date.now();
    toast("اضغط رجوع مرة أخرى للخروج");
  }

  var KEY = { LEFT: 37, UP: 38, RIGHT: 39, DOWN: 40, ENTER: 13, BACK: 10009, ESC: 27, BKSP: 8,
              RED: 403, GREEN: 404, YELLOW: 405, BLUE: 406, CH_UP: 427, CH_DOWN: 428,
              PLAYPAUSE: 10252, PLAY: 415, PAUSE: 19, STOP: 413, PGUP: 33, PGDN: 34, SPACE: 32 };

  document.addEventListener("keydown", function (e) {
    var k = e.keyCode, foc = Nav.current(), inInput = document.activeElement && document.activeElement.tagName === "INPUT";

    if (!$("screen-off").hidden) { e.preventDefault(); screenOff(false); return; }

    if (inInput) {
      if (k === KEY.ENTER) { e.preventDefault(); runSearch(); return; }
      if (k === KEY.DOWN) { e.preventDefault(); var f = $("grid").querySelector(".st") || document.querySelector('[data-action="do-search"]'); Nav.focus(f); return; }
      if (k === KEY.UP || k === KEY.BACK || k === KEY.ESC) { e.preventDefault(); document.activeElement.blur(); Nav.focus(document.querySelector(".cat.active")); return; }
      if (k === KEY.LEFT && document.activeElement.selectionStart === 0) { e.preventDefault(); Nav.move("left"); return; }
      return; // let typing through
    }

    var digit = k >= 48 && k <= 57 ? k - 48 : k >= 96 && k <= 105 ? k - 96 : -1;
    if (digit >= 1) { e.preventDefault(); playFavorite(digit); return; }

    switch (k) {
      case KEY.LEFT: e.preventDefault(); Nav.move("left"); break;
      case KEY.RIGHT: e.preventDefault(); Nav.move("right"); break;
      case KEY.UP: e.preventDefault(); Nav.move("up"); break;
      case KEY.DOWN: e.preventDefault(); Nav.move("down"); break;
      case KEY.ENTER:
        e.preventDefault();
        if (foc) foc.click();
        break;
      case KEY.BACK: case KEY.ESC: case KEY.BKSP: e.preventDefault(); back(); break;
      case KEY.RED: toggleFavorite(); break;
      case KEY.GREEN: cycleSleep(); break;
      case KEY.YELLOW: screenOff(true); break;
      case KEY.BLUE: openCat("search", true); break;
      case KEY.CH_UP: case KEY.PGUP: e.preventDefault(); stepStation(-1); break;
      case KEY.CH_DOWN: case KEY.PGDN: e.preventDefault(); stepStation(1); break;
      case KEY.PLAYPAUSE: case KEY.SPACE: e.preventDefault(); doAction("toggle"); break;
      case KEY.PLAY: Player.resume(); break;
      case KEY.PAUSE: Player.pause(); break;
      case KEY.STOP: Player.stop(); break;
    }
  });

  /* Opening a category when the focus lands on it keeps the remote flow short. */
  var catHoverTimer;
  document.addEventListener("focusin", function (e) {
    var c = e.target.closest && e.target.closest(".cat");
    clearTimeout(catHoverTimer);
    if (c && (c.dataset.cat !== state.cat || state.parent)) catHoverTimer = setTimeout(function () { openCat(c.dataset.cat, false); }, 350);
  });

  /* Directory size on the brand line: a live reminder of how much is out there. */
  function showStats() {
    Sources.stats().then(function (st) {
      if (st && st.stations) $("dir-count").textContent = fmt(st.stations) + " محطة في الدليل";
    });
  }

  /* ---------- ICY now-playing poll ---------- */
  var icyTimer = null, icyTitle = "", icyArtist = "";

  function pollNowPlaying(station) {
    var url = station.urls && station.urls[0];
    if (!url) return;
    var s = Player.current();
    if (!s || s.id !== station.id) return;
    var apiUrl = "https://radioproxy.elgarhy.uk/nowplaying?url=" + encodeURIComponent(url);
    fetch(apiUrl).then(function (r) { return r.json(); }).then(function (d) {
      var cur = Player.current();
      if (!cur || cur.id !== station.id) return;
      icyTitle  = d.title  || "";
      icyArtist = d.artist || "";
      if (icyTitle) {
        var display = icyArtist ? icyArtist + " — " + icyTitle : icyTitle;
        $("now-status").textContent = "♪ " + display;
        $("now-status").classList.remove("err");
        updateMediaSession(cur, "playing");
      }
    }).catch(function () {});
  }

  function startNowPlayingPoll(station) {
    stopNowPlayingPoll();
    icyTitle = ""; icyArtist = "";
    pollNowPlaying(station);
    icyTimer = setInterval(function () { pollNowPlaying(station); }, 30000);
  }

  function stopNowPlayingPoll() {
    clearInterval(icyTimer);
    icyTimer = null;
    icyTitle = ""; icyArtist = "";
  }

  /* ---------- Media Session (lock-screen controls) ---------- */
  function updateMediaSession(station, playState) {
    if (!navigator.mediaSession) return;
    try {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: icyTitle  || station.name,
        artist: icyArtist || station.tags || "بث مباشر",
        album: station.name,
        artwork: station.logo
          ? [{ src: station.logo, sizes: "512x512" }]
          : [{ src: "/assets/icon.png", sizes: "192x192", type: "image/png" }]
      });
      navigator.mediaSession.playbackState = playState || "playing";
    } catch (e) {}
  }

  function setupMediaSession() {
    if (!navigator.mediaSession) return;
    try {
      navigator.mediaSession.setActionHandler("play", function () { Player.resume(); });
      navigator.mediaSession.setActionHandler("pause", function () { Player.pause(); });
      navigator.mediaSession.setActionHandler("stop", function () { Player.stop(); });
      navigator.mediaSession.setActionHandler("previoustrack", function () { stepStation(-1); });
      navigator.mediaSession.setActionHandler("nexttrack", function () { stepStation(1); });
    } catch (e) {}
  }

  /* ---------- prayer pause checkbox ---------- */
  $("prayer-pause").addEventListener("change", function () {
    Store.set("prayer_pause", $("prayer-pause").checked);
  });
  /* restore saved state */
  $("prayer-pause").checked = !!Store.get("prayer_pause", false);

  /* ---------- start ---------- */
  renderCats();
  showStats();
  applyTextSize(!!Store.get("big", false));

  updateAlarmBadge();
  updatePrayerDisplay();
  clock(); setInterval(clock, 10000);
  var last = Store.lastStation();
  if (last) {
    $("now-name").textContent = last.name;
    $("now-status").textContent = "آخر محطة · اضغط تشغيل";
    paintLogo($("now-art"), last);
    Player.prime(last);
  }
  updateFavButton();
  setupMediaSession();

  /* Shareable link: #s=<station-id> — resolve and prime/play the station. */
  var hashMatch = location.hash && location.hash.match(/^#s=([^&]+)/);
  if (hashMatch) {
    var linkedId = decodeURIComponent(hashMatch[1]);
    history.replaceState(null, "", location.pathname); // clean URL after reading hash
    Sources.resolveById(linkedId).then(function (s) {
      Store.addRecent(s);
      paintLogo($("now-art"), s);
      $("now-name").textContent = s.name;
      $("now-status").textContent = "محطة مشتركة · اضغط تشغيل";
      Player.prime(s);
      Player.play(s);
      toast("🔗 " + s.name);
    }, function () {
      toast("لم يُعثر على المحطة المشتركة");
    });
  }

  openCat(Store.favorites().length ? "fav" : "quran", true);

  /* Station health: fetch once at startup, dim confirmed-dead stations. */
  var healthData = {};
  fetch("https://radioproxy.elgarhy.uk/station-health")
    .then(function (r) { return r.json(); })
    .then(function (d) {
      healthData = d.stations || {};
      /* Mark any already-rendered cards that are confirmed dead */
      Object.keys(healthData).forEach(function (id) {
        if (!healthData[id].ok) {
          var card = $("grid").querySelector('.st[data-id="' + id.replace(/"/g, "") + '"]');
          if (card) card.classList.add("broken");
        }
      });
    })
    .catch(function () {});

  /* Apply health data when renderList builds new cards */
  var _origRenderList = renderList;
  renderList = function (stations, emptyText) {
    _origRenderList(stations, emptyText);
    if (!stations || !Object.keys(healthData).length) return;
    stations.forEach(function (s) {
      if (healthData[s.id] && !healthData[s.id].ok) {
        var card = $("grid").querySelector('.st[data-id="' + s.id.replace(/"/g, "") + '"]');
        if (card) card.classList.add("broken");
      }
    });
  };
})();
