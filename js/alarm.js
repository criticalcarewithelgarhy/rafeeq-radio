/* رفيق · راديو — Alarm. Exposes window.Alarm. Depends on window.Store. */
(function () {
  "use strict";

  window.Alarm = {
    get: function () {
      return Store.get("alarm", null);
    },

    set: function (time, stationId) {
      Store.set("alarm", { time: time, stationId: stationId, enabled: true });
    },

    cancel: function () {
      Store.set("alarm", null);
    },

    /* Called every minute. If current HH:MM matches alarm time and alarm is enabled,
       calls playFn(stationId) and disables the alarm to prevent re-firing. */
    check: function (playFn) {
      var alarm = this.get();
      if (!alarm || !alarm.enabled) return;
      var d = new Date();
      var h = d.getHours(), m = d.getMinutes();
      var hh = (h < 10 ? "0" : "") + h;
      var mm = (m < 10 ? "0" : "") + m;
      var now = hh + ":" + mm;
      if (now === alarm.time) {
        /* Disable before firing so re-check within same minute won't fire again. */
        Store.set("alarm", { time: alarm.time, stationId: alarm.stationId, enabled: false });
        playFn(alarm.stationId);
      }
    },

    /* Returns display string like "⏰ ٠٧:٠٠" or "" if no alarm set. */
    badge: function () {
      var alarm = this.get();
      if (!alarm) return "";
      function toAr(n) {
        return String(n).replace(/\d/g, function (d) { return "٠١٢٣٤٥٦٧٨٩"[d]; });
      }
      var parts = alarm.time.split(":");
      return "\u23F0 " + toAr(parts[0]) + ":" + toAr(parts[1]);
    }
  };
})();
