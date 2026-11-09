/* Audio engine: tries each stream link of a station in turn, reconnects on stalls,
   and handles the sleep timer with a gentle fade-out. */
(function () {
  "use strict";

  var audio = document.getElementById("audio");
  var CONNECT_TIMEOUT = 12000, STALL_TIMEOUT = 15000;
  var HLS_SRC = "https://cdn.jsdelivr.net/npm/hls.js@1.5.18/dist/hls.min.js";

  var current = null, urlIndex = 0, attemptId = 0, connectTimer = null, stallTimer = null;
  var hls = null, listeners = [], sleepTimer = null, sleepEnds = 0, fadeTimer = null;

  var PROXY = "https://radioproxy.elgarhy.uk/stream?url=";
  function proxyUrl(url) {
    /* Rewrite http:// streams through the VPS proxy so they play on the HTTPS site. */
    return (url && url.indexOf("http://") === 0) ? PROXY + encodeURIComponent(url) : url;
  }

  function emit(state, info) { listeners.forEach(function (fn) { fn(state, info || {}); }); }
  function clearTimers() { clearTimeout(connectTimer); clearTimeout(stallTimer); }
  function isHls(url, station) { return station.hls || /\.m3u8(\?|$)/i.test(url); }

  function loadHlsLib() {
    if (window.Hls) return Promise.resolve(window.Hls);
    return new Promise(function (resolve, reject) {
      var s = document.createElement("script");
      s.src = HLS_SRC;
      s.onload = function () { window.Hls ? resolve(window.Hls) : reject(new Error("hls_missing")); };
      s.onerror = function () { reject(new Error("hls_load_failed")); };
      document.head.appendChild(s);
    });
  }

  function detach() {
    clearTimers();
    if (hls) { try { hls.destroy(); } catch (e) {} hls = null; }
    audio.removeAttribute("src");
    try { audio.load(); } catch (e) {}
  }

  function tryUrl() {
    var my = ++attemptId;
    if (!current) return;
    if (urlIndex >= current.urls.length) {
      detach();
      emit("error", { station: current });
      return;
    }
    var rawUrl = current.urls[urlIndex];
    var url = proxyUrl(rawUrl);
    emit("connecting", { station: current, attempt: urlIndex + 1, of: current.urls.length });
    detach();
    audio.volume = 1;

    connectTimer = setTimeout(function () { if (my === attemptId) next(); }, CONNECT_TIMEOUT);

    if (isHls(rawUrl, current) && !audio.canPlayType("application/vnd.apple.mpegurl")) {
      loadHlsLib().then(function (Hls) {
        if (my !== attemptId) return;
        if (!Hls.isSupported()) return next();
        hls = new Hls({ lowLatencyMode: false });
        hls.on(Hls.Events.ERROR, function (_, d) { if (d.fatal && my === attemptId) next(); });
        hls.loadSource(url);
        hls.attachMedia(audio);
        audio.play().catch(function () {});
      }, function () { if (my === attemptId) next(); });
    } else {
      audio.src = url;
      var p = audio.play();
      if (p && p.catch) p.catch(function (e) {
        if (my !== attemptId) return;
        if (e && e.name === "NotAllowedError") emit("blocked", { station: current });
      });
    }
  }

  function next() { clearTimers(); urlIndex++; tryUrl(); }

  audio.addEventListener("playing", function () {
    clearTimers();
    if (current) emit("playing", { station: current });
  });
  audio.addEventListener("waiting", function () {
    if (!current || audio.paused) return;
    emit("buffering", { station: current });
    clearTimeout(stallTimer);
    var my = attemptId;
    stallTimer = setTimeout(function () { if (my === attemptId && current) tryUrl(); }, STALL_TIMEOUT);
  });
  audio.addEventListener("error", function () {
    if (!current || !audio.getAttribute("src") && !hls) return;
    next();
  });
  audio.addEventListener("pause", function () {
    if (current && !audio.ended && audio.getAttribute("src")) emit("paused", { station: current });
  });

  function cancelSleep() {
    clearTimeout(sleepTimer); clearInterval(fadeTimer);
    sleepTimer = null; sleepEnds = 0; audio.volume = 1;
  }

  window.Player = {
    on: function (fn) { listeners.push(fn); },
    current: function () { return current; },
    isPlaying: function () { return !!current && !audio.paused; },

    play: function (station) {
      current = station; urlIndex = 0; tryUrl();
    },
    /* Remember a station (e.g. the last one heard) without starting it. */
    prime: function (station) { if (!current) { current = station; urlIndex = 0; } },
    resume: function () {
      if (!current) return;
      if (audio.getAttribute("src") || hls) {
        // live radio: reconnect instead of resuming stale buffered audio
        urlIndex = urlIndex < current.urls.length ? urlIndex : 0;
        tryUrl();
      } else this.play(current);
    },
    pause: function () { clearTimers(); audio.pause(); },
    stop: function () { var s = current; detach(); current = null; emit("stopped", { station: s }); },
    toggle: function () { this.isPlaying() ? this.pause() : this.resume(); },

    /* minutes = 0 cancels. The last 30 seconds fade out. */
    setSleep: function (minutes) {
      cancelSleep();
      if (!minutes) { emit("sleep", { minutes: 0 }); return; }
      sleepEnds = Date.now() + minutes * 60e3;
      sleepTimer = setTimeout(function fade() {
        var steps = 30, n = 0;
        fadeTimer = setInterval(function () {
          n++; audio.volume = Math.max(0, 1 - n / steps);
          if (n >= steps) { clearInterval(fadeTimer); Player.pause(); cancelSleep(); emit("sleep", { minutes: 0, fired: true }); }
        }, 1000);
      }, Math.max(0, minutes * 60e3 - 30e3));
      emit("sleep", { minutes: minutes });
    },
    sleepRemaining: function () { return sleepEnds ? Math.max(0, sleepEnds - Date.now()) : 0; }
  };
})();
