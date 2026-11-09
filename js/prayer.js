/* رفيق · راديو — Prayer Times. Exposes window.Prayer. Depends on window.Store.
   Pure JS implementation of the standard prayer time algorithm (no external library).
   ES5 only: var, function, no arrow functions, no const/let, no template literals. */
(function () {
  "use strict";

  var DEG = Math.PI / 180;

  /* ---------- Astronomical helpers ---------- */

  function julianDate(y, m, d) {
    if (m <= 2) { y -= 1; m += 12; }
    var A = Math.floor(y / 100);
    var B = 2 - A + Math.floor(A / 4);
    return Math.floor(365.25 * (y + 4716)) + Math.floor(30.6001 * (m + 1)) + d + B - 1524.5;
  }

  function mod(x, n) { return x - Math.floor(x / n) * n; }

  function sunPosition(jd) {
    var D = jd - 2451545.0;
    var g = mod(357.529 + 0.98560028 * D, 360);
    var q = mod(280.459 + 0.98564736 * D, 360);
    var L = q + 1.915 * Math.sin(g * DEG) + 0.020 * Math.sin(2 * g * DEG);
    var e = 23.439 - 0.0000004 * D;
    var RA = Math.atan2(Math.cos(e * DEG) * Math.sin(L * DEG), Math.cos(L * DEG)) / DEG / 15;
    var decl = Math.asin(Math.sin(e * DEG) * Math.sin(L * DEG)) / DEG;
    var EqT = q / 15 - RA;
    return { decl: decl, eqT: EqT };
  }

  function hourAngle(lat, decl, angle) {
    var num = -Math.sin(angle * DEG) - Math.sin(lat * DEG) * Math.sin(decl * DEG);
    var den = Math.cos(lat * DEG) * Math.cos(decl * DEG);
    if (den === 0) return NaN;
    var cos = num / den;
    if (cos < -1) cos = -1;
    if (cos > 1) cos = 1;
    return Math.acos(cos) / DEG / 15;
  }

  /* Shafi method: shadow factor = 1 */
  function asrHourAngle(lat, decl) {
    var target = Math.atan(1 / (1 + Math.tan(Math.abs(lat - decl) * DEG))) / DEG;
    return hourAngle(lat, decl, -target);
  }

  /* Convert decimal hours (relative to midnight local time) to "HH:MM" string */
  function hoursToHHMM(h) {
    if (isNaN(h)) return "--:--";
    h = mod(h, 24);
    var hh = Math.floor(h);
    var mm = Math.round((h - hh) * 60);
    if (mm >= 60) { hh += 1; mm = 0; }
    hh = mod(hh, 24);
    return (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm;
  }

  /* Methods: fajrAngle, ishaAngle (degrees), ishaMinutes (minutes after Maghrib, 0 = use angle) */
  var METHODS = {
    egypt:      { fajrAngle: 19.5, ishaAngle: 17.5, ishaMinutes: 0 },
    mwl:        { fajrAngle: 18,   ishaAngle: 17,   ishaMinutes: 0 },
    umm_alqura: { fajrAngle: 18.5, ishaAngle: 0,    ishaMinutes: 90 }
  };

  function calcTimes(date, lat, lng, tz, method) {
    var jd = julianDate(date.getFullYear(), date.getMonth() + 1, date.getDate());
    var sp = sunPosition(jd);
    var decl = sp.decl, eqT = sp.eqT;
    var m = METHODS[method] || METHODS.mwl;

    var duhr = 12 + tz - lng / 15 - eqT;
    var sunrise = duhr - hourAngle(lat, decl, -0.8333);
    var maghrib = duhr + hourAngle(lat, decl, -0.8333);
    var fajr    = duhr - hourAngle(lat, decl, m.fajrAngle);
    var asr     = duhr + asrHourAngle(lat, decl);
    var isha;
    if (m.ishaMinutes) {
      isha = maghrib + m.ishaMinutes / 60;
    } else {
      isha = duhr + hourAngle(lat, decl, m.ishaAngle);
    }

    return {
      fajr:    hoursToHHMM(fajr),
      sunrise: hoursToHHMM(sunrise),
      duhr:    hoursToHHMM(duhr),
      asr:     hoursToHHMM(asr),
      maghrib: hoursToHHMM(maghrib),
      isha:    hoursToHHMM(isha)
    };
  }

  /* ---------- City list ---------- */

  var CITIES = [
    { id: "cairo",      name: "القاهرة",       lat: 30.0444,  lng: 31.2357,  tz: 2,  method: "egypt" },
    { id: "riyadh",     name: "الرياض",         lat: 24.6877,  lng: 46.7219,  tz: 3,  method: "umm_alqura" },
    { id: "dubai",      name: "دبي",            lat: 25.2048,  lng: 55.2708,  tz: 4,  method: "mwl" },
    { id: "abudhabi",   name: "أبوظبي",         lat: 24.4539,  lng: 54.3773,  tz: 4,  method: "mwl" },
    { id: "kuwait",     name: "الكويت",          lat: 29.3759,  lng: 47.9774,  tz: 3,  method: "mwl" },
    { id: "amman",      name: "عمّان",           lat: 31.9539,  lng: 35.9106,  tz: 2,  method: "mwl" },
    { id: "beirut",     name: "بيروت",           lat: 33.8938,  lng: 35.5018,  tz: 2,  method: "mwl" },
    { id: "damascus",   name: "دمشق",            lat: 33.5138,  lng: 36.2765,  tz: 2,  method: "mwl" },
    { id: "baghdad",    name: "بغداد",           lat: 33.3406,  lng: 44.4009,  tz: 3,  method: "mwl" },
    { id: "doha",       name: "الدوحة",          lat: 25.2854,  lng: 51.5310,  tz: 3,  method: "mwl" },
    { id: "manama",     name: "المنامة",          lat: 26.2235,  lng: 50.5876,  tz: 3,  method: "mwl" },
    { id: "muscat",     name: "مسقط",            lat: 23.5880,  lng: 58.3829,  tz: 4,  method: "mwl" },
    { id: "sanaa",      name: "صنعاء",           lat: 15.3694,  lng: 44.1910,  tz: 3,  method: "mwl" },
    { id: "tripoli",    name: "طرابلس",          lat: 32.8872,  lng: 13.1913,  tz: 2,  method: "mwl" },
    { id: "tunis",      name: "تونس",            lat: 36.8065,  lng: 10.1815,  tz: 1,  method: "mwl" },
    { id: "algiers",    name: "الجزائر",          lat: 36.7372,  lng: 3.0865,   tz: 1,  method: "mwl" },
    { id: "casablanca", name: "الدار البيضاء",   lat: 33.5731,  lng: -7.5898,  tz: 0,  method: "mwl" },
    { id: "khartoum",   name: "الخرطوم",          lat: 15.5007,  lng: 32.5599,  tz: 3,  method: "mwl" },
    { id: "mogadishu",  name: "مقديشو",           lat: 2.0469,   lng: 45.3182,  tz: 3,  method: "mwl" }
  ];

  var NAMES = {
    fajr:    "\u0627\u0644\u0641\u062c\u0631",
    sunrise: "\u0627\u0644\u0634\u0631\u0648\u0642",
    duhr:    "\u0627\u0644\u0638\u0647\u0631",
    asr:     "\u0627\u0644\u0639\u0635\u0631",
    maghrib: "\u0627\u0644\u0645\u063a\u0631\u0628",
    isha:    "\u0627\u0644\u0639\u0634\u0627\u0621"
  };

  function findCity(id) {
    for (var i = 0; i < CITIES.length; i++) {
      if (CITIES[i].id === id) return CITIES[i];
    }
    return null;
  }

  /* HH:MM string to total minutes */
  function hhmmToMinutes(hhmm) {
    var parts = hhmm.split(":");
    return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
  }

  function toArabicNum(n) {
    return String(n).replace(/\d/g, function (d) { return "\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669"[d]; });
  }

  window.Prayer = {
    CITIES: CITIES,
    NAMES: NAMES,

    getTimes: function (cityId, date) {
      var city = findCity(cityId);
      if (!city) return null;
      return calcTimes(date || new Date(), city.lat, city.lng, city.tz, city.method);
    },

    getNext: function (cityId) {
      var city = findCity(cityId);
      if (!city) return null;
      var now = new Date();
      var times = calcTimes(now, city.lat, city.lng, city.tz, city.method);
      var nowMinutes = now.getHours() * 60 + now.getMinutes();
      var keys = ["fajr", "sunrise", "duhr", "asr", "maghrib", "isha"];
      for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        var t = times[key];
        var tMin = hhmmToMinutes(t);
        if (tMin > nowMinutes) {
          return { key: key, name: NAMES[key], time: t, minutes: tMin - nowMinutes };
        }
      }
      /* Past Isha: return tomorrow's Fajr */
      var tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
      var tomorrowTimes = calcTimes(tomorrow, city.lat, city.lng, city.tz, city.method);
      var fajrMin = hhmmToMinutes(tomorrowTimes.fajr);
      var minutesUntilMidnight = 24 * 60 - nowMinutes;
      return { key: "fajr", name: NAMES.fajr, time: tomorrowTimes.fajr, minutes: minutesUntilMidnight + fajrMin };
    },

    getCityName: function (id) {
      var city = findCity(id);
      return city ? city.name : "";
    },

    currentCityId: function () {
      return Store.get("prayer_city", null);
    },

    setCity: function (id) {
      Store.set("prayer_city", id);
    },

    toArabicNum: toArabicNum
  };
})();
