/* Small persistent store. Every access is wrapped: TV storage can be full or unavailable. */
(function () {
  "use strict";
  var P = "rafeeq.radio.";
  function get(k, fallback) {
    try { var v = localStorage.getItem(P + k); return v ? JSON.parse(v) : fallback; } catch (e) { return fallback; }
  }
  function set(k, v) {
    try { localStorage.setItem(P + k, JSON.stringify(v)); return true; } catch (e) { return false; }
  }
  function del(k) { try { localStorage.removeItem(P + k); } catch (e) {} }

  var BROKEN_HOURS = 6, RECENT_MAX = 30, CACHE_MAX = 40;

  function slim(s) {
    return { id: s.id, name: s.name, tags: s.tags, country: s.country, cat: s.cat,
             logo: s.logo, urls: s.urls, uuid: s.uuid, hls: s.hls };
  }

  window.Store = {
    get: get,
    set: set,

    favorites: function () { return get("favorites", []); },
    isFavorite: function (id) { return this.favorites().some(function (s) { return s.id === id; }); },
    toggleFavorite: function (station) {
      var list = this.favorites(), i = -1;
      list.forEach(function (s, n) { if (s.id === station.id) i = n; });
      if (i >= 0) list.splice(i, 1);
      else list.push(slim(station));
      set("favorites", list);
      return i < 0;
    },

    recent: function () { return get("recent", []); },
    addRecent: function (station) {
      var list = this.recent().filter(function (s) { return s.id !== station.id; });
      list.unshift(slim(station));
      set("recent", list.slice(0, RECENT_MAX));
    },

    markBroken: function (id) { var b = get("broken", {}); b[id] = Date.now(); set("broken", b); },
    clearBroken: function (id) { var b = get("broken", {}); if (b[id]) { delete b[id]; set("broken", b); } },
    isBroken: function (id) {
      var t = get("broken", {})[id];
      return !!t && Date.now() - t < BROKEN_HOURS * 3600e3;
    },

    cached: function (key, maxAgeMs) {
      var c = get("cache." + key, null);
      if (!c) return null;
      return { fresh: Date.now() - c.t < maxAgeMs, data: c.data };
    },
    /* Keeps at most CACHE_MAX cached lists; the oldest are dropped first,
       and again whenever storage runs out of room. */
    cache: function (key, data) {
      var index = get("cacheIndex", []).filter(function (k) { return k !== key; });
      index.push(key);
      while (index.length > CACHE_MAX) del("cache." + index.shift());
      var entry = { t: Date.now(), data: data };
      while (!set("cache." + key, entry) && index.length > 1) del("cache." + index.shift());
      set("cacheIndex", index);
    },

    lastStation: function () { return get("last", null); },
    setLastStation: function (s) { set("last", slim(s)); }
  };
})();
