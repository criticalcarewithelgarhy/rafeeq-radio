/* Station sources: the curated seed list, Radio Browser (open directory of tens of
   thousands of stations) and mp3quran.net (one radio per Quran reciter).
   Lists are paged (60 at a time) and cached so the app keeps working when a
   directory is down. */
(function () {
  "use strict";

  var RB_SERVERS = [
    "https://de1.api.radio-browser.info",
    "https://fi1.api.radio-browser.info",
    "https://de2.api.radio-browser.info",
    "https://nl1.api.radio-browser.info"
  ];
  var PAGE = 60;
  var CACHE_MS = 12 * 3600e3, FOLDER_CACHE_MS = 24 * 3600e3;
  var AR = window.RAFEEQ_COUNTRIES_AR || {};

  /* Shown first in the countries view, in this order. */
  var ARAB = ["EG", "SA", "AE", "KW", "QA", "BH", "OM", "JO", "LB", "PS", "SY", "IQ", "YE",
              "SD", "LY", "TN", "DZ", "MA", "MR", "SO", "DJ", "KM"];

  var CATEGORIES = [
    { id: "fav",       name: "المفضلة",          ico: "★" },
    { id: "recent",    name: "سمعتها مؤخراً",    ico: "↺", sub: "آخر 30 محطة شغّلتها" },
    { id: "quran",     name: "القرآن الكريم",    ico: "۞" },
    { id: "arabic",    name: "الدول العربية",    ico: "ع", folder: true, sub: "محطات كل دولة عربية" },
    { id: "countries", name: "دول العالم",       ico: "◍", folder: true, sub: "الأكثر محطات أولاً" },
    { id: "genres",    name: "الأنواع",          ico: "♫", folder: true, sub: "أنواع المحطات العربية ثم العالمية" },
    { id: "news",      name: "أخبار",            ico: "◆", sub: "إذاعات إخبارية بالعربية" },
    { id: "sport",     name: "رياضة",            ico: "◆", sub: "إذاعات رياضية بالعربية" },
    { id: "top",       name: "الأكثر استماعاً",  ico: "▲", sub: "حول العالم" },
    { id: "search",    name: "بحث",              ico: "⌕" }
  ];

  /* Arabic labels for the most common directory tags; others keep their original name. */
  var TAG_AR = {
    "music": "موسيقى", "pop": "بوب", "news": "أخبار", "talk": "برامج حوارية", "rock": "روك", "jazz": "جاز",
    "classical": "موسيقى كلاسيكية", "quran": "قرآن", "islamic": "إسلامية", "islam": "إسلامية", "religion": "دينية",
    "religious": "دينية", "christian": "مسيحية", "sport": "رياضة", "sports": "رياضة", "football": "كرة قدم",
    "arabic": "عربية", "arab": "عربية", "arabic music": "موسيقى عربية", "tarab": "طرب", "khaleeji": "خليجي",
    "oldies": "أغاني قديمة", "hits": "أشهر الأغاني", "top 40": "أعلى 40", "dance": "رقص", "electronic": "إلكترونية",
    "house": "هاوس", "country": "كانتري", "folk": "فولك", "traditional": "تراثية", "kids": "أطفال",
    "children": "أطفال", "80s": "الثمانينات", "90s": "التسعينات", "70s": "السبعينات", "60s": "الستينات",
    "chillout": "هادئة", "ambient": "هادئة", "lounge": "لاونج", "easy listening": "استماع هادئ",
    "hip-hop": "هيب هوب", "hiphop": "هيب هوب", "rap": "راب", "rnb": "آر أند بي", "soul": "سول", "blues": "بلوز",
    "metal": "ميتال", "alternative": "بديلة", "indie": "مستقلة", "reggae": "ريغي", "latin": "لاتينية",
    "culture": "ثقافة", "education": "تعليم", "comedy": "كوميديا", "public radio": "إذاعة عامة",
    "community radio": "إذاعة مجتمعية", "local news": "أخبار محلية", "information": "معلومات",
    "entertainment": "ترفيه", "variety": "منوعات", "world music": "موسيقى العالم", "instrumental": "موسيقى بلا غناء",
    "piano": "بيانو", "soundtrack": "موسيقى أفلام", "student": "طلابية", "regional": "إقليمية", "local": "محلية",
    "adult contemporary": "معاصرة", "charts": "قوائم الأغاني", "eclectic": "متنوعة", "hindi": "هندية",
    "bollywood": "بوليوود", "turkish": "تركية", "persian": "فارسية", "urdu": "أردية", "french": "فرنسية",
    "english": "إنجليزية", "spanish": "إسبانية", "german": "ألمانية", "greek": "يونانية", "deutsch": "ألمانية",
    "techno": "تكنو", "trance": "ترانس", "disco": "ديسكو", "funk": "فانك", "gospel": "إنجيلية", "opera": "أوبرا",
    "nasheed": "أناشيد", "anasheed": "أناشيد", "egypt": "مصر", "lebanon": "لبنان", "morocco": "المغرب",
    "algeria": "الجزائر", "tunisia": "تونس", "iraq": "العراق", "syria": "سوريا", "jordan": "الأردن",
    "palestine": "فلسطين", "saudi arabia": "السعودية", "kuwait": "الكويت", "qatar": "قطر", "dubai": "دبي",
    "rai": "راي", "chaabi": "شعبي", "shaabi": "شعبي", "mahraganat": "مهرجانات", "fm": "إف إم", "am": "إيه إم"
  };

  function xhrJSON(url, timeoutMs) {
    return new Promise(function (resolve, reject) {
      var x = new XMLHttpRequest();
      x.open("GET", url, true);
      x.timeout = timeoutMs || 9000;
      x.onload = function () {
        if (x.status < 200 || x.status >= 300) return reject(new Error("http_" + x.status));
        try { resolve(JSON.parse(x.responseText)); } catch (e) { reject(e); }
      };
      x.onerror = x.ontimeout = function () { reject(new Error("network")); };
      x.send();
    });
  }

  /* Tries each Radio Browser mirror in turn; remembers the one that answered. */
  var rbFirst = 0;
  function rb(path) {
    var tried = 0;
    function attempt() {
      if (tried >= RB_SERVERS.length) return Promise.reject(new Error("rb_unavailable"));
      var i = (rbFirst + tried++) % RB_SERVERS.length;
      return xhrJSON(RB_SERVERS[i] + path).then(function (d) { rbFirst = i; return d; }, attempt);
    }
    return attempt();
  }

  function unique(list) {
    var seen = {};
    return list.filter(function (u) { if (!u || seen[u]) return false; seen[u] = 1; return true; });
  }
  function httpsFirst(urls) {
    return urls.slice().sort(function (a, b) { return (b.indexOf("https:") === 0) - (a.indexOf("https:") === 0); });
  }
  function countryName(code, fallback) { return AR[code] || fallback || code; }
  function tagLabel(t) { var k = (t || "").toLowerCase().trim(); return TAG_AR[k] || t; }

  function fromRB(s) {
    var tags = (s.tags || "").split(",").filter(Boolean).slice(0, 2).map(tagLabel).join(" · ");
    var cc = (s.countrycode || "").toUpperCase();
    return {
      id: "rb-" + s.stationuuid, uuid: s.stationuuid,
      name: (s.name || "").trim() || "محطة بلا اسم",
      tags: [tags, cc ? countryName(cc, s.country) : s.country].filter(Boolean).join(" · "),
      country: cc,
      logo: s.favicon || "",
      hls: s.hls === 1,
      urls: httpsFirst(unique([s.url_resolved, s.url]))
    };
  }

  function rbPage(query, offset) {
    return rb("/json/stations/search?hidebroken=true&order=clickcount&reverse=true&limit=" + PAGE +
              "&offset=" + (offset || 0) + (query ? "&" + query : ""))
      .then(function (rows) {
        return { stations: rows.map(fromRB).filter(function (s) { return s.urls.length; }), full: rows.length >= PAGE, rows: rows.length };
      });
  }

  function mp3quran() {
    return xhrJSON("https://mp3quran.net/api/v3/radios?language=ar").then(function (d) {
      return { stations: (d.radios || []).map(function (r) {
        return { id: "mq-" + r.id, name: (r.name || "").trim(), tags: "قرآن · تلاوات", country: "", cat: "quran",
                 urls: unique([r.url]) };
      }).filter(function (s) { return s.name && s.urls.length; }), full: false };
    });
  }

  /* Each station list is described by a Radio Browser query, so it can be paged. */
  var QUERIES = {
    arabic: "language=arabic",
    news:   "tag=news&language=arabic",
    sport:  "tag=sport&language=arabic",
    top:    ""
  };

  function seedFor(cat) {
    return (window.RAFEEQ_SEED || []).filter(function (s) { return s.cat === cat; });
  }

  function dedupe(list) {
    var seen = {};
    return list.filter(function (s) {
      var key = (s.urls[0] || "").replace(/^https?:\/\//, "").replace(/\/$/, "");
      var nameKey = s.name.replace(/\s+/g, " ").toLowerCase();
      if (seen[key] || seen[nameKey]) return false;
      seen[key] = 1; seen[nameKey] = 1;
      return true;
    });
  }

  /* A list = { key, query, seed }. Returns { stations, source, full }.
     source is "live", "cache", "seed" or "local"; full=true means more pages may exist. */
  function loadList(list) {
    var seed = list.seed || [];
    var c = Store.cached(list.key, CACHE_MS);
    if (c && c.fresh && c.data.stations) return Promise.resolve({ stations: dedupe(seed.concat(c.data.stations)), source: "cache", full: c.data.full, rows: c.data.rows || 0 });
    var get = list.key === "quran" ? mp3quran() : rbPage(list.query, 0);
    return get.then(function (res) {
      Store.cache(list.key, res);
      return { stations: dedupe(seed.concat(res.stations)), source: "live", full: res.full, rows: res.rows || 0 };
    }, function () {
      if (c && c.data.stations) return { stations: dedupe(seed.concat(c.data.stations)), source: "cache", full: c.data.full, rows: c.data.rows || 0 };
      return { stations: seed, source: "seed", full: false };
    });
  }

  function listFor(cat) {
    if (cat === "quran") return { key: "quran", seed: seedFor("quran") };
    if (QUERIES.hasOwnProperty(cat)) return { key: cat, query: QUERIES[cat], seed: seedFor(cat) };
    return null;
  }

  function load(cat) {
    if (cat === "fav") return Promise.resolve({ stations: Store.favorites(), source: "local", full: false });
    if (cat === "recent") return Promise.resolve({ stations: Store.recent(), source: "local", full: false });
    var list = listFor(cat);
    if (!list) return Promise.resolve({ stations: [], source: "seed", full: false });
    return loadList(list).then(function (r) { r.list = list; return r; });
  }

  /* Next page of a list. Offset counts directory rows already shown. */
  function more(list, offset) {
    return rbPage(list.query, offset);
  }

  /* ---------- folders: countries and genres ---------- */
  function cachedFolder(key, fetcher) {
    var c = Store.cached(key, FOLDER_CACHE_MS);
    if (c && c.fresh) return Promise.resolve({ items: c.data, source: "cache" });
    return fetcher().then(function (items) {
      Store.cache(key, items);
      return { items: items, source: "live" };
    }, function () {
      if (c) return { items: c.data, source: "cache" };
      throw new Error("folder_unavailable");
    });
  }

  function countryItems(rows) {
    var byCode = {};
    rows.forEach(function (r) {
      var code = (r.iso_3166_1 || "").toUpperCase();
      if (!code || !r.stationcount) return;
      if (!byCode[code]) byCode[code] = { code: code, name: r.name, count: 0 };
      byCode[code].count += r.stationcount;
    });
    return byCode;
  }
  function makeCountryItem(c, group) {
    return { id: "cc-" + c.code, kind: "country", code: c.code, group: group,
             label: countryName(c.code, c.name), count: c.count,
             logo: "https://flagcdn.com/w160/" + c.code.toLowerCase() + ".png",
             query: "countrycode=" + c.code };
  }

  function arabicCountries() {
    return cachedFolder("folder.arabic-countries.v2", function () {
      return rb("/json/countries?hidebroken=true").then(function (rows) {
        var byCode = countryItems(rows);
        return ARAB.filter(function (code) { return byCode[code]; })
                   .map(function (code) { return makeCountryItem(byCode[code], "arab"); });
      });
    });
  }

  function countries() {
    return cachedFolder("folder.countries.v2", function () {
      return rb("/json/countries?hidebroken=true").then(function (rows) {
        var byCode = countryItems(rows);
        return Object.keys(byCode)
          .filter(function (k) { return ARAB.indexOf(k) < 0; })
          .map(function (k) { return byCode[k]; })
          .sort(function (a, b) { return b.count - a.count; })
          .map(function (c) { return makeCountryItem(c, "world"); });
      });
    });
  }

  /* Arabic genres are counted from the 500 most-played Arabic stations, so every
     tile leads to real stations. World genres come from the directory's tag list. */
  function genres() {
    return cachedFolder("folder.genres", function () {
      var skip = { "arabic": 1, "arab": 1, "radio": 1, "fm": 1, "am": 1 };
      var arabicP = rb("/json/stations/search?hidebroken=true&order=clickcount&reverse=true&limit=500&language=arabic")
        .then(function (rows) {
          var count = {};
          rows.forEach(function (r) {
            (r.tags || "").split(",").forEach(function (t) {
              t = t.toLowerCase().trim();
              if (!t || skip[t] || t.length > 24) return;
              count[t] = (count[t] || 0) + 1;
            });
          });
          return Object.keys(count).filter(function (t) { return count[t] >= 3; })
            .sort(function (a, b) { return count[b] - count[a]; }).slice(0, 24)
            .map(function (t) {
              return { id: "ga-" + t, kind: "genre", group: "arab", label: tagLabel(t), sub: t, count: count[t],
                       query: "language=arabic&tagExact=true&tag=" + encodeURIComponent(t) };
            });
        }, function () { return []; });
      var worldP = rb("/json/tags?hidebroken=true&order=stationcount&reverse=true&limit=80")
        .then(function (rows) {
          return rows.filter(function (r) { return r.name && r.stationcount >= 50 && !skip[r.name.toLowerCase()]; })
            .map(function (r) {
              return { id: "gw-" + r.name, kind: "genre", group: "world", label: tagLabel(r.name), sub: r.name,
                       count: r.stationcount, query: "tagExact=true&tag=" + encodeURIComponent(r.name) };
            });
        }, function () { return []; });
      return Promise.all([arabicP, worldP]).then(function (parts) {
        var items = parts[0].concat(parts[1]);
        if (!items.length) throw new Error("genres_unavailable");
        return items;
      });
    });
  }

  function folder(cat) {
    if (cat === "arabic") return arabicCountries();
    if (cat === "countries") return countries();
    return genres();
  }

  /* Station list behind a country or genre tile. */
  function openFolderItem(item) {
    return loadList({ key: "list." + item.id, query: item.query, seed: [] })
      .then(function (r) { r.list = { key: "list." + item.id, query: item.query }; return r; });
  }

  /* Name search; when the name finds little, stations tagged with the word are added. */
  function search(text) {
    var q = encodeURIComponent(text.trim());
    if (!q) return Promise.resolve({ stations: [], source: "live", full: false });
    var list = { key: "search", query: "name=" + q };
    return rbPage(list.query, 0).then(function (byName) {
      if (byName.stations.length >= 12) return { stations: dedupe(byName.stations), source: "live", full: byName.full, rows: byName.rows, list: list };
      return rbPage("tag=" + q, 0).then(function (byTag) {
        return { stations: dedupe(byName.stations.concat(byTag.stations)), source: "live", full: false, list: list };
      }, function () {
        return { stations: dedupe(byName.stations), source: "live", full: false, list: list };
      });
    });
  }

  /* Resolve a station by its app ID — used for shareable links (#s=<id>).
     Checks seed + favorites + recent first, falls back to Radio Browser by UUID. */
  function resolveById(id) {
    var local = (window.RAFEEQ_SEED || []).concat(Store.favorites()).concat(Store.recent());
    for (var i = 0; i < local.length; i++) {
      if (local[i].id === id) return Promise.resolve(local[i]);
    }
    if (id.indexOf("rb-") === 0) {
      return rb("/json/stations/byuuid/" + id.slice(3)).then(function (rows) {
        if (!rows || !rows.length) return Promise.reject(new Error("not_found"));
        var s = fromRB(rows[0]);
        if (!s.urls.length) return Promise.reject(new Error("no_url"));
        return s;
      });
    }
    return Promise.reject(new Error("not_found"));
  }

  /* Total number of stations in the directory, for the header line. */
  function stats() {
    var c = Store.cached("stats", FOLDER_CACHE_MS);
    if (c && c.fresh) return Promise.resolve(c.data);
    return rb("/json/stats").then(function (s) { Store.cache("stats", s); return s; }, function () { return c ? c.data : null; });
  }

  /* Radio Browser asks clients to report a play, so popular stations rank higher. */
  function reportClick(station) {
    if (!station.uuid) return;
    rb("/json/url/" + station.uuid).catch(function () {});
  }

  window.Sources = {
    categories: CATEGORIES, load: load, more: more, folder: folder, openFolderItem: openFolderItem,
    search: search, stats: stats, reportClick: reportClick, dedupe: dedupe, PAGE: PAGE,
    resolveById: resolveById
  };
})();
